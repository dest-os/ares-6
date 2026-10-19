import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'settings_service.dart';

/// Metin tabanlı LLM çağrıları.
/// Ses tanıma ayrı (AresService + Gemini audio); bu servis yazılı/akıllı yanıt içindir.
class LlmService {
  final SettingsService settings;

  LlmService(this.settings);

  /// Kisa Turkce yanit. Birincil beyin basarisizsa (429/404) diger kayitli API'lere gecer.
  Future<String> akilliYanit(String kullaniciMesaji) async {
    final mesaj = kullaniciMesaji.trim();
    if (mesaj.isEmpty) {
      throw Exception('Bos mesaj');
    }

    final sistem = 'Sen ${settings.asistanAdi}. Turkce, 1-2 cumle, net.';

    // Sadece anahtari DOLU beyinler
    final adaylar = <String>[
      settings.birincilApi,
      ApiProvider.nvidia,
      ApiProvider.openai,
      ApiProvider.grok,
      ApiProvider.custom,
      ApiProvider.gemini,
      ApiProvider.claude,
    ];
    final denenen = <String>[];
    for (final p in adaylar) {
      if (denenen.contains(p)) continue;
      if (!_providerHazir(p)) continue;
      denenen.add(p);
    }
    if (denenen.isEmpty) {
      throw Exception(
        'Hic kayitli API anahtari yok. Ayarlardan Gemini veya NVIDIA ekle ve KAYDET.',
      );
    }

    String sonHata = '';
    for (final provider in denenen) {
      try {
        final yanit = await _tekSaglayici(provider, sistem, mesaj);
        if (yanit.trim().isNotEmpty) {
          debugPrint('LlmService basarili provider: $provider');
          return yanit;
        }
      } catch (e) {
        sonHata = e.toString();
        debugPrint('LlmService $provider hata: $e');
        continue;
      }
    }
    throw Exception(
      'Kayitli beyinler yanit veremedi (${denenen.join(", ")}). Son hata: $sonHata',
    );
  }

  bool _providerHazir(String provider) {
    switch (provider) {
      case ApiProvider.nvidia:
        return settings.nvidiaHazir;
      case ApiProvider.openai:
        return settings.openaiHazir;
      case ApiProvider.grok:
        return settings.grokHazir;
      case ApiProvider.custom:
        return settings.customHazir;
      case ApiProvider.claude:
        return settings.claudeHazir;
      case ApiProvider.gemini:
        return settings.geminiHazir;
      default:
        return false;
    }
  }

  Future<String> _tekSaglayici(
    String provider,
    String sistem,
    String mesaj,
  ) async {
    switch (provider) {
      case ApiProvider.nvidia:
        if (!settings.nvidiaHazir) throw Exception('NVIDIA anahtar yok');
        return await _nvidiaCagir(sistem: sistem, kullanici: mesaj);
      case ApiProvider.openai:
        if (!settings.openaiHazir) throw Exception('OpenAI anahtar yok');
        return await _openaiUyumluCagir(
          baseUrl: 'https://api.openai.com/v1',
          apiKey: settings.openaiApiKey,
          model: 'gpt-4o-mini',
          sistem: sistem,
          kullanici: mesaj,
        );
      case ApiProvider.grok:
        if (!settings.grokHazir) throw Exception('Grok anahtar yok');
        return await _openaiUyumluCagir(
          baseUrl: 'https://api.x.ai/v1',
          apiKey: settings.grokApiKey,
          model: 'grok-2-latest',
          sistem: sistem,
          kullanici: mesaj,
        );
      case ApiProvider.custom:
        if (!settings.customHazir) throw Exception('Ozel API yok');
        return await _openaiUyumluCagir(
          baseUrl: _normalizeBase(settings.customApiBaseUrl),
          apiKey: settings.customApiKey,
          model: 'default',
          sistem: sistem,
          kullanici: mesaj,
        );
      case ApiProvider.claude:
        if (!settings.claudeHazir) throw Exception('Claude anahtar yok');
        return await _claudeCagir(sistem: sistem, kullanici: mesaj);
      case ApiProvider.gemini:
      default:
        if (!settings.geminiHazir) throw Exception('Gemini anahtar yok');
        return await _geminiMetin(sistem: sistem, kullanici: mesaj);
    }
  }

  /// Ayarlar ekrani test butonu — her zaman okunabilir Turkce sonuc.
  Future<String> baglantiTesti() async {
    final beyin = settings.birincilEtiket;
    if (!settings.birincilHazir) {
      return 'Secili beyin ($beyin) icin API anahtari eksik. '
          'Anahtari yapistirip KAYDET, sonra test et.';
    }
    try {
      final sistem = 'Kisa cevap ver.';
      final yanit = await _tekSaglayici(
        settings.birincilApi,
        sistem,
        'Sadece su kelimeleri yaz: baglanti tamam',
      );
      if (yanit.trim().isEmpty) {
        return 'Sunucu bos yanit dondu ($beyin). Model adini kontrol et.';
      }
      return 'Basarili ($beyin): $yanit';
    } catch (e) {
      final msg = e.toString();
      debugPrint('baglantiTesti hata: $msg');
      if (msg.contains('401') || msg.contains('403')) {
        return 'Yetki hatasi (401/403): API anahtari yanlis veya suresi dolmus. ($beyin)';
      }
      if (msg.contains('404')) {
        return 'Model bulunamadi (404): Model adini kontrol et. ($beyin)';
      }
      if (msg.contains('429') || msg.contains('quota')) {
        return 'Kota doldu (429) ($beyin). Baska beyin sec veya bekle.';
      }
      return 'Hata ($beyin): $msg';
    }
  }

