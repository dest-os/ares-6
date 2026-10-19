import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;
import 'settings_service.dart';
import 'llm_service.dart';

/// ARES'in durumları: ekranda gösterilecek göstergeyi belirler.
enum AresDurum { pasif, dinliyor, isliyorum, konusuyor }

/// Tek bir görev/komut tanımı. ares_tasks.json içindeki her blok
/// bu sınıfa dönüşür.
class AresTask {
  final String tur; // 'tam_eslesme' | 'onek'
  final String eylem; // 'kategori_ac' | 'uygulama_ac' | 'internette_ara' | 'soyle'
  final String? parametre;
  final List<String> tetikleyiciler;
  final String? yanit;

  AresTask({
    required this.tur,
    required this.eylem,
    required this.tetikleyiciler,
    this.parametre,
    this.yanit,
  });

  factory AresTask.fromJson(Map<String, dynamic> j) {
    return AresTask(
      tur: (j['tur'] ?? 'tam_eslesme').toString(),
      eylem: (j['eylem'] ?? 'soyle').toString(),
      parametre: j['parametre']?.toString(),
      tetikleyiciler: (j['tetikleyiciler'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      yanit: j['yanit']?.toString(),
    );
  }
}

class AresConfig {
  final String asistanAdi;
  final String sahibiAdi;
  final String karsilamaMesaji;
  final String anlasilmadiMesaji;
  final String uygulamaBulunamadiMesaji;
  final List<AresTask> gorevler;

  AresConfig({
    required this.asistanAdi,
    required this.sahibiAdi,
    required this.karsilamaMesaji,
    required this.anlasilmadiMesaji,
    required this.uygulamaBulunamadiMesaji,
    required this.gorevler,
  });

  factory AresConfig.fromJson(Map<String, dynamic> j) {
    return AresConfig(
      asistanAdi: (j['asistan_adi'] ?? 'ARES').toString(),
      sahibiAdi: (j['sahibi_adi'] ?? '').toString(),
      karsilamaMesaji:
          (j['karsilama_mesaji'] ?? 'Merhaba, senin için ne yapabilirim?').toString(),
      anlasilmadiMesaji: (j['anlasilmadi_mesaji'] ?? 'Bunu anlayamadım.').toString(),
      uygulamaBulunamadiMesaji:
          (j['uygulama_bulunamadi_mesaji'] ?? 'Uygulama bulunamadı.').toString(),
      gorevler: (j['gorevler'] as List? ?? const [])
          .map((e) => AresTask.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// ARES'in tüm mantığını yöneten servis.
class AresService extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  final AudioRecorder _kayitci = AudioRecorder();
  final SettingsService settings;

  AresConfig? _config;
  bool _baslatildi = false;

  AresDurum durum = AresDurum.pasif;
  String canliMetin = '';
  String sonYanit = '';
  String sonSoylenen = '';

  /// Kategori açma isteği geldiğinde çağrılır (örn. "SOSYAL").
  Future<void> Function(String kategori)? onKategoriAc;

  /// Uygulama açma isteği: bulunup açılabildiyse true döner.
  Future<bool> Function(String uygulamaAdi)? onUygulamaAc;

  /// İnternette arama isteği.
  Future<void> Function(String sorgu)? onInternetAra;

  static const String _varsayilanGorevDosyasi = 'assets/ares_tasks.json';
  static const String _kullaniciGorevDosyaAdi = 'ares_gorevler.json';
  static const String _genelKlasorYolu = '/storage/emulated/0/ARES';

  AresService({required this.settings});

  Future<void> baslat() async {
    if (_baslatildi) return;
    _baslatildi = true;

    try {
      await _tts.setLanguage('tr-TR');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
      await _kadinSesiSecmeyeCalis();
    } catch (e) {
      debugPrint('ARES: TTS başlatılamadı: $e');
    }

    _config = await _gorevleriYukle();
  }

  Future<void> _kadinSesiSecmeyeCalis() async {
    try {
      final sesler = await _tts.getVoices;
      if (sesler is! List) return;

      final turkceSesler = sesler.where((s) {
        final locale = (s['locale'] ?? '').toString().toLowerCase();
        return locale.contains('tr');
      }).toList();

      if (turkceSesler.isEmpty) return;

      const kadinIpuclari = ['female', 'kadın', 'woman', '#female', '-a-', '-c-', '-d-'];

      Map? secilen;
      for (final s in turkceSesler) {
        final ad = (s['name'] ?? '').toString().toLowerCase();
        if (kadinIpuclari.any((ipucu) => ad.contains(ipucu))) {
          secilen = s as Map;
          break;
        }
      }

      if (secilen != null) {
        await _tts.setVoice({
          'name': secilen['name'].toString(),
          'locale': secilen['locale'].toString(),
        });
        debugPrint('ARES: seçilen ses -> ${secilen['name']}');
      }
    } catch (e) {
      debugPrint('ARES: ses listesi alınamadı: $e');
    }
  }

  Future<Directory?> _dosyaKlasoru() async {
    try {
      final genel = Directory(_genelKlasorYolu);
      if (!await genel.exists()) {
        await genel.create(recursive: true);
      }
      final testDosyasi = File('${genel.path}/.ares_test');
      await testDosyasi.writeAsString('ok');
      await testDosyasi.delete();
      return genel;
    } catch (e) {
      debugPrint('ARES: /storage/emulated/0/ARES yazılamadı, yedek konuma geçiliyor: $e');
    }
    return getExternalStorageDirectory();
  }

  Future<AresConfig> _gorevleriYukle() async {
    try {
      final dizin = await _dosyaKlasoru();
      if (dizin != null) {
        final dosya = File('${dizin.path}/$_kullaniciGorevDosyaAdi');
        if (!await dosya.exists()) {
          final varsayilanIcerik = await rootBundle.loadString(_varsayilanGorevDosyasi);
          await dosya.writeAsString(varsayilanIcerik);
        }
        final icerik = await dosya.readAsString();
        final json = jsonDecode(icerik) as Map<String, dynamic>;
        // Ayarlardan gelen isimleri uygula
        if (settings.sahipAdi.isNotEmpty) {
          json['sahibi_adi'] = settings.sahipAdi;
        }
        if (settings.asistanAdi.isNotEmpty) {
          json['asistan_adi'] = settings.asistanAdi;
        }
        // Karşılama mesajını kişiselleştir
        final sahip = settings.sahipAdi.isNotEmpty ? settings.sahipAdi : 'İbrahim';
        json['karsilama_mesaji'] = 'Dinliyorum $sahip.';
        return AresConfig.fromJson(json);
      }
    } catch (e) {
      debugPrint('ARES: Cihazdaki görev dosyası okunamadı, varsayılan kullanılıyor: $e');
    }
    final varsayilanIcerik = await rootBundle.loadString(_varsayilanGorevDosyasi);
    return AresConfig.fromJson(jsonDecode(varsayilanIcerik) as Map<String, dynamic>);
  }

  String _trKucuk(String s) {
    return s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  }

  String? _bicimlendir(String? sablon, String deger) {
    if (sablon == null) return null;
    return sablon.replaceAll('%s', deger);
  }

  Future<void> konus(String metin) async {
    durum = AresDurum.konusuyor;
    sonYanit = metin;
    notifyListeners();
    try {
      await _tts.speak(metin);
    } catch (e) {
      debugPrint('ARES: konuşma hatası: $e');
    }
  }

  /// Alkış (veya elle) tetiklendiğinde çağrılır.
  Future<void> uyandirVeDinle() async {
    if (!_baslatildi) await baslat();
    // Her seferinde ayarları ve görevleri tazele
    await settings.yukle();
    _config = await _gorevleriYukle();
    final cfg = _config!;

    await konus(cfg.karsilamaMesaji);

    // Ses tanıma şu an Gemini üzerinden çalışır.
    // Birincil beyin başka seçilmiş olsa bile STT için Gemini gerekir.
    if (!settings.geminiHazir) {
      final beyin = settings.birincilEtiket;
      await konus(
        'Ses tanıma için Gemini API anahtarı gerekli. '
        'Ayarlar ekranından Gemini anahtarını ekle. '
        'Birincil beynin şu an $beyin olarak kayıtlı.',
      );
      durum = AresDurum.pasif;
      notifyListeners();
      return;
    }

    if (!settings.birincilHazir &&
        settings.birincilApi != ApiProvider.gemini) {
      final etiket = settings.birincilEtiket;
      await konus(
        'Seçtiğin birincil API için anahtar eksik. '
        'Ayarlar ekranından $etiket anahtarını ekle '
        'veya birincil beyni Gemini yap.',
      );
      // Yine de Gemini ile dinlemeye devam edebiliriz
    }

    durum = AresDurum.dinliyor;
    canliMetin = 'Sizi dinliyorum...';
    notifyListeners();

    String soylenen = '';
    try {
      soylenen = await _kaydetVeYaziyaCevir();
    } catch (e) {
      debugPrint('ARES: kayıt/tanıma hatası: $e');
      durum = AresDurum.isliyorum;
      notifyListeners();
      await konus('Bir hata oldu: $e');
      durum = AresDurum.pasif;
      notifyListeners();
      return;
    }

    durum = AresDurum.isliyorum;
    notifyListeners();

    if (soylenen.trim().isEmpty) {
      await konus('Sizi duyamadım, tekrar dener misiniz?');
    } else {
      sonSoylenen = soylenen.trim();
      notifyListeners();
      await _komutuIsle(soylenen);
    }

    durum = AresDurum.pasif;
    notifyListeners();
  }

  Future<String> _kaydetVeYaziyaCevir() async {
    final izinVar = await _kayitci.hasPermission();
    if (!izinVar) {
      throw Exception('mikrofon izni verilmemiş');
    }

    final gecici = await getTemporaryDirectory();
    final dosyaYolu =
        '${gecici.path}/ares_kayit_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _kayitci.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: dosyaYolu,
    );

    final sure = settings.dinlemeSuresi.clamp(3, 15);
    await Future.delayed(Duration(seconds: sure));

    final kaydedilenYol = await _kayitci.stop();
    if (kaydedilenYol == null) {
      throw Exception('kayıt durdurulamadı');
    }

    final dosya = File(kaydedilenYol);
    if (!await dosya.exists()) {
      throw Exception('kayıt dosyası oluşmadı');
    }

    final boyut = await dosya.length();
    if (boyut < 2000) {
      throw Exception(
          'kayıt neredeyse boş, $boyut bayt (mikrofon çalışmamış olabilir)');
    }

    return _gemininSesiYaziyaCevirmesi(dosya);
  }

  Future<String> _gemininSesiYaziyaCevirmesi(File sesDosyasi) async {
    final bayt = await sesDosyasi.readAsBytes();
    final base64Ses = base64Encode(bayt);

    // Her seferinde ayarlardan guncel model oku
    await settings.yukle();
    final tercih = settings.geminiModel.trim().isEmpty
        ? 'gemini-3.8-flash'
        : settings.geminiModel.trim();

    // Once secili model; basarisizsa sadece 3.x flash (2.5 yok - yeni kullanicida 404)
    final modeller = <String>[
      tercih,
      'gemini-3.8-flash',
      'gemini-3.7-flash',
      'gemini-3.6-flash',
      'gemini-3.5-flash',
    ];
    final sirali = <String>[];
    for (final m in modeller) {
      if (m.isNotEmpty && !sirali.contains(m)) sirali.add(m);
    }

    final anahtarlar = settings.geminiTumAnahtarlar;
    if (anahtarlar.isEmpty) {
      throw Exception('Gemini anahtar yok. Ayarlardan ekle.');
    }

    String sonHata = '';
    for (final key in anahtarlar) {
      for (final model in sirali) {
        try {
          final metin = await _geminiSesTekModel(base64Ses, model, key);
          debugPrint('ARES STT basarili model: $model');
          return metin;
        } catch (e) {
          sonHata = e.toString();
          debugPrint('ARES STT key/model hata: $e');
          if (sonHata.contains('401') ||
              sonHata.contains('403') ||
              sonHata.contains('API_KEY')) {
            // Bu anahtar gecersiz -> sonraki anahtar
            break;
          }
          if (sonHata.contains('429') || sonHata.contains('quota')) {
            // Kota dolu -> sonraki anahtar
            break;
          }
          // 404 vb. -> sonraki model
        }
      }
    }
    throw Exception(
      'Ses tanima basarisiz. ${anahtarlar.length} anahtar denendi. Son: $sonHata. '
      'Farkli projelerden Gemini anahtari ekle veya bekle.',
    );
  }

  Future<String> _geminiSesTekModel(String base64Ses, String model, String apiKey) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );

    final govde = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text':
                  'Bu ses kaydinda Turkce olarak soylenen komutu, baska hicbir '
                  'aciklama ya da noktalama eklemeden, sadece duz metin olarak yaz.'
            },
            {
              'inline_data': {'mime_type': 'audio/wav', 'data': base64Ses},
            },
          ],
        },
      ],
    });

    final yanit = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey.trim(),
          },
          body: govde,
        )
        .timeout(const Duration(seconds: 25));

    if (yanit.statusCode != 200) {
      throw Exception('Gemini hata kodu ${yanit.statusCode} ($model): '
          '${yanit.body.length > 150 ? yanit.body.substring(0, 150) : yanit.body}');
    }

    final data = jsonDecode(yanit.body) as Map<String, dynamic>;
    if (data['candidates'] == null) {
      final engelSebebi = data['promptFeedback']?['blockReason'];
      throw Exception(
          'Gemini yanit vermedi ($model)${engelSebebi != null ? ", sebep: $engelSebebi" : ""}');
    }

    final metin = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
    final sonuc = (metin ?? '').toString().trim();
    if (sonuc.isEmpty) {
      throw Exception('Gemini bos metin dondurdu ($model)');
    }
    return sonuc;
  }

  Future<void> _komutuIsle(String soylenen) async {
    final cfg = _config;
    if (cfg == null || soylenen.trim().isEmpty) {
      await konus(cfg?.anlasilmadiMesaji ?? 'Bunu anlayamadim.');
      return;
    }

    final ham = soylenen.trim();
    final temiz = _trKucuk(ham);

    // 1) Gorev listesi
    for (final gorev in cfg.gorevler) {
      if (gorev.tur == 'onek') {
        for (final onek in gorev.tetikleyiciler) {
          final onekTemiz = _trKucuk(onek);
          if (temiz.startsWith(onekTemiz)) {
            final parametre = ham.length > onek.trim().length
                ? ham.substring(onek.trim().length).trim()
                : ham;
            await _eylemiCalistir(gorev, parametre.isEmpty ? ham : parametre);
            return;
          }
        }
      } else {
        for (final tetik in gorev.tetikleyiciler) {
          if (temiz.contains(_trKucuk(tetik))) {
            await _eylemiCalistir(gorev, gorev.parametre ?? '');
            return;
          }
        }
      }
    }

    // 1b) Yerel komutlar: saat, tarih, hava (LLM gerekmez)
    if (await _yerelKomut(temiz, ham)) {
      return;
    }

    // 2) "YouTube ac", "WhatsAppi ac", "kamerayi baslat" (sonda ac/baslat)
    final acSonlari = <String>[
      ' uygulamasini ac',
      ' uygulamasini baslat',
      ' i ac',
      ' ı ac',
      ' yi ac',
      ' yı ac',
      ' u ac',
      ' ü ac',
      ' ac',
      ' baslat',
      ' aç',
      ' başlat',
    ];
    for (final son in acSonlari) {
      final sonTemiz = _trKucuk(son);
      if (temiz.endsWith(sonTemiz) && temiz.length > sonTemiz.length + 1) {
        var appAdi = ham;
        // Ham metinden son kismi dus
        final lowerHam = _trKucuk(ham);
        final idx = lowerHam.lastIndexOf(sonTemiz);
        if (idx > 0) {
          appAdi = ham.substring(0, idx).trim();
        }
        appAdi = appAdi.replaceAll(RegExp("[\"'.,!?]"), '').trim();
        // Turkce ekleri temizle: YouTube'u -> YouTube
        for (final ek in ["'u", "'ü", "'i", "'ı", "'yi", "'yı", " yi", " yı", " i", " ı", " u", " ü"]) {
          if (_trKucuk(appAdi).endsWith(_trKucuk(ek)) && appAdi.length > ek.length + 1) {
            appAdi = appAdi.substring(0, appAdi.length - ek.trim().length).trim();
          }
        }
        if (appAdi.isNotEmpty) {
          final bulundu = await onUygulamaAc?.call(appAdi) ?? false;
          if (bulundu) {
            await konus('$appAdi aciliyor.');
          } else {
            await konus(
              _config?.uygulamaBulunamadiMesaji ??
                  'Boyle bir uygulama bulamadim: $appAdi',
            );
          }
          return;
        }
      }
    }

    // Kural eslesmedi → birincil beyin ile kisa akilli yanit dene
    try {
      final llm = LlmService(settings);
      final akilli = await llm.akilliYanit(soylenen);
      if (akilli.trim().isNotEmpty) {
        await konus(akilli);
      } else {
        await konus(cfg.anlasilmadiMesaji);
      }
    } catch (e) {
      debugPrint('ARES akilli yanit hatasi: $e');
      await konus(
        'Komutu anlayamadim ve beyin yanit veremedi. '
        'Ayarlardan API anahtarini ve birincil beyni kontrol et.',
      );
    }
  }

  /// Yazılı komut (ARES kategorisinden veya başka yerden).
  Future<void> metinKomutuIsle(String metin) async {
    // Yazili komut: Gemini ses anahtari GEREKMEZ
    if (!_baslatildi) await baslat();
    await settings.yukle();
    _config = await _gorevleriYukle();
    final temiz = metin.trim();
    if (temiz.isEmpty) return;
    durum = AresDurum.isliyorum;
    sonSoylenen = temiz;
    canliMetin = '';
    notifyListeners();
    try {
      await _komutuIsle(temiz);
    } catch (e) {
      debugPrint('metinKomutuIsle hata: $e');
      await konus('Komut islenirken hata olustu.');
    }
    durum = AresDurum.pasif;
    notifyListeners();
  }


  Future<bool> _yerelKomut(String temiz, String ham) async {
    // Saat
    if (temiz.contains('saat kac') ||
        temiz.contains('saat kaç') ||
        temiz == 'saat' ||
        temiz.contains('saati soyle') ||
        temiz.contains('saati söyle')) {
      final now = DateTime.now();
      final s = now.hour.toString().padLeft(2, '0');
      final d = now.minute.toString().padLeft(2, '0');
      await konus('Saat $s $d.');
      return true;
    }
    // Tarih
    if (temiz.contains('tarih') ||
        temiz.contains('bugun ne') ||
        temiz.contains('bugün ne') ||
        temiz.contains('gunlerden') ||
        temiz.contains('günlerden') ||
        temiz.contains('hangi gun') ||
        temiz.contains('hangi gün')) {
      const gunler = [
        'pazartesi', 'sali', 'carsamba', 'persembe', 'cuma', 'cumartesi', 'pazar'
      ];
      const aylar = [
        'ocak', 'subat', 'mart', 'nisan', 'mayis', 'haziran',
        'temmuz', 'agustos', 'eylul', 'ekim', 'kasim', 'aralik'
      ];
      final now = DateTime.now();
      final gunAd = gunler[now.weekday - 1];
      final ayAd = aylar[now.month - 1];
      await konus(
        'Bugun ${now.day} $ayAd ${now.year}, $gunAd.',
      );
      return true;
    }
    // Hava - basit bilgi (widget zaten gosteriyor)
    if (temiz.contains('hava durumu') ||
        temiz.contains('hava nasil') ||
        temiz.contains('hava nasıl') ||
        temiz == 'hava') {
      await konus(
        'Hava bilgisini ekranin sag tarafindaki hava kutusunda gorebilirsin. '
        'Detayli tahmin icin "hava durumu ara" diyebilirsin.',
      );
      return true;
    }
    return false;
  }

  Future<void> _eylemiCalistir(AresTask gorev, String parametre) async {
    switch (gorev.eylem) {
      case 'kategori_ac':
        await onKategoriAc?.call(gorev.parametre ?? '');
        await konus(gorev.yanit ?? 'Açıyorum.');
        break;

      case 'uygulama_ac':
        final bulundu = await onUygulamaAc?.call(parametre) ?? false;
        if (bulundu) {
          await konus(
              _bicimlendir(gorev.yanit, parametre) ?? '$parametre açılıyor.');
        } else {
          await konus(
              _config?.uygulamaBulunamadiMesaji ?? 'Uygulama bulunamadı.');
        }
        break;

      case 'internette_ara':
        await onInternetAra?.call(parametre);
        await konus(
            _bicimlendir(gorev.yanit, parametre) ?? '$parametre aranıyor.');
        break;

      case 'soyle':
      default:
        await konus(gorev.yanit ?? '');
    }
  }

  /// Overlay X dugmesi: dinlemeyi/konusmayi kes, pasife don.
  Future<void> kapat() async {
    try {
      await _tts.stop();
      try {
        await _kayitci.stop();
      } catch (_) {}
    } catch (_) {}
    durum = AresDurum.pasif;
    canliMetin = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _kayitci.dispose();
    _tts.stop();
    super.dispose();
  }
}

