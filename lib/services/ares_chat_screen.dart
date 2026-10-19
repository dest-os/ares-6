import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/settings_service.dart';
import '../services/llm_service.dart';
import '../services/ares_service.dart';
import 'settings_screen.dart';

class _Msg {
  final String rol;
  final String metin;
  _Msg({required this.rol, required this.metin});
  Map<String, dynamic> toJson() => {'rol': rol, 'metin': metin};
  factory _Msg.fromJson(Map<String, dynamic> j) =>
      _Msg(rol: j['rol'] ?? 'sen', metin: j['metin'] ?? '');
}

class _Konu {
  String id;
  String baslik;
  List<_Msg> mesajlar;
  _Konu({required this.id, required this.baslik, List<_Msg>? mesajlar})
      : mesajlar = mesajlar ?? [];
  Map<String, dynamic> toJson() => {
        'id': id,
        'baslik': baslik,
        'mesajlar': mesajlar.map((m) => m.toJson()).toList(),
      };
  factory _Konu.fromJson(Map<String, dynamic> j) => _Konu(
        id: '${j['id']}',
        baslik: '${j['baslik'] ?? 'Sohbet'}',
        mesajlar: ((j['mesajlar'] as List?) ?? [])
            .map((e) => _Msg.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class AresChatScreen extends StatefulWidget {
  final SettingsService settings;
  final AresService? ares;
  const AresChatScreen({super.key, required this.settings, this.ares});

  @override
  State<AresChatScreen> createState() => _AresChatScreenState();
}

class _AresChatScreenState extends State<AresChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  final _tts = FlutterTts();
  late final LlmService _llm;

  List<_Konu> _konular = [];
  String? _aktifId;
  final List<String> _ekler = [];
  bool _busy = false;
  bool _mic = false;
  bool _sesli = true;

  _Konu get _aktif {
    if (_konular.isEmpty) {
      final k = _Konu(id: '${DateTime.now().millisecondsSinceEpoch}', baslik: 'Yeni');
      _konular.add(k);
      _aktifId = k.id;
    }
    return _konular.firstWhere((k) => k.id == _aktifId, orElse: () => _konular.first);
  }

  @override
  void initState() {
    super.initState();
    _llm = LlmService(widget.settings);
    _tts.setLanguage('tr-TR');
    _tts.setSpeechRate(0.5);
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('ares_chat_konular');
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      setState(() {
        _konular = list
            .map((e) => _Konu.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (_konular.isNotEmpty) _aktifId = _konular.first.id;
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        'ares_chat_konular', jsonEncode(_konular.map((k) => k.toJson()).toList()));
  }

  Future<void> _pick() async {
    try {
      final r = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (r == null || r.files.isEmpty) return;
      setState(() {
        for (final f in r.files) {
          _ekler.add(f.name);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Dosya: $e')));
      }
    }
  }

  Future<void> _micTap() async {
    if (widget.ares == null || !widget.settings.geminiHazir) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Mikrofon icin Gemini anahtari gerekli')));
      }
      return;
    }
    setState(() => _mic = true);
    try {
      await widget.ares!.uyandirVeDinle();
      final m = widget.ares!.sonSoylenen;
      if (m.isNotEmpty) setState(() => _ctrl.text = m);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _mic = false);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty && _ekler.isEmpty) return;
    if (_busy) return;
    final full = _ekler.isEmpty ? text : '$text\n[Ek: ${_ekler.join(", ")}]';
    setState(() {
      _busy = true;
      _aktif.mesajlar.add(_Msg(rol: 'sen', metin: full));
      if (_aktif.baslik == 'Yeni' && text.isNotEmpty) {
        _aktif.baslik = text.length > 28 ? '${text.substring(0, 28)}...' : text;
      }
      _ctrl.clear();
      _ekler.clear();
    });
    _focus.unfocus();
    await _save();
    _toEnd();

    try {
      await widget.settings.yukle();
      // Otomatik yedek zinciri llm icinde
      final yanit = await _llm.akilliYanit(full);
      if (!mounted) return;
      setState(() => _aktif.mesajlar.add(_Msg(rol: 'ares', metin: yanit)));
      await _save();
      _toEnd();
      if (_sesli && yanit.isNotEmpty) await _tts.speak(yanit);
    } catch (e) {
      if (!mounted) return;
      setState(() => _aktif.mesajlar.add(_Msg(rol: 'ares', metin: 'Hata: $e')));
      await _save();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent + 40);
      }
    });
  }