  String _normalizeBase(String url) {
    var u = url.trim();
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    if (u.endsWith('/chat/completions')) {
      u = u.replaceAll(RegExp(r'/chat/completions$'), '');
    }
    return u;
  }


  /// NVIDIA: once /v1/models ile hesabinda acik modelleri al, sonra dene.
  Future<List<String>> nvidiaModelListesi() async {
    final key = settings.nvidiaApiKey.trim();
    if (key.isEmpty) return [];
    final uri = Uri.parse('https://integrate.api.nvidia.com/v1/models');
    final r = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $key',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 20));
    if (r.statusCode == 401 || r.statusCode == 403) {
      throw Exception(
        'NVIDIA anahtar yetkisiz (${r.statusCode}). build.nvidia.com anahtarini kontrol et.',
      );
    }
    if (r.statusCode < 200 || r.statusCode >= 300) {
      debugPrint('NVIDIA models HTTP ${r.statusCode}: ${r.body}');
      return [];
    }
    final data = jsonDecode(r.body);
    final list = <String>[];
    if (data is Map && data['data'] is List) {
      for (final item in data['data'] as List) {
        if (item is Map && item['id'] != null) {
          list.add(item['id'].toString());
        }
      }
    }
    return list;
  }

  Future<String> _nvidiaCagir({
    required String sistem,
    required String kullanici,
  }) async {
    final tercih = settings.nvidiaModel.trim();
    final adaylar = <String>[];
    if (tercih.isNotEmpty) adaylar.add(tercih);

    try {
      final canli = await nvidiaModelListesi();
      for (final m in canli) {
        if (!adaylar.contains(m)) adaylar.add(m);
      }
      debugPrint('NVIDIA canli model sayisi: ${canli.length}');
      if (canli.isEmpty) {
        throw Exception(
          'NVIDIA /v1/models bos dondu. Hesabinda etkin model yok veya anahtar sinirli.',
        );
      }
    } catch (e) {
      debugPrint('NVIDIA model listesi: $e');
      final s = e.toString();
      if (s.contains('401') || s.contains('403') || s.contains('yetkisiz')) {
        rethrow;
      }
      for (final m in const [
        'meta/llama-3.3-70b-instruct',
        'meta/llama3-70b-instruct',
        'microsoft/phi-3-mini-4k-instruct',
        'google/gemma-2-9b-it',
      ]) {
        if (!adaylar.contains(m)) adaylar.add(m);
      }
    }

    if (adaylar.isEmpty) {
      throw Exception(
        'NVIDIA hesabinda kullanilabilir model yok. build.nvidia.com',
      );
    }

    Object? son;
    final denenecek = adaylar.take(8).toList();
    for (final model in denenecek) {
      try {
        final yanit = await _openaiUyumluCagir(
          baseUrl: 'https://integrate.api.nvidia.com/v1',
          apiKey: settings.nvidiaApiKey,
          model: model,
          sistem: sistem,
          kullanici: kullanici,
        );
        if (settings.nvidiaModel != model) {
          settings.nvidiaModel = model;
          await settings.kaydet();
        }
        return yanit;
      } catch (e) {
        son = e;
        debugPrint('NVIDIA dene $model: $e');
        continue;
      }
    }
    throw Exception(
      'NVIDIA yanit vermedi. Denenen: ${denenecek.join(", ")}. Son: $son',
    );
  }

