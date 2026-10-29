import '../../widgets/bu_widgets.dart' show fileUrl;

/// Tek yemek: ad + (yönetici girdiyse) kalori. `kcal == null` -> kalori girilmemiş (0 yazılmaz).
class MenuDish {
  const MenuDish(this.name, [this.kcal]);

  final String name;
  final int? kcal;
}

/// Günün menüsü: yemek kalemleri + isteğe bağlı yönetici fotoğrafı + kalori (V870).
class MenuDay {
  const MenuDay({this.items = const [], this.imageUrl, this.dishes = const [], this.totalKcal, this.kcalComplete = false});

  final List<String> items;

  /// Mutlak adres (göreli `/files/...` yolu `fileUrl` ile çevrilmiştir); yoksa null.
  final String? imageUrl;

  /// `items` ile aynı sıra; sunucu alanı yoksa kalorisiz doldurulur.
  final List<MenuDish> dishes;

  /// Kalorisi bilinen yemeklerin toplamı; hiçbirinin kalorisi yoksa null.
  final int? totalKcal;

  /// Bütün yemeklerin kalorisi girilmişse true (false iken toplam "en az" diye gösterilir).
  final bool kcalComplete;

  bool get hasPhoto => imageUrl != null;

  /// Sunucu yanıtından (`/menu` öğesi ya da `/menu/today`) güvenle ayrıştırır.
  factory MenuDay.fromJson(Map<dynamic, dynamic> j) {
    final raw = j['imageUrl'];
    final img = raw is String && raw.trim().isNotEmpty ? fileUrl(raw.trim()) : null;
    final rawItems = j['items'];
    final items = [
      for (final x in (rawItems is List ? rawItems : const [])) '$x'.trim(),
    ].where((s) => s.isNotEmpty).toList();

    // `dishes[{name,kcal}]` varsa kalori oradan; yoksa (eski sunucu) `items` kalorisiz.
    final rawDishes = j['dishes'];
    final dishes = <MenuDish>[];
    if (rawDishes is List) {
      for (final d in rawDishes) {
        if (d is! Map) continue;
        final name = '${d['name'] ?? ''}'.trim();
        if (name.isEmpty) continue;
        final k = d['kcal'];
        dishes.add(MenuDish(name, k is num ? k.round() : null));
      }
    }
    final total = j['totalKcal'];
    return MenuDay(
      items: items,
      imageUrl: img,
      dishes: dishes.isNotEmpty ? dishes : [for (final s in items) MenuDish(s)],
      totalKcal: total is num ? total.round() : null,
      kcalComplete: j['kcalComplete'] == true,
    );
  }
}
