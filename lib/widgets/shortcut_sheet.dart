import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import '../models/shortcut.dart';
import '../services/shortcut_service.dart';
import 'neon_container.dart';

class ShortcutSheet extends StatefulWidget {
  final String category;
  final VoidCallback? onSettingsTap;
  final Future<void> Function(String metin)? onTextCommand;

  const ShortcutSheet({
    super.key,
    required this.category,
    this.onSettingsTap,
    this.onTextCommand,
  });

  @override
  State<ShortcutSheet> createState() => _ShortcutSheetState();
}

class _ShortcutSheetState extends State<ShortcutSheet> {
  List<ShortcutItem> _shortcuts = [];
  bool _loading = true;
  final Map<String, Uint8List?> _iconCache = {};

  bool get _isAres => widget.category == 'ARES';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await ShortcutService().getShortcuts(widget.category);
    if (mounted) {
      setState(() {
        _shortcuts = list;
        _loading = false;
      });
      _loadIcons(list);
    }
  }

  Future<void> _loadIcons(List<ShortcutItem> list) async {
    for (final item in list) {
      if (item.packageName == null) continue;
      if (_iconCache.containsKey(item.packageName)) continue;
      try {
        final apps = await InstalledApps.getInstalledApps(false, true);
        for (final app in apps) {
          if (app.packageName == item.packageName && app.icon != null) {
            _iconCache[item.packageName!] = app.icon;
            break;
          }
        }
        _iconCache.putIfAbsent(item.packageName!, () => null);
        if (mounted) setState(() {});
      } catch (_) {}
    }
  }

  Future<void> _remove(String id) async {
    await ShortcutService().removeShortcut(id);
    await _load();
  }

  Future<void> _launchApp(ShortcutItem item) async {
    if (item.packageName == null) return;
    try {
      await InstalledApps.startApp(item.packageName!);
    } catch (_) {}
  }

  void _showAddDialog() async {
    List<AppInfo> apps = [];
    try {
      apps = await InstalledApps.getInstalledApps(true, true);
      apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (_) {}
    final existing = _shortcuts.map((s) => s.id).toSet();
    final available =
        apps.where((a) => !existing.contains(a.packageName)).toList();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _AppPickerSheet(
        category: widget.category,
        apps: available,
        onAppSelected: (app) async {
          await ShortcutService().addShortcut(ShortcutItem(
            id: app.packageName,
            name: app.name,
            icon: '📱',
            category: widget.category,
            packageName: app.packageName,
          ));
          if (app.icon != null) _iconCache[app.packageName] = app.icon;
          if (ctx.mounted) Navigator.pop(ctx);
          await _load();
        },
      ),
    );
  }

  Widget _buildIcon(ShortcutItem item) {
    final bytes =
        item.packageName != null ? _iconCache[item.packageName] : null;
    if (bytes != null) {
      return Image.memory(bytes, width: 40, height: 40, fit: BoxFit.contain);
    }
    return Text(item.icon, style: const TextStyle(fontSize: 28));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E17),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF00BFFF).withOpacity(0.6), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                widget.category,
                style: const TextStyle(
                  color: Color(0xFF00BFFF),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (!_isAres)
                IconButton(
                  onPressed: _showAddDialog,
                  icon: const Icon(Icons.add_circle, color: Color(0xFF00BFFF)),
                ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white54),
              ),
            ],
          ),
          const Divider(color: Color(0xFF00BFFF), height: 16),
          if (_isAres && widget.onSettingsTap != null)
            NeonContainer(
              onTap: () {
                Navigator.pop(context);
                widget.onSettingsTap!();
              },
              borderRadius: 12,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: const Row(
                children: [
                  Icon(Icons.settings, color: Color(0xFF00BFFF), size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'ARES Ayarlari',
                      style: TextStyle(
                        color: Color(0xFF00BFFF),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Color(0xFF00BFFF)),
                ],
              ),
            ),
          if (_isAres)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Sohbet icin ana ekrandaki goz simgesine dokun.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13),
              ),
            )
          else if (_loading)
            const Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(color: Color(0xFF00BFFF)),
            )
          else if (_shortcuts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Bu kategoride kisayol yok.\n+ ile uygulama ekleyebilirsin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _shortcuts.length,
                itemBuilder: (_, i) {
                  final item = _shortcuts[i];
                  return ListTile(
                    leading: _buildIcon(item),
                    title: Text(item.name,
                        style: const TextStyle(color: Colors.white)),
                    onTap: () => _launchApp(item),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.white38),
                      onPressed: () => _remove(item.id),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _AppPickerSheet extends StatefulWidget {
  final String category;
  final List<AppInfo> apps;
  final Future<void> Function(AppInfo app) onAppSelected;

  const _AppPickerSheet({
    required this.category,
    required this.apps,
    required this.onAppSelected,
  });

  @override
  State<_AppPickerSheet> createState() => _AppPickerSheetState();
}

class _AppPickerSheetState extends State<_AppPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.apps
        .where((a) => a.name.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E17),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00BFFF).withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text('${widget.category} — Uygulama ekle',
              style: const TextStyle(
                  color: Color(0xFF00BFFF),
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 12),
          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Uygulama ara...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF00BFFF)),
              filled: true,
              fillColor: Colors.black45,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (v) => setState(() => _q = v),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final app = filtered[i];
                return ListTile(
                  leading: app.icon != null
                      ? Image.memory(app.icon!, width: 36, height: 36)
                      : const Icon(Icons.android, color: Color(0xFF00BFFF)),
                  title: Text(app.name,
                      style: const TextStyle(color: Colors.white)),
                  onTap: () => widget.onAppSelected(app),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
