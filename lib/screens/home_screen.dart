import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/clock_widget.dart';
import '../widgets/status_bar_widget.dart';
import '../widgets/calendar_widget.dart';
import '../widgets/weather_widget.dart';
import '../widgets/shortcut_sheet.dart';
import '../widgets/ares_overlay.dart';
import '../widgets/ares_eye_pulse.dart';
import '../services/ares_service.dart';
import '../services/clap_wake_service.dart';
import '../services/settings_service.dart';
import 'settings_screen.dart';
import 'ares_chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final SettingsService _settings = SettingsService();
  late final AresService _ares;
  final ClapWakeService _clapWake = ClapWakeService();
  bool _aresMesgul = false;
  bool _hazir = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ares = AresService(settings: _settings);
    _baslat();
  }

  Future<void> _baslat() async {
    await _settings.yukle();
    _clapWake.ayarlariBagla(_settings);

    _ares.onKategoriAc = (kategori) async {
      _openCategory(context, kategori);
    };
    _ares.onUygulamaAc = _uygulamaAc;
    _ares.onInternetAra = _internetteAra;

    await _ares.baslat();

    // Alkış dinlemeyi başlat
    final basarili = await _clapWake.baslat(onCiftCirpma: _aresUyandir);
    if (!basarili && mounted) {
      debugPrint('Alkış izni alınamadı – göz simgesine dokunarak ARES\'i uyandırabilirsiniz.');
    }

    if (mounted) {
      setState(() => _hazir = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _clapWake.duraklat();
    } else if (state == AppLifecycleState.resumed) {
      // Sistem cubuklarini tekrar gizle
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      if (!_aresMesgul) {
        _clapWake.devamEt();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clapWake.dispose();
    _ares.dispose();
    super.dispose();
  }

  void _openCategory(BuildContext context, String category) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ShortcutSheet(
        category: category,
        onSettingsTap: category == 'ARES' ? _ayarlariAc : null,
        onTextCommand: category == 'ARES'
            ? (metin) async {
                if (_aresMesgul) return;
                _aresMesgul = true;
                await _clapWake.duraklat();
                try {
                  await _ares.metinKomutuIsle(metin);
                } finally {
                  await _clapWake.devamEt();
                  _aresMesgul = false;
                }
              }
            : null,
      ),
    );
  }

  void _ayarlariAc() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(settings: _settings),
      ),
    ).then((_) {
      // Ayarlar kapanınca hassasiyeti güncelle
      _clapWake.ayarlariBagla(_settings);
    });
  }

  Future<void> _aresUyandir() async {
    if (_aresMesgul) return;
    _aresMesgul = true;
    await _clapWake.duraklat();
    try {
      await _ares.uyandirVeDinle();
    } finally {
      await _clapWake.devamEt();
      _aresMesgul = false;
    }
  }

  Future<bool> _uygulamaAc(String soylenenAd) async {
    try {
      // Sistem uygulamalari da dahil (Kamera, Ayarlar vb.)
      final apps = await InstalledApps.getInstalledApps(false, false);
      final aranan = _sadelestir(soylenenAd);
      if (aranan.isEmpty) return false;

      // Skorlama: en iyi esleseni sec
      String? enIyiPaket;
      int enIyiSkor = 0;

      for (final app in apps) {
        final ad = _sadelestir(app.name);
        if (ad.isEmpty) continue;
        int skor = 0;
        if (ad == aranan) {
          skor = 100;
        } else if (ad.startsWith(aranan) || aranan.startsWith(ad)) {
          skor = 80;
        } else if (ad.contains(aranan) || aranan.contains(ad)) {
          skor = 60;
        } else {
          final kelimeler = aranan.split(' ').where((k) => k.length > 1).toList();
          if (kelimeler.isNotEmpty && kelimeler.every((k) => ad.contains(k))) {
            skor = 50;
          }
        }
        if (skor > enIyiSkor) {
          enIyiSkor = skor;
          enIyiPaket = app.packageName;
        }
      }

      if (enIyiPaket != null && enIyiSkor >= 50) {
        await InstalledApps.startApp(enIyiPaket);
        return true;
      }
    } catch (e) {
      debugPrint('ARES: uygulama acma hatasi: $e');
    }
    return false;
  }

  String _sadelestir(String s) {
    return s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase().trim();
  }

  Future<void> _internetteAra(String sorgu) async {
    final temiz = sorgu.trim();
    if (temiz.isEmpty) return;
    final url = Uri.parse(
        'https://www.google.com/search?q=${Uri.encodeComponent(temiz)}');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('ARES: arama açılamadı: $e');
    }
  }


  static const _navChannel = MethodChannel('com.destos.ares/nav');

  /// Sol ok: launcher'i kucult, arka plandaki uygulamaya gec
  Future<void> _launcherKucult() async {
    try {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      await _ares.kapat();
      await _navChannel.invokeMethod('moveToBack');
    } catch (e) {
      debugPrint('moveToBack: $e');
    }
  }

  /// Ev: ARES ayarlari
  void _chatAc() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AresChatScreen(
          settings: _settings,
          ares: _ares,
        ),
      ),
    );
  }

  void _aresAyarlariniAc() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(settings: _settings),
      ),
    );
  }

  /// Sag: yuklu uygulamalar listesi (gecis)
  Future<void> _sonUygulamalariGoster() async {
    List<AppInfo> apps = [];
    try {
      apps = await InstalledApps.getInstalledApps(false, false); // ikonsuz = hizli
    } catch (e) {
      debugPrint('Uygulama listesi: $e');
    }
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A1520),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.55,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BFFF).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Uygulamalar',
                    style: TextStyle(
                      color: Color(0xFF00BFFF),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Expanded(
                  child: apps.isEmpty
                      ? const Center(
                          child: Text(
                            'Liste alinamadi',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.builder(
                          itemCount: apps.length,
                          itemBuilder: (_, i) {
                            final app = apps[i];
                            final name = app.name?.toString() ?? app.packageName?.toString() ?? '?';
                            final pkg = app.packageName?.toString() ?? '';
                            return ListTile(
                              leading: app.icon != null
                                  ? Image.memory(app.icon!, width: 36, height: 36)
                                  : const Icon(Icons.android, color: Color(0xFF00BFFF)),
                              title: Text(
                                name,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                              onTap: () async {
                                Navigator.pop(ctx);
                                if (pkg.isNotEmpty) {
                                  try {
                                    await InstalledApps.startApp(pkg);
                                  } catch (e) {
                                    debugPrint('Baslatma: $e');
                                  }
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _altNavDugme({
    required IconData ikon,
    required VoidCallback onTap,
    required String etiket,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 96,
        height: 48,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(ikon, color: const Color(0xFF00BFFF), size: 26),
            if (etiket.isNotEmpty)
              Text(
                etiket,
                style: const TextStyle(
                  color: Color(0xFF00BFFF),
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double w = size.width;
    final double h = size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Orijinal arka plan
          Image.asset(
            'assets/images/background.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) =>
                Container(color: const Color(0xFF02050A)),
          ),

          // ÜST SOL - Saat
          Positioned(
            left: w * 0.013,
            top: h * 0.009,
            width: w * 0.369,
            height: h * 0.098,
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: ClockWidget(),
              ),
            ),
          ),

          // UST SAG - Durum simgeleri (sol saat ile ayni olcek)
          Positioned(
            left: w * 0.617,
            top: h * 0.009,
            width: w * 0.361,
            height: h * 0.098,
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: StatusBarWidget(),
              ),
            ),
          ),

          // SOL - Takvim
          Positioned(
            left: w * 0.029,
            top: h * 0.405,
            width: w * 0.244,
            height: h * 0.217,
            child: const CalendarWidget(),
          ),

          // SAĞ - Hava durumu
          Positioned(
            left: w * 0.725,
            top: h * 0.4406,
            width: w * 0.2417,
            height: h * 0.181,
            child: const WeatherWidget(),
          ),

          // =====================================================
          // KATEGORİLER
          // =====================================================

          // Isim-kategori arasi goz -> sohbet (buyuk, daire yok)
          Positioned(
            left: w * 0.445,
            top: h * 0.565,
            width: w * 0.11,
            height: w * 0.11,
            child: GestureDetector(
              onTap: _chatAc,
              behavior: HitTestBehavior.opaque,
              child: const Icon(
                Icons.remove_red_eye,
                color: Color(0xFF00BFFF),
                size: 42,
              ),
            ),
          ),

          // ÜST SIRA
          Positioned(
            left: w * 0.035,
            top: h * 0.664,
            width: w * 0.222,
            height: h * 0.079,
            child: GestureDetector(
              onTap: () => _openCategory(context, 'SOSYAL'),
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: w * 0.277,
            top: h * 0.664,
            width: w * 0.213,
            height: h * 0.079,
            child: GestureDetector(
              onTap: () => _openCategory(context, 'ARES'),
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: w * 0.509,
            top: h * 0.664,
            width: w * 0.212,
            height: h * 0.079,
            child: GestureDetector(
              onTap: () => _openCategory(context, 'MEDYA'),
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: w * 0.740,
            top: h * 0.664,
            width: w * 0.218,
            height: h * 0.079,
            child: GestureDetector(
              onTap: () => _openCategory(context, 'ARAÇLAR'),
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),

          // ALT SIRA
          Positioned(
            left: w * 0.035,
            top: h * 0.779,
            width: w * 0.222,
            height: h * 0.078,
            child: GestureDetector(
              onTap: () => _openCategory(context, 'İŞ'),
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: w * 0.277,
            top: h * 0.779,
            width: w * 0.213,
            height: h * 0.078,
            child: GestureDetector(
              onTap: () => _openCategory(context, 'SİSTEM'),
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: w * 0.509,
            top: h * 0.779,
            width: w * 0.212,
            height: h * 0.078,
            child: GestureDetector(
              onTap: () => _openCategory(context, 'İNTERNET'),
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: w * 0.740,
            top: h * 0.779,
            width: w * 0.218,
            height: h * 0.078,
            child: GestureDetector(
              onTap: () => _openCategory(context, 'DİĞER'),
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),

          // ARES nabiz - hexagon goz hizasi (ince ayar)
          Positioned(
            left: w * 0.392,
            top: h * 0.058,
            width: w * 0.216,
            height: w * 0.216,
            child: Center(
              child: AnimatedBuilder(
                animation: _ares,
                builder: (context, _) => AresEyePulse(
                  durum: _ares.durum,
                  boyut: w * 0.20,
                ),
              ),
            ),
          ),

          // ARES goz dokunma alani
          Positioned(
            left: w * 0.392,
            top: h * 0.058,
            width: w * 0.216,
            height: w * 0.216,
            child: GestureDetector(
              onTap: _aresUyandir,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),

          // Ayarlar: ARES kategorisi içinde (ana tasarım bozulmasın diye)


          // ALT NAV: arka plan simgelerinin uzerinde, yazi yok
          // Sol ok -> launcher kucult
          Positioned(
            left: w * 0.22,
            bottom: h * 0.012,
            width: w * 0.12,
            height: h * 0.06,
            child: GestureDetector(
              onTap: _launcherKucult,
              behavior: HitTestBehavior.opaque,
              child: const ColoredBox(color: Color(0x00000000)),
            ),
          ),
          // Orta ev -> Ayarlar
          Positioned(
            left: w * 0.44,
            bottom: h * 0.012,
            width: w * 0.12,
            height: h * 0.06,
            child: GestureDetector(
              onTap: _aresAyarlariniAc,
              behavior: HitTestBehavior.opaque,
              child: const ColoredBox(color: Color(0x00000000)),
            ),
          ),
          // Sag ... / kare -> uygulamalar
          Positioned(
            left: w * 0.66,
            bottom: h * 0.012,
            width: w * 0.12,
            height: h * 0.06,
            child: GestureDetector(
              onTap: () { _sonUygulamalariGoster(); },
              behavior: HitTestBehavior.opaque,
              child: const ColoredBox(color: Color(0x00000000)),
            ),
          ),

          // ARES durum gostergesi
          AresOverlay(ares: _ares),


          // İlk yükleme sırasında küçük bir indikatör
          if (!_hazir)
            Positioned(
              left: 0,
              right: 0,
              bottom: 80,
              child: Center(
                child: Text(
                  'ARES hazırlanıyor...',
                  style: TextStyle(
                    color: const Color(0xFF00BFFF).withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