  Future<String> _openaiUyumluCagir({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String sistem,
    required String kullanici,
  }) async {
    final base = _normalizeBase(baseUrl);
    final uri = Uri.parse('$base/chat/completions');
    final govde = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'system', 'content': sistem},
        {'role': 'user', 'content': kullanici},
      ],
      'temperature': 0.4,
      'max_tokens': 120,
    });
    final yanit = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${apiKey.trim()}',
          },
          body: govde,
        )
        .timeout(const Duration(seconds: 25));
    if (yanit.statusCode < 200 || yanit.statusCode >= 300) {
      final body = yanit.body.length > 200
          ? yanit.body.substring(0, 200)
          : yanit.body;
      throw Exception('HTTP ${yanit.statusCode}: $body');
    }
    final data = jsonDecode(yanit.body) as Map<String, dynamic>;
    final content = data['choices']?[0]?['message']?['content'];
    final text = content?.toString().trim() ?? '';
    if (text.isEmpty) {
      throw Exception('Bos icerik: ${yanit.body.length > 100 ? yanit.body.substring(0, 100) : yanit.body}');
    }
    return text;
  }

  Future<String> _claudeCagir({
    required String sistem,
    required String kullanici,
  }) async {
    final uri = Uri.parse('https://api.anthropic.com/v1/messages');
    final govde = jsonEncode({
      'model': 'claude-3-5-haiku-latest',
      'max_tokens': 120,
      'system': sistem,
      'messages': [
        {'role': 'user', 'content': kullanici},
      ],
    });
    final yanit = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': settings.claudeApiKey.trim(),
            'anthropic-version': '2023-06-01',
          },
          body: govde,
        )
        .timeout(const Duration(seconds: 25));
    if (yanit.statusCode < 200 || yanit.statusCode >= 300) {
      throw Exception('Claude HTTP ${yanit.statusCode}: ${yanit.body.length > 120 ? yanit.body.substring(0, 120) : yanit.body}');
    }
    final data = jsonDecode(yanit.body) as Map<String, dynamic>;
    final blocks = data['content'] as List? ?? [];
    if (blocks.isEmpty) {
      throw Exception('Claude bos content');
    }
    final text = blocks.first['text']?.toString().trim() ?? '';
    if (text.isEmpty) throw Exception('Claude bos metin');
    return text;
  }

  /// API anahtariyla kullanilabilir modelleri listeler.
  Future<List<String>> _geminiModelleriListele() async {
    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models'
        '?key=${settings.geminiApiKey.trim()}',
      );
      final yanit = await http.get(uri).timeout(const Duration(seconds: 15));
      if (yanit.statusCode != 200) return [];
      final data = jsonDecode(yanit.body) as Map<String, dynamic>;
      final models = data['models'] as List? ?? [];
      final isimler = <String>[];
      for (final m in models) {
        final name = (m['name'] ?? '').toString(); // models/gemini-x
        final methods = (m['supportedGenerationMethods'] as List? ?? [])
            .map((e) => e.toString())
            .toList();
        if (!methods.contains('generateContent')) continue;
        final id = name.replaceFirst('models/', '');
        if (id.isNotEmpty) isimler.add(id);
      }
      return isimler;
    } catch (e) {
      debugPrint('Gemini model listesi alinamadi: $e');
      return [];
    }
  }

  /// Gemini metin — once listedeki modeller, sonra bilinen guncel isimler.
  Future<String> _geminiMetin({
    required String sistem,
    required String kullanici,
  }) async {
    final anahtarlar = settings.geminiTumAnahtarlar;
    if (anahtarlar.isEmpty) {
      throw Exception('Gemini anahtar yok');
    }

    final tercih = settings.geminiModel.trim().isEmpty
        ? 'gemini-3.8-flash'
        : settings.geminiModel.trim();
    final modeller = <String>[
      tercih,
      'gemini-3.8-flash',
      'gemini-3.7-flash',
      'gemini-3.5-flash',
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-2.0-flash-lite',
    ];
    final uniq = <String>[];
    for (final m in modeller) {
      if (m.isNotEmpty && !uniq.contains(m)) uniq.add(m);
    }

    Object? sonHata;
    for (final key in anahtarlar) {
      for (final model in uniq.take(4)) {
        try {
          return await _geminiTekModel(
            model: model,
            sistem: sistem,
            kullanici: kullanici,
            apiKey: key,
          );
        } catch (e) {
          sonHata = e;
          final s = e.toString();
          debugPrint('Gemini key/model hata: $s');
          if (s.contains('429') || s.contains('quota') || s.contains('RESOURCE_EXHAUSTED')) {
            // Bu anahtar kotasi dolu -> sonraki anahtar
            break;
          }
          // 404 model -> sonraki model ayni anahtar
          continue;
        }
      }
    }
    throw Exception(
      sonHata ??
          'Gemini yanit yok. Anahtar sayisi: ${anahtarlar.length}. '
              'Farkli projelerden anahtar ekle veya Flash-Lite dene.',
    );
  }

  Future<String> _geminiTekModel({
    required String model,
    required String sistem,
    required String kullanici,
    required String apiKey,
  }) async {
    final key = apiKey.trim();
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );
    final govde = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': '$sistem\n\nKullanici: $kullanici'},
          ],
        },
      ],
    });
    final yanit = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': key,
          },
          body: govde,
        )
        .timeout(const Duration(seconds: 30));
    if (yanit.statusCode != 200) {
      throw Exception(
          'Gemini HTTP ${yanit.statusCode} ($model): '
          '${yanit.body.length > 150 ? yanit.body.substring(0, 150) : yanit.body}');
    }
    final data = jsonDecode(yanit.body) as Map<String, dynamic>;
    if (data['candidates'] == null) {
      final sebep = data['promptFeedback']?['blockReason'] ?? data['error'];
      throw Exception('Gemini aday yok ($model): $sebep');
    }
    final text =
        data['candidates']?[0]?['content']?['parts']?[0]?['text']?.toString().trim() ??
            '';
    if (text.isEmpty) {
      throw Exception('Gemini bos metin ($model)');
    }
    return text;
  }
}
