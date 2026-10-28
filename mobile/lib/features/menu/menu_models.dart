import '../../widgets/bu_widgets.dart' show fileUrl;

/// Günün menüsü: yemek kalemleri + isteğe bağlı yönetici fotoğrafı.
class MenuDay {
  const MenuDay({this.items = const [], this.imageUrl});

  final List<String> items;

  /// Mutlak adres (göreli `/files/...` yolu `fileUrl` ile çevrilmiştir); yoksa null.
  final String? imageUrl;

  bool get hasPhoto => imageUrl != null;

  /// Sunucu yanıtından (`/menu` öğesi ya da `/menu/today`) güvenle ayrıştırır.
  factory MenuDay.fromJson(Map<dynamic, dynamic> j) {
    final raw = j['imageUrl'];
    final img = raw is String && raw.trim().isNotEmpty ? fileUrl(raw.trim()) : null;
    final rawItems = j['items'];
    return MenuDay(
      items: [
        for (final x in (rawItems is List ? rawItems : const [])) '$x'.trim(),
      ].where((s) => s.isNotEmpty).toList(),
      imageUrl: img,
    );
  }
}
