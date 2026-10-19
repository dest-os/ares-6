import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/llm_service.dart';
import '../widgets/neon_container.dart';

/// Siberpunk temaya uygun Ayarlar paneli.
/// Buradan birden fazla API anahtarı eklenebilir / değiştirilebilir.
class SettingsScreen extends StatefulWidget {
  final SettingsService settings;

  const SettingsScreen({super.key, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _geminiCtrl;
  late final TextEditingController _geminiCtrl2;
  late final TextEditingController _geminiCtrl3;
  late final TextEditingController _openaiCtrl;
  late final TextEditingController _claudeCtrl;
  late final TextEditingController _grokCtrl;
  late final TextEditingController _nvidiaCtrl;
  late final TextEditingController _nvidiaModelCtrl;
  late final TextEditingController _agentNameCtrl;
  late final TextEditingController _openweatherCtrl;
  late final TextEditingController _githubTokenCtrl;
  late final TextEditingController _githubUserCtrl;
  late final TextEditingController _githubRepoCtrl;
  late final TextEditingController _customKeyCtrl;
  late final TextEditingController _customUrlCtrl;
  late final TextEditingController _sahipCtrl;
  late final TextEditingController _asistanCtrl;
  late final TextEditingController _modelCtrl;

  int _dinlemeSuresi = 6;
  String _alkisHassasiyeti = 'orta';
  String _birincilApi = ApiProvider.gemini;
  bool _kaydediliyor = false;
  bool _testEdiliyor = false;
  String? _testSonucu;
  String? _mesaj;
  bool _mesajBasarili = true;

  // Alanların görünürlüğü (şifre gibi gizleme)
  final Map<String, bool> _gorunur = {};

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _geminiCtrl = TextEditingController(text: s.geminiApiKey);
    final ek = s.geminiApiKeys;
    _geminiCtrl2 = TextEditingController(text: ek.isNotEmpty ? ek[0] : '');
    _geminiCtrl3 = TextEditingController(text: ek.length > 1 ? ek[1] : '');
    _openaiCtrl = TextEditingController(text: s.openaiApiKey);
    _claudeCtrl = TextEditingController(text: s.claudeApiKey);
    _grokCtrl = TextEditingController(text: s.grokApiKey);
    _nvidiaCtrl = TextEditingController(text: s.nvidiaApiKey);
    _nvidiaModelCtrl = TextEditingController(text: s.nvidiaModel);
    _agentNameCtrl = TextEditingController(text: s.customAgentName);
    _openweatherCtrl = TextEditingController(text: s.openweatherApiKey);
    _githubTokenCtrl = TextEditingController(text: s.githubToken);
    _githubUserCtrl = TextEditingController(text: s.githubUsername);
    _githubRepoCtrl = TextEditingController(text: s.githubRepo);
    _customKeyCtrl = TextEditingController(text: s.customApiKey);
    _customUrlCtrl = TextEditingController(text: s.customApiBaseUrl);
    _sahipCtrl = TextEditingController(text: s.sahipAdi);
    _asistanCtrl = TextEditingController(text: s.asistanAdi);
    _modelCtrl = TextEditingController(text: s.geminiModel);
    _dinlemeSuresi = s.dinlemeSuresi;
    _alkisHassasiyeti = s.alkisHassasiyeti;
    _birincilApi = s.birincilApi;
  }

  @override
  void dispose() {
    _geminiCtrl.dispose();
    _geminiCtrl2.dispose();
    _geminiCtrl3.dispose();
    _openaiCtrl.dispose();
    _claudeCtrl.dispose();
    _grokCtrl.dispose();
    _nvidiaCtrl.dispose();
    _nvidiaModelCtrl.dispose();
    _agentNameCtrl.dispose();
    _openweatherCtrl.dispose();
    _githubTokenCtrl.dispose();
    _githubUserCtrl.dispose();
    _githubRepoCtrl.dispose();
    _customKeyCtrl.dispose();
    _customUrlCtrl.dispose();
    _sahipCtrl.dispose();
    _asistanCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    setState(() {
      _kaydediliyor = true;
      _mesaj = null;
    });
    try {
      final s = widget.settings;
      s.geminiApiKey = _geminiCtrl.text;
    s.geminiApiKeys = [_geminiCtrl2.text, _geminiCtrl3.text]
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
      s.geminiApiKeys = [_geminiCtrl2.text, _geminiCtrl3.text]
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      s.openaiApiKey = _openaiCtrl.text;
      s.claudeApiKey = _claudeCtrl.text;
      s.grokApiKey = _grokCtrl.text;
      s.nvidiaApiKey = _nvidiaCtrl.text;
      s.nvidiaModel = _nvidiaModelCtrl.text.isEmpty
          ? 'meta/llama-3.1-8b-instruct'
          : _nvidiaModelCtrl.text;
      s.customAgentName =
          _agentNameCtrl.text.isEmpty ? 'Hermes' : _agentNameCtrl.text;
      s.openweatherApiKey = _openweatherCtrl.text;
      s.githubToken = _githubTokenCtrl.text;
      s.githubUsername = _githubUserCtrl.text;
      s.githubRepo = _githubRepoCtrl.text;
      s.customApiKey = _customKeyCtrl.text;
      s.customApiBaseUrl = _customUrlCtrl.text;
      s.sahipAdi = _sahipCtrl.text;
      s.asistanAdi = _asistanCtrl.text;
      s.geminiModel = _modelCtrl.text.isEmpty ? 'gemini-3.8-flash' : _modelCtrl.text;
      s.dinlemeSuresi = _dinlemeSuresi.clamp(3, 15);
      s.alkisHassasiyeti = _alkisHassasiyeti;
      s.birincilApi = _birincilApi;
      await s.kaydet();
      setState(() {
        _mesaj = 'Ayarlar kaydedildi! ARES yeni anahtarları kullanacak.';
        _mesajBasarili = true;
      });
    } catch (e) {
      setState(() {
        _mesaj = 'Kaydetme hatası: $e';
        _mesajBasarili = false;
      });
    } finally {
      setState(() => _kaydediliyor = false);
    }
  }


  Future<void> _baglantiTesti() async {
    // Formdaki degerleri yaz + diske kaydet (ARES de ayni anahtarlari gorsun)
    final s = widget.settings;
    s.geminiApiKey = _geminiCtrl.text;
    s.openaiApiKey = _openaiCtrl.text;
    s.claudeApiKey = _claudeCtrl.text;
    s.grokApiKey = _grokCtrl.text;
    s.nvidiaApiKey = _nvidiaCtrl.text;
    s.nvidiaModel = _nvidiaModelCtrl.text.isEmpty
        ? 'meta/llama-3.1-8b-instruct'
        : _nvidiaModelCtrl.text;
    s.customApiKey = _customKeyCtrl.text;
    s.customApiBaseUrl = _customUrlCtrl.text;
    s.customAgentName =
        _agentNameCtrl.text.isEmpty ? 'Hermes' : _agentNameCtrl.text;
    s.geminiModel =
        _modelCtrl.text.isEmpty ? 'gemini-3.8-flash' : _modelCtrl.text;
    s.birincilApi = _birincilApi;
    setState(() {
      _testEdiliyor = true;
      _testSonucu = null;
    });
    try {
      await s.kaydet();
      final sonuc = await LlmService(s).baglantiTesti();
      if (mounted) setState(() => _testSonucu = sonuc);
    } catch (e) {
      if (mounted) setState(() => _testSonucu = 'Hata: $e');
    } finally {
      if (mounted) setState(() => _testEdiliyor = false);
    }
  }

  Widget _bolumBasligi(String baslik, {IconData? ikon}) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          if (ikon != null) ...[
            Icon(ikon, color: const Color(0xFF00BFFF), size: 20),
            const SizedBox(width: 8),
          ],
          Text(
            baslik,
            style: const TextStyle(
              color: Color(0xFF00BFFF),
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }


  Widget _modelSecici({
    required String etiket,
    required String deger,
    required List<String> secenekler,
    List<String> eskiModeller = const [],
    required ValueChanged<String?> onChanged,
  }) {
    final tum = <String>[...secenekler];
    for (final e in eskiModeller) {
      if (!tum.contains(e)) tum.add(e);
    }
    if (deger.isNotEmpty && !tum.contains(deger)) {
      tum.insert(0, deger);
    }
    final secili = tum.contains(deger) && deger.isNotEmpty ? deger : tum.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiket,
            style: const TextStyle(
              color: Color(0xFF00BFFF),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00BFFF).withOpacity(0.45),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                dropdownColor: const Color(0xFF0A1520),
                value: secili,
                icon: const Icon(Icons.arrow_drop_down,
                    color: Color(0xFF00BFFF)),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                items: tum.map((m) {
                  final eski = eskiModeller.contains(m);
                  return DropdownMenuItem(
                    value: m,
                    child: Text(
                      m,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: eski ? Colors.redAccent : Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
          if (eskiModeller.contains(secili))
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Bu model kullanımdan kalkmis olabilir.',
                style: TextStyle(color: Colors.redAccent, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _apiAlani({
    required String etiket,
    required String ipucu,
    required TextEditingController controller,
    required String anahtarId,
    String? aciklama,
  }) {
    final gorunur = _gorunur[anahtarId] ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiket,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (aciklama != null) ...[
            const SizedBox(height: 2),
            Text(
              aciklama,
              style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11),
            ),
          ],
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            obscureText: !gorunur,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: ipucu,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: Colors.black.withOpacity(0.45),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFF00BFFF).withOpacity(0.4)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFF00BFFF).withOpacity(0.35)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00BFFF), width: 1.5),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  gorunur ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF00BFFF).withOpacity(0.7),
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _gorunur[anahtarId] = !gorunur);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _normalAlan({
    required String etiket,
    required TextEditingController controller,
    String? ipucu,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiket,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: ipucu,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: Colors.black.withOpacity(0.45),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFF00BFFF).withOpacity(0.4)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFF00BFFF).withOpacity(0.35)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00BFFF), width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02050A),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.85),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00BFFF)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'ARES AYARLAR',
          style: TextStyle(
            color: Color(0xFF00BFFF),
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFF00BFFF).withOpacity(0.4),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            12 + MediaQuery.of(context).viewInsets.bottom,
          ),
          children: [
            // Bilgi kartı
            NeonContainer(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF00BFFF), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Buraya girdiğin API anahtarları sadece bu cihazda saklanır. '
                      'ARES her uyandığında en güncel anahtarları kullanır.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            _bolumBasligi('KİŞİSEL', ikon: Icons.person),
            _normalAlan(etiket: 'Senin adın', controller: _sahipCtrl, ipucu: 'İbrahim'),
            _normalAlan(etiket: 'Asistan adı', controller: _asistanCtrl, ipucu: 'ARES'),

            _bolumBasligi('BAŞLANGIÇ BEYNİ (Birincil API)', ikon: Icons.smart_toy),
            NeonContainer(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ARES komutları işlerken önce bu API\'yi kullanır. '
                    'Ses tanıma şu an en iyi Gemini ile çalışır; diğerlerini '
                    'yedek / ileride akıllı yanıt için saklayabilirsin.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...ApiProvider.tumu.map((id) {
                    final secili = _birincilApi == id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _birincilApi = id),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: secili
                                ? const Color(0xFF00BFFF).withOpacity(0.22)
                                : Colors.black.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: secili
                                  ? const Color(0xFF00BFFF)
                                  : const Color(0xFF00BFFF).withOpacity(0.25),
                              width: secili ? 1.6 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                secili
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: const Color(0xFF00BFFF),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ApiProvider.etiket(id),
                                      style: TextStyle(
                                        color: secili
                                            ? const Color(0xFF00BFFF)
                                            : Colors.white.withOpacity(0.9),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      ApiProvider.aciklama(id),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.45),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            _bolumBasligi('YAPAY ZEKA API ANAHTARLARI', ikon: Icons.psychology),

            _apiAlani(
              etiket: 'Google Gemini API Anahtarı 1 (zorunlu)',
              ipucu: 'AIzaSy...',
              controller: _geminiCtrl,
              anahtarId: 'gemini',
              aciklama:
                  'https://aistudio.google.com — her anahtar FARKLI projeden olmali. Ayni proje kotayi paylasir.',
            ),
            _apiAlani(
              etiket: 'Gemini API Anahtarı 2 (opsiyonel, baska proje)',
              ipucu: 'AIzaSy... (proje 2)',
              controller: _geminiCtrl2,
              anahtarId: 'gemini2',
            ),
            _apiAlani(
              etiket: 'Gemini API Anahtarı 3 (opsiyonel, baska proje)',
              ipucu: 'AIzaSy... (proje 3)',
              controller: _geminiCtrl3,
              anahtarId: 'gemini3',
            ),
            _modelSecici(
              etiket: 'Gemini Model',
              deger: _modelCtrl.text,
              secenekler: const [
                'gemini-3.8-flash',
                'gemini-3.7-flash',
                'gemini-3.5-flash',
                'gemini-2.5-flash',
              ],
              onChanged: (v) {
                if (v != null) setState(() => _modelCtrl.text = v);
              },
            ),
            _apiAlani(
              etiket: 'OpenAI API Anahtarı (opsiyonel)',
              ipucu: 'sk-...',
              controller: _openaiCtrl,
              anahtarId: 'openai',
              aciklama: 'İleride ARES OpenAI modellerini de kullanabilecek.',
            ),
            _apiAlani(
              etiket: 'Claude (Anthropic) API Anahtarı (opsiyonel)',
              ipucu: 'sk-ant-...',
              controller: _claudeCtrl,
              anahtarId: 'claude',
            ),
            _apiAlani(
              etiket: 'Grok (xAI) API Anahtarı (opsiyonel)',
              ipucu: 'xai-...',
              controller: _grokCtrl,
              anahtarId: 'grok',
            ),
            _apiAlani(
              etiket: 'NVIDIA API Anahtarı (opsiyonel)',
              ipucu: 'nvapi-...',
              controller: _nvidiaCtrl,
              anahtarId: 'nvidia',
              aciklama:
                  'https://build.nvidia.com adresinden al. Açık kaynak modeller (Llama, Mistral vb.).',
            ),
            _modelSecici(
              etiket: 'NVIDIA Model',
              deger: _nvidiaModelCtrl.text,
              secenekler: const [
                'meta/llama-3.3-70b-instruct',
                'meta/llama3-70b-instruct',
                'meta/llama-3.3-70b-instruct',
                'google/gemma-2-9b-it',
                'microsoft/phi-3-mini-4k-instruct',
              ],
              eskiModeller: const [
                'meta/llama-3.1-8b-instruct',
                'meta/llama-3.1-70b-instruct',
              ],
              onChanged: (v) {
                if (v != null) setState(() => _nvidiaModelCtrl.text = v);
              },
            ),
            _apiAlani(
              etiket: 'Özel API / Ajan Anahtarı (opsiyonel)',
              ipucu: 'Kendi anahtarın veya ajan token',
              controller: _customKeyCtrl,
              anahtarId: 'custom',
              aciklama:
                  'Hermes, kendi sunucun veya OpenAI uyumlu herhangi bir endpoint.',
            ),
            _normalAlan(
              etiket: 'Özel API / Ajan Base URL',
              controller: _customUrlCtrl,
              ipucu: 'https://api.ornek.com/v1/chat/completions',
            ),
            _normalAlan(
              etiket: 'Ajan adı (gösterim)',
              controller: _agentNameCtrl,
              ipucu: 'Hermes',
            ),

            _bolumBasligi('DİĞER SERVİSLER', ikon: Icons.cloud),
            _apiAlani(
              etiket: 'OpenWeatherMap API (opsiyonel)',
              ipucu: 'Hava durumu için (şu an Open-Meteo kullanılıyor)',
              controller: _openweatherCtrl,
              anahtarId: 'weather',
            ),

            _bolumBasligi('GITHUB (ileride kullanılacak)', ikon: Icons.code),
            _normalAlan(etiket: 'GitHub Kullanıcı Adı', controller: _githubUserCtrl, ipucu: 'kullaniciadi'),
            _normalAlan(etiket: 'Depo Adı (Repository)', controller: _githubRepoCtrl, ipucu: 'dest-os-ares'),
            _apiAlani(
              etiket: 'GitHub Personal Access Token',
              ipucu: 'ghp_...',
              controller: _githubTokenCtrl,
              anahtarId: 'github',
              aciklama: 'repo okuma/yazma izni olan token. İleride otomatik push için.',
            ),

            _bolumBasligi('ARES DAVRANIŞI', ikon: Icons.tune),
            Text(
              'Dinleme süresi: $_dinlemeSuresi saniye',
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
            ),
            Slider(
              value: _dinlemeSuresi.toDouble(),
              min: 3,
              max: 12,
              divisions: 9,
              activeColor: const Color(0xFF00BFFF),
              inactiveColor: const Color(0xFF00BFFF).withOpacity(0.25),
              label: '$_dinlemeSuresi sn',
              onChanged: (v) => setState(() => _dinlemeSuresi = v.round()),
            ),
            const SizedBox(height: 8),
            Text(
              'Alkış hassasiyeti',
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
            ),
            const SizedBox(height: 6),
            Row(
              children: ['düşük', 'orta', 'yüksek'].map((h) {
                final secili = _alkisHassasiyeti == h;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => setState(() => _alkisHassasiyeti = h),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: secili
                              ? const Color(0xFF00BFFF).withOpacity(0.25)
                              : Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: secili
                                ? const Color(0xFF00BFFF)
                                : const Color(0xFF00BFFF).withOpacity(0.3),
                            width: secili ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          h.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: secili ? const Color(0xFF00BFFF) : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Kaydet butonu
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _kaydediliyor ? null : _kaydet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFFF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 8,
                  shadowColor: const Color(0xFF00BFFF).withOpacity(0.5),
                ),
                child: _kaydediliyor
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text(
                        'KAYDET',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 2,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                onPressed: (_kaydediliyor || _testEdiliyor) ? null : _baglantiTesti,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00BFFF),
                  side: const BorderSide(color: Color(0xFF00BFFF), width: 1.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _testEdiliyor
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF00BFFF)),
                      )
                    : const Text(
                        'BİRİNCİL BEYNİ TEST ET',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
            if (_testSonucu != null) ...[
              const SizedBox(height: 10),
              NeonContainer(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _testSonucu!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                  ),
                ),
              ),
            ],

            if (_mesaj != null) ...[
              const SizedBox(height: 14),
              NeonContainer(
                padding: const EdgeInsets.all(12),
                glowColor: _mesajBasarili ? const Color(0xFF00FF9C) : const Color(0xFFFF4D6A),
                child: Text(
                  _mesaj!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _mesajBasarili ? const Color(0xFF00FF9C) : const Color(0xFFFF4D6A),
                    fontSize: 13,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),
            Text(
              'Aktif API\'ler: ${widget.settings.aktifApiListesi.isEmpty ? "Henüz yok" : widget.settings.aktifApiListesi.join(", ")}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
