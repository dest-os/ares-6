import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Desteklenen "beyin" (birincil API) seçenekleri.
class ApiProvider {
  static const String gemini = 'gemini';
  static const String openai = 'openai';
  static const String claude = 'claude';
  static const String grok = 'grok';
  static const String nvidia = 'nvidia';
  static const String custom = 'custom';

  static const List<String> tumu = [
    gemini,
    openai,
    claude,
    grok,
    nvidia,
    custom,
  ];

  static String etiket(String id) {
    switch (id) {
      case openai:
        return 'OpenAI';
      case claude:
        return 'Claude';
      case grok:
        return 'Grok (xAI)';
      case nvidia:
        return 'NVIDIA (NIM / API)';
      case custom:
        return 'Özel API / Ajan';
      case gemini:
      default:
        return 'Google Gemini';
    }
  }

  static String aciklama(String id) {
    switch (id) {
      case openai:
        return 'OpenAI GPT modelleri';
      case claude:
        return 'Anthropic Claude';
      case grok:
        return 'xAI Grok';
      case nvidia:
        return 'build.nvidia.com / NIM – açık modeller (Llama, Mistral vb.)';
      case custom:
        return 'Kendi ajanın veya Hermes tarzı endpoint (URL + anahtar)';
      case gemini:
      default:
        return 'Ses tanıma için önerilen (Google AI Studio)';
    }
  }
}

class SettingsService extends ChangeNotifier {
  static const String _prefsKey = 'ares_settings_v3';

  String geminiApiKey = '';
  /// Ek Gemini anahtarlari (farkli projelerden). 429'da sirayla denenir.
  List<String> geminiApiKeys = [];
  String openaiApiKey = '';
  String openweatherApiKey = '';
  String githubToken = '';
  String githubUsername = '';
  String githubRepo = '';
  String claudeApiKey = '';
  String grokApiKey = '';
  String nvidiaApiKey = '';
  /// NVIDIA model adı (örn. meta/llama-3.3-70b-instruct)
  String nvidiaModel = 'meta/llama-3.3-70b-instruct';
  String customApiKey = '';
  String customApiBaseUrl = '';
  /// Özel ajan adı (gösterim için): Hermes, AutoGPT vb.
  String customAgentName = 'Hermes';
  String sahipAdi = 'İbrahim';
  String asistanAdi = 'ARES';
  String geminiModel = 'gemini-3.8-flash';
  int dinlemeSuresi = 4;
  String alkisHassasiyeti = 'yüksek';
  String birincilApi = ApiProvider.gemini;

  bool _yuklendi = false;
  bool get yuklendi => _yuklendi;

