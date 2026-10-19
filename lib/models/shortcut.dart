class ShortcutItem {
  final String id;
  final String name;
  final String icon; // emoji yedek
  final String category;
  final String? packageName;

  ShortcutItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.category,
    this.packageName,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'category': category,
        'packageName': packageName,
      };

  factory ShortcutItem.fromJson(Map<String, dynamic> json) => ShortcutItem(
        id: json['id'],
        name: json['name'],
        icon: json['icon'] ?? '📱',
        category: json['category'],
        packageName: json['packageName'],
      );
}
