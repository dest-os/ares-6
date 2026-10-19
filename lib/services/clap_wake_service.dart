import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:detect_clap_sound_flutter/detect_clap_sound_flutter.dart';
import 'settings_service.dart';

/// Arka planda mikrofonu dinleyip art arda 2 el çırpma algılandığında
/// ARES'i uyandırır.
///
/// Hassasiyet SettingsService üzerinden ayarlanabilir:
/// - düşük  → daha uzun aralık, daha az yanlış tetikleme
/// - orta   → varsayılan
/// - yüksek → daha kısa aralık, daha hassas
class ClapWakeService {
  DetectClapSoundFlutter _plugin = DetectClapSoundFlutter();
  StreamSubscription<int>? _subscription;
  VoidCallback? _onCiftCirpma;
  DateTime? _sonOlay;
  DateTime? _ilkCirpma;
  bool _aktif = false;
  bool _izinAlindi = false;
  SettingsService? _settings;

  /// Debounce süresi (aynı çırpmanın yankısını yok say)
  Duration get _debounce {
    final h = _settings?.alkisHassasiyeti ?? 'yuksek';
    switch (h) {
      case 'düşük':
      case 'dusuk':
        return const Duration(milliseconds: 400);
      case 'yüksek':
      case 'yuksek':
        return const Duration(milliseconds: 100);
      default:
        return const Duration(milliseconds: 120);
    }
  }

  /// Iki cirpma arasindaki maksimum sure (daha genis pencere)
  Duration get _ciftCirpmaSuresi {
    final h = _settings?.alkisHassasiyeti ?? 'yuksek';
    switch (h) {
      case 'düşük':
      case 'dusuk':
        return const Duration(milliseconds: 2200);
      case 'yüksek':
      case 'yuksek':
        return const Duration(milliseconds: 2500);
      default:
        return const Duration(milliseconds: 2500);
    }
  }

  void ayarlariBagla(SettingsService settings) {
    _settings = settings;
  }

  /// Dinlemeyi başlatır. Mikrofon izni yoksa kullanıcıdan ister.
  Future<bool> baslat({required VoidCallback onCiftCirpma}) async {
    _onCiftCirpma = onCiftCirpma;
    try {
      bool izinVar = await _plugin.hasPermission() ?? false;
      if (!izinVar) {
        izinVar = await _plugin.requestPermission() ?? false;
      }
      if (!izinVar) {
        debugPrint('ClapWakeService: mikrofon izni reddedildi');
        return false;
      }
      _izinAlindi = true;
      _dinlemeyeBasla();
      debugPrint('ClapWakeService: dinleme başladı');
      return true;
    } catch (e) {
      debugPrint('ClapWakeService başlatılamadı: $e');
      return false;
    }
  }

  void _dinlemeyeBasla() {
    try {
      _plugin.startRecording();
      _aktif = true;
      _subscription?.cancel();
      _subscription = _plugin.onListenDetectSound().listen((_) {
        final simdi = DateTime.now();

        if (_sonOlay != null && simdi.difference(_sonOlay!) < _debounce) {
          return; // yankı, yok say
        }
        _sonOlay = simdi;

        if (_ilkCirpma == null ||
            simdi.difference(_ilkCirpma!) > _ciftCirpmaSuresi) {
          // İlk çırpma
          _ilkCirpma = simdi;
          debugPrint('ClapWakeService: 1. çırpma algılandı');
        } else {
          // İkinci çırpma → ARES'i uyandır
          _ilkCirpma = null;
          debugPrint('ClapWakeService: 2. çırpma → ARES uyandırılıyor');
          _onCiftCirpma?.call();
        }
      }, onError: (e) {
        debugPrint('ClapWakeService dinleme hatası: $e');
        // Hata olursa birkaç saniye sonra yeniden dene
        _yenidenBaslat();
      }, onDone: () {
        debugPrint('ClapWakeService stream kapandı, yeniden başlatılıyor');
        _yenidenBaslat();
      });
    } catch (e) {
      debugPrint('ClapWakeService _dinlemeyeBasla hatası: $e');
    }
  }

  /// Stream bozulursa sessizce yeniden başlat
  Future<void> _yenidenBaslat() async {
    if (!_izinAlindi) return;
    try {
      await Future.delayed(const Duration(milliseconds: 800));
      await duraklat();
      await Future.delayed(const Duration(milliseconds: 300));
      _plugin = DetectClapSoundFlutter();
      _dinlemeyeBasla();
    } catch (e) {
      debugPrint('ClapWakeService yeniden başlatma hatası: $e');
    }
  }

  /// ARES konuşurken/dinlerken mikrofon çakışmasın diye durdurulur.
  Future<void> duraklat() async {
    if (!_aktif) return;
    _aktif = false;
    try {
      await _subscription?.cancel();
      _subscription = null;
      await _plugin.stopRecording();
      try {
        _plugin.dispose();
      } catch (_) {}
    } catch (e) {
      debugPrint('ClapWakeService duraklatılamadı: $e');
    }
  }

  /// ARES görevini bitirince alkış dinlemeye geri döner.
  Future<void> devamEt() async {
    if (_aktif) return;
    if (!_izinAlindi) return;
    try {
      // Android'in eski ses oturumunu serbest bırakması için bekle
      await Future.delayed(const Duration(milliseconds: 500));
      _plugin = DetectClapSoundFlutter();
      _dinlemeyeBasla();
      debugPrint('ClapWakeService: dinleme devam ediyor');
    } catch (e) {
      debugPrint('ClapWakeService devam ettirilemedi: $e');
      // Bir kez daha dene
      await Future.delayed(const Duration(seconds: 1));
      try {
        _plugin = DetectClapSoundFlutter();
        _dinlemeyeBasla();
      } catch (e2) {
        debugPrint('ClapWakeService ikinci deneme de başarısız: $e2');
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
    try {
      _plugin.dispose();
    } catch (_) {}
  }
}
