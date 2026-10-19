import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shortcut.dart';

class ShortcutService {
  static const String _key = 'dest_os_shortcuts';

  Future<List<ShortcutItem>> getShortcuts(String category) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_key);
    if (data == null) return [];
    final List list = jsonDecode(data);
    return list
        .map((e) => ShortcutItem.fromJson(e))
        .where((s) => s.category == category)
        .toList();
  }

  Future<void> addShortcut(ShortcutItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_key);
    List list = data != null ? jsonDecode(data) : [];
    if (list.any((e) => e['id'] == item.id)) return;
    list.add(item.toJson());
    await prefs.setString(_key, jsonEncode(list));
  }

  Future<void> removeShortcut(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_key);
    if (data == null) return;
    List list = jsonDecode(data);
    list.removeWhere((e) => e['id'] == id);
    await prefs.setString(_key, jsonEncode(list));
  }

  // Yaygın uygulamalar (gerçek paket isimleriyle)
  static List<ShortcutItem> getAvailableApps(String category) {
    final all = [
      // SOSYAL
      ShortcutItem(id: 'whatsapp', name: 'WhatsApp', icon: '💬', category: 'SOSYAL', packageName: 'com.whatsapp'),
      ShortcutItem(id: 'instagram', name: 'Instagram', icon: '📸', category: 'SOSYAL', packageName: 'com.instagram.android'),
      ShortcutItem(id: 'telegram', name: 'Telegram', icon: '✈️', category: 'SOSYAL', packageName: 'org.telegram.messenger'),
      ShortcutItem(id: 'twitter', name: 'X', icon: '🐦', category: 'SOSYAL', packageName: 'com.twitter.android'),
      ShortcutItem(id: 'facebook', name: 'Facebook', icon: '👤', category: 'SOSYAL', packageName: 'com.facebook.katana'),
      ShortcutItem(id: 'tiktok', name: 'TikTok', icon: '🎵', category: 'SOSYAL', packageName: 'com.zhiliaoapp.musically'),
      ShortcutItem(id: 'youtube', name: 'YouTube', icon: '▶️', category: 'MEDYA', packageName: 'com.google.android.youtube'),
      ShortcutItem(id: 'netflix', name: 'Netflix', icon: '🎬', category: 'MEDYA', packageName: 'com.netflix.mediaclient'),
      ShortcutItem(id: 'spotify', name: 'Spotify', icon: '🎧', category: 'MEDYA', packageName: 'com.spotify.music'),
      ShortcutItem(id: 'chrome', name: 'Chrome', icon: '🌐', category: 'İNTERNET', packageName: 'com.android.chrome'),
      ShortcutItem(id: 'maps', name: 'Haritalar', icon: '🗺️', category: 'İNTERNET', packageName: 'com.google.android.apps.maps'),
      ShortcutItem(id: 'gmail', name: 'Gmail', icon: '📧', category: 'İŞ', packageName: 'com.google.android.gm'),
      ShortcutItem(id: 'drive', name: 'Drive', icon: '☁️', category: 'İŞ', packageName: 'com.google.android.apps.docs'),
      ShortcutItem(id: 'settings', name: 'Ayarlar', icon: '⚙️', category: 'SİSTEM', packageName: 'com.android.settings'),
      ShortcutItem(id: 'phone', name: 'Telefon', icon: '📞', category: 'DİĞER', packageName: 'com.android.dialer'),
      ShortcutItem(id: 'messages', name: 'Mesajlar', icon: '💬', category: 'DİĞER', packageName: 'com.android.mms'),
      ShortcutItem(id: 'camera', name: 'Kamera', icon: '📷', category: 'MEDYA', packageName: 'com.android.camera'),
      ShortcutItem(id: 'gallery', name: 'Galeri', icon: '🖼️', category: 'MEDYA', packageName: 'com.android.gallery3d'),
      ShortcutItem(id: 'calculator', name: 'Hesap Makinesi', icon: '🧮', category: 'ARAÇLAR', packageName: 'com.android.calculator2'),
      ShortcutItem(id: 'clock', name: 'Saat', icon: '⏰', category: 'ARAÇLAR', packageName: 'com.android.deskclock'),
      ShortcutItem(id: 'files', name: 'Dosyalar', icon: '📁', category: 'ARAÇLAR', packageName: 'com.android.documentsui'),
      ShortcutItem(id: 'playstore', name: 'Play Store', icon: '🛍️', category: 'İNTERNET', packageName: 'com.android.vending'),
      ShortcutItem(id: 'contacts', name: 'Rehber', icon: '👥', category: 'DİĞER', packageName: 'com.android.contacts'),
      ShortcutItem(id: 'calendar', name: 'Takvim', icon: '📅', category: 'İŞ', packageName: 'com.google.android.calendar'),
    ];

    return all.where((a) => a.category == category).toList();
  }
}