  void _settings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xE00A1520),
      builder: (ctx) {
        final s = widget.settings;
        final ops = [
          if (s.geminiHazir) ApiProvider.gemini,
          if (s.nvidiaHazir) ApiProvider.nvidia,
          if (s.openaiHazir) ApiProvider.openai,
          if (s.grokHazir) ApiProvider.grok,
          if (s.claudeHazir) ApiProvider.claude,
          if (s.customHazir) ApiProvider.custom,
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                  title: Text('Beyin sec',
                      style: TextStyle(
                          color: Color(0xFF00BFFF),
                          fontWeight: FontWeight.bold))),
              ...ops.map((id) => ListTile(
                    leading: Icon(
                      s.birincilApi == id
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      color: const Color(0xFF00BFFF),
                    ),
                    title: Text(ApiProvider.etiket(id),
                        style: const TextStyle(color: Colors.white)),
                    onTap: () async {
                      s.birincilApi = id;
                      await s.kaydet();
                      if (ctx.mounted) Navigator.pop(ctx);
                      setState(() {});
                    },
                  )),
              ListTile(
                leading: const Icon(Icons.settings, color: Color(0xFF00BFFF)),
                title: const Text('Tum ayarlar',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SettingsScreen(settings: widget.settings),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final pad = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/ares_chat_bg.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(color: const Color(0xFF02050A)),
          ),

          // Ust seffaf kontroller
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Color(0xFF00BFFF), size: 22),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => setState(() => _sesli = !_sesli),
                    icon: Icon(_sesli ? Icons.volume_up : Icons.volume_off,
                        color: const Color(0xFF00BFFF).withOpacity(0.85)),
                  ),
                  IconButton(
                    onPressed: _settings,
                    icon: const Icon(Icons.settings, color: Color(0xFF00BFFF)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),

          // Mesajlar (sag panel bolgesi)
          Positioned(
            left: size.width * 0.30,
            right: size.width * 0.035,
            top: size.height * 0.11,
            bottom: 78 + pad,
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(8),
              itemCount: _aktif.mesajlar.length + (_busy ? 1 : 0),
              itemBuilder: (_, i) {
                if (_busy && i == _aktif.mesajlar.length) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF00BFFF)),
                      ),
                    ),
                  );
                }
                final m = _aktif.mesajlar[i];
                final me = m.rol == 'sen';
                return Align(
                  alignment:
                      me ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    constraints:
                        BoxConstraints(maxWidth: size.width * 0.42),
                    decoration: BoxDecoration(
                      color: me
                          ? const Color(0xFF00BFFF).withOpacity(0.3)
                          : Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF00BFFF).withOpacity(0.4)),
                    ),
                    child: Text(m.metin,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14)),
                  ),
                );
              },
            ),
          ),

          // Alt input — gorselin cubugu uzerinde, CALISIR
          Positioned(
            left: size.width * 0.28,
            right: size.width * 0.02,
            bottom: 12 + pad,
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_ekler.isNotEmpty)
                    SizedBox(
                      height: 24,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _ekler
                            .map((e) => Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Chip(
                                    label: Text(e,
                                        style: const TextStyle(fontSize: 10)),
                                    onDeleted: () =>
                                        setState(() => _ekler.remove(e)),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: Colors.black54,
                                    labelStyle:
                                        const TextStyle(color: Colors.white),
                                    deleteIconColor: Colors.white54,
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  Row(
                    children: [
                      // + dosya
                      IconButton(
                        onPressed: _pick,
                        icon: const Icon(Icons.add_circle_outline,
                            color: Color(0xFF00BFFF), size: 32),
                        tooltip: 'Dosya ekle',
                      ),
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _focus,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15),
                          cursorColor: const Color(0xFF00BFFF),
                          minLines: 1,
                          maxLines: 3,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'Mesaj yaz...',
                            hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.35)),
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.35),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide(
                                  color: const Color(0xFF00BFFF)
                                      .withOpacity(0.45)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide(
                                  color: const Color(0xFF00BFFF)
                                      .withOpacity(0.35)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: const BorderSide(
                                  color: Color(0xFF00BFFF), width: 1.4),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _mic ? null : _micTap,
                        icon: Icon(_mic ? Icons.mic : Icons.mic_none,
                            color: _mic
                                ? Colors.redAccent
                                : const Color(0xFF00BFFF)),
                      ),
                      IconButton(
                        onPressed: _busy ? null : _send,
                        icon: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF00BFFF)),
                              )
                            : const Icon(Icons.send,
                                color: Color(0xFF00BFFF)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
