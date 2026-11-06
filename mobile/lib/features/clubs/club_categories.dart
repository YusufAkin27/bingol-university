import 'package:flutter/widgets.dart';

import '../../core/api.dart';
import '../../core/icons/bu_icons.dart';

/// Kulüp kategorisi (GET /communities/categories): `key` süzme/gönderme değeri,
/// `name` sunucunun istek diline çevirdiği görünen ad. Bilinmeyen alanlar yok sayılır.
class ClubCategory {
  const ClubCategory({required this.key, required this.name, this.count, this.icon = '', this.sortOrder = 0});

  final String key;
  final String name;
  /// Kategorideki kulüp sayısı; yanıtta yoksa null (boş sayılmaz).
  final int? count;

  bool get isEmpty => count == 0;
  final String icon;
  final int sortOrder;

  /// Tek bir yanıt satırını okur; anahtar (`key`, yoksa `category`) boşsa null.
  static ClubCategory? fromJson(Object? e) {
    if (e is! Map) return null;
    final key = (e['key'] ?? e['category'] ?? '').toString().trim();
    if (key.isEmpty) return null;
    final name = (e['name'] ?? '').toString().trim();
    return ClubCategory(
      key: key,
      name: name.isEmpty ? capitalizeKey(key) : name,
      count: (e['count'] as num?)?.toInt(),
      icon: (e['icon'] ?? '').toString().trim(),
      sortOrder: (e['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  /// Yanıtı (admin sırası korunarak) okur; bozuk satırlar atlanır.
  static List<ClubCategory> parseList(Object? res) {
    if (res is! List) return const [];
    final seen = <String>{};
    return [
      for (final e in res)
        if (fromJson(e) case final c? when seen.add(c.key)) c,
    ];
  }

  /// Anahtarı (baş harfi büyük) gösterim metnine çevirir: adı bilinmeyen kategori için.
  static String capitalizeKey(String key) {
    final k = key.trim();
    return k.isEmpty ? k : k[0].toUpperCase() + k.substring(1);
  }

  /// `icon` değerine karşılık gelen simge; bilinmeyen değer varsayılan etikete düşer.
  static IconData iconFor(String icon) {
    switch (icon.toLowerCase()) {
      case 'sports':
      case 'sport':
        return BuIcons.trophy;
      case 'music':
        return BuIcons.music;
      case 'art':
      case 'arts':
        return BuIcons.palette;
      case 'tech':
      case 'technology':
        return BuIcons.cpu;
      case 'science':
      case 'education':
        return BuIcons.bookOpen;
      case 'social':
        return BuIcons.users;
      case 'health':
        return BuIcons.heart;
      case 'culture':
        return BuIcons.globe;
      // Genişletilmiş kategori listesi (V1550) ve eski varsayılan simge adları.
      case 'school':
      case 'career':
        return BuIcons.graduationCap;
      case 'theatre':
      case 'theater':
        return BuIcons.mic;
      case 'cinema':
        return BuIcons.clapperboard;
      case 'photo':
        return BuIcons.camera;
      case 'literature':
        return BuIcons.notebookPen;
      case 'library':
        return BuIcons.library;
      case 'history':
        return BuIcons.landmark;
      case 'bulb':
        return BuIcons.lightbulb;
      case 'language':
        return BuIcons.globe;
      case 'debate':
        return BuIcons.megaphone;
      case 'media':
        return BuIcons.newspaper;
      case 'software':
      case 'code':
        return BuIcons.laptop;
      case 'robotics':
        return BuIcons.cpu;
      case 'ai':
      case 'space':
        return BuIcons.atom;
      case 'gaming':
      case 'rocket':
        return BuIcons.zap;
      case 'engineering':
        return BuIcons.wrench;
      case 'nature':
        return BuIcons.compass;
      case 'hiking':
        return BuIcons.footprints;
      case 'football':
        return BuIcons.trophy;
      case 'volleyball':
        return BuIcons.volleyball;
      case 'fitness':
        return BuIcons.dumbbell;
      case 'volunteer':
        return BuIcons.hand;
      case 'travel':
        return BuIcons.backpack;
      case 'food':
        return BuIcons.utensils;
      case 'craft':
        return BuIcons.palette;
      case 'architecture':
        return BuIcons.building2;
      case 'politics':
        return BuIcons.vote;
      case 'finance':
        return BuIcons.chartPie;
      case 'fun':
        return BuIcons.star;
      default:
        return BuIcons.tag;
    }
  }
}

/// Etkin kategori listesinin süreç içi kopyası: kart ve ayrıntıdaki `category` anahtarı
/// buradan ada çevrilir. Liste yalnız AKTİF kategorileri taşır; pasif/silinmiş kategorideki
/// kulüp için ad bulunamaz ve anahtar (baş harfi büyük) gösterilir.
class ClubCategories {
  ClubCategories._();

  static List<ClubCategory> _active = const [];

  static List<ClubCategory> get active => _active;

  static void set(List<ClubCategory> list) => _active = list;

  @visibleForTesting
  static void reset() => _active = const [];

  /// Bulunan kategori; yoksa null (pasif/silinmiş).
  static ClubCategory? find(String? key) {
    final k = (key ?? '').trim();
    if (k.isEmpty) return null;
    for (final c in _active) {
      if (c.key == k) return c;
    }
    return null;
  }

  /// Anahtarın görünen adı: etkin listedeyse `name`, değilse anahtarın baş harfi büyük hâli.
  static String labelFor(String? key) {
    final k = (key ?? '').trim();
    if (k.isEmpty) return '';
    return find(k)?.name ?? ClubCategory.capitalizeKey(k);
  }

  /// Sunucudan okur ve süreç içi kopyayı günceller; hata sessizce yutulur (eski liste kalır).
  static Future<List<ClubCategory>?> load(ApiClient api) async {
    try {
      final list = ClubCategory.parseList(await api.get('/communities/categories'));
      _active = list;
      return list;
    } catch (_) {
      return null;
    }
  }
}