  Future<void> yukle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? raw = prefs.getString(_prefsKey);
      raw ??= prefs.getString('ares_settings_v2');
      raw ??= prefs.getString('ares_settings_v1');
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        geminiApiKey = (map['gemini_api_key'] ?? '').toString();
        final ek = map['gemini_api_keys'];
        if (ek is List) {
          geminiApiKeys = ek.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
        } else {
          geminiApiKeys = [];
        }
        openaiApiKey = (map['openai_api_key'] ?? '').toString();
        openweatherApiKey = (map['openweather_api_key'] ?? '').toString();
        githubToken = (map['github_token'] ?? '').toString();
        githubUsername = (map['github_username'] ?? '').toString();
        githubRepo = (map['github_repo'] ?? '').toString();
        claudeApiKey = (map['claude_api_key'] ?? '').toString();
        grokApiKey = (map['grok_api_key'] ?? '').toString();
        nvidiaApiKey = (map['nvidia_api_key'] ?? '').toString();
        nvidiaModel =
            (map['nvidia_model'] ?? 'meta/llama-3.3-70b-instruct').toString();
        customApiKey = (map['custom_api_key'] ?? '').toString();
        customApiBaseUrl = (map['custom_api_base_url'] ?? '').toString();
        customAgentName = (map['custom_agent_name'] ?? 'Hermes').toString();
        sahipAdi = (map['sahip_adi'] ?? 'İbrahim').toString();
        asistanAdi = (map['asistan_adi'] ?? 'ARES').toString();
        geminiModel = (map['gemini_model'] ?? 'gemini-3.8-flash').toString();
        dinlemeSuresi = (map['dinleme_suresi'] as num?)?.toInt() ?? 4;
        alkisHassasiyeti = (map['alkis_hassasiyeti'] ?? 'yüksek').toString();
        birincilApi = (map['birincil_api'] ?? ApiProvider.gemini).toString();
        if (!ApiProvider.tumu.contains(birincilApi)) {
          birincilApi = ApiProvider.gemini;
        }
      }
    } catch (e) {
      debugPrint('SettingsService yükleme hatası: $e');
    }
    _yuklendi = true;
    notifyListeners();
  }

  Future<void> kaydet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {
        'gemini_api_key': geminiApiKey.trim(),
        'openai_api_key': openaiApiKey.trim(),
        'openweather_api_key': openweatherApiKey.trim(),
        'github_token': githubToken.trim(),
        'github_username': githubUsername.trim(),
        'github_repo': githubRepo.trim(),
        'claude_api_key': claudeApiKey.trim(),
        'grok_api_key': grokApiKey.trim(),
        'nvidia_api_key': nvidiaApiKey.trim(),
        'nvidia_model': nvidiaModel.trim(),
        'custom_api_key': customApiKey.trim(),
        'custom_api_base_url': customApiBaseUrl.trim(),
        'custom_agent_name': customAgentName.trim(),
        'sahip_adi': sahipAdi.trim(),
        'asistan_adi': asistanAdi.trim(),
        'gemini_model': geminiModel.trim(),
        'dinleme_suresi': dinlemeSuresi,
        'alkis_hassasiyeti': alkisHassasiyeti,
        'birincil_api': birincilApi,
      };
      await prefs.setString(_prefsKey, jsonEncode(map));
      notifyListeners();
    } catch (e) {
      debugPrint('SettingsService kaydetme hatası: $e');
      rethrow;
    }
  }

  bool _anahtarDolu(String k) {
    final t = k.trim();
    return t.isNotEmpty && !t.contains('BURAYA') && t.length > 8;
  }

  /// Birincil + ek anahtarlar (tekrarsiz, dolu olanlar).
  List<String> get geminiTumAnahtarlar {
    final list = <String>[];
    final a = geminiApiKey.trim();
    if (a.isNotEmpty) list.add(a);
    for (final k in geminiApiKeys) {
      final t = k.trim();
      if (t.isNotEmpty && !list.contains(t)) list.add(t);
    }
    return list;
  }

  bool get geminiHazir => geminiTumAnahtarlar.isNotEmpty;
  bool get openaiHazir => _anahtarDolu(openaiApiKey);
  bool get claudeHazir => _anahtarDolu(claudeApiKey);
  bool get grokHazir => _anahtarDolu(grokApiKey);
  bool get nvidiaHazir => _anahtarDolu(nvidiaApiKey);
  bool get customHazir =>
      _anahtarDolu(customApiKey) && customApiBaseUrl.trim().isNotEmpty;

  bool get birincilHazir {
    switch (birincilApi) {
      case ApiProvider.openai:
        return openaiHazir;
      case ApiProvider.claude:
        return claudeHazir;
      case ApiProvider.grok:
        return grokHazir;
      case ApiProvider.nvidia:
        return nvidiaHazir;
      case ApiProvider.custom:
        return customHazir;
      case ApiProvider.gemini:
      default:
        return geminiHazir;
    }
  }

  String get birincilEtiket => ApiProvider.etiket(birincilApi);

  List<String> get aktifApiListesi {
    final list = <String>[];
    if (geminiHazir) list.add('Gemini');
    if (openaiHazir) list.add('OpenAI');
    if (claudeHazir) list.add('Claude');
    if (grokHazir) list.add('Grok');
    if (nvidiaHazir) list.add('NVIDIA');
    if (openweatherApiKey.trim().isNotEmpty) list.add('OpenWeather');
    if (githubToken.trim().isNotEmpty) list.add('GitHub');
    if (customHazir) list.add(customAgentName.isEmpty ? 'Özel Ajan' : customAgentName);
    return list;
  }
}
