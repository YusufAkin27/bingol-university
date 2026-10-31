import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Ana Sayfa bölümleri (sabit "Bugün" bloğu hariç; o gizlenmez). Sıra = varsayılan sıra. [id] kalıcı kimliktir (yerel kayıtta saklanır): ADI ASLA DEĞİŞTİRMEYİN; yeni bölüm sona
/// eklenir, kaldırılan bölümün kimliği kayıttan sessizce atılır.
enum HomeSection {
  quickAccess('quickAccess', true),
  menu('menu', true),
  todayClasses('todayClasses', true),
  featuredNews('featuredNews', true),
  upcomingEvents('upcomingEvents', true),
  announcements('announcements', true);

  const HomeSection(this.id, this.defaultVisible);

  final String id;

  /// Varsayılan düzende görünür mü (Stitch v3: altı bölümün hepsi açık).
  final bool defaultVisible;

  static HomeSection? byId(Object? id) {
    for (final s in values) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// Hızlı Erişim kısayol havuzu (hedef rotalar mevcut ekranlardır). Kimlikler kalıcıdır.
enum HomeShortcut {
  news('news'),
  menu('menu'),
  events('events'),
  polls('polls'),
  schedule('schedule'),
  clubs('clubs'),
  chat('chat'),
  support('support'),
  search('search'),
  notifications('notifications'),
  bookmarks('bookmarks');

  const HomeShortcut(this.id);

  final String id;

  static HomeShortcut? byId(Object? id) {
    for (final s in values) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// Ana Sayfa düzeni: bölüm sırası + gizli bölümler + Hızlı Erişim kısayolları (seçili olanlar, SIRALI). Değişmezdir.
@immutable
class HomeLayout {
  const HomeLayout({required this.order, required this.hidden, required this.shortcutOn});

  /// Hızlı Erişim'deki en çok kısayol (5 slot).
  static const maxShortcuts = 5;

  /// Bütün bölümler, görüntüleme sırasıyla (gizliler dahil).
  final List<HomeSection> order;
  final Set<HomeSection> hidden;

  /// Seçili kısayollar, Hızlı Erişim sırasıyla (1..[maxShortcuts]).
  final List<HomeShortcut> shortcutOn;

  static const defaults = HomeLayout(
    order: HomeSection.values,
    hidden: <HomeSection>{},
    shortcutOn: [HomeShortcut.news, HomeShortcut.menu, HomeShortcut.events, HomeShortcut.polls, HomeShortcut.schedule],
  );

  bool isVisible(HomeSection s) => !hidden.contains(s);

  /// Görünür bölümler, sırayla.
  List<HomeSection> get visible => [for (final s in order) if (isVisible(s)) s];

  /// Hızlı Erişim'de gösterilecek kısayollar, sırayla (en çok 5).
  List<HomeShortcut> get shortcuts => shortcutOn;

  /// Havuzda seçili olmayan kısayollar (havuz sırasıyla).
  List<HomeShortcut> get shortcutPool => [for (final s in HomeShortcut.values) if (!shortcutOn.contains(s)) s];

  bool get isDefault => listEquals(order, defaults.order) && setEquals(hidden, defaults.hidden) && listEquals(shortcutOn, defaults.shortcutOn);

  HomeLayout _copy({List<HomeSection>? order, Set<HomeSection>? hidden, List<HomeShortcut>? shortcutOn}) =>
      HomeLayout(order: order ?? this.order, hidden: hidden ?? this.hidden, shortcutOn: shortcutOn ?? this.shortcutOn);

  HomeLayout setVisible(HomeSection s, bool visible) => _copy(hidden: {...hidden}..remove(s)..addAll(visible ? const [] : [s]));

  /// [from] dizinindeki bölümü, çıkarıldıktan sonraki [to] dizinine yerleştirir (`ReorderableListView.onReorderItem` kuralı).
  HomeLayout reorderSection(int from, int to) => _copy(order: _reorder(order, from, to));

  /// [s] bölümünü bir basamak yukarı (-1) / aşağı (+1) taşır; sınırda değişmez.
  HomeLayout moveSection(HomeSection s, int delta) {
    final i = order.indexOf(s);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= order.length) return this;
    return _copy(order: _reorder(order, i, j));
  }

  /// Seçili kısayollar arasında sıra değişimi (aynı kural).
  HomeLayout reorderShortcut(int from, int to) => _copy(shortcutOn: _reorder(shortcutOn, from, to));

  /// Kısayolu açar (sona eklenir)/kapatır. En çok [maxShortcuts] açık; son açık kısayol kapatılamaz.
  HomeLayout setShortcut(HomeShortcut s, bool on) {
    if (on) {
      if (shortcutOn.contains(s) || shortcutOn.length >= maxShortcuts) return this;
      return _copy(shortcutOn: [...shortcutOn, s]);
    }
    if (!shortcutOn.contains(s) || shortcutOn.length <= 1) return this;
    return _copy(shortcutOn: [...shortcutOn]..remove(s));
  }

  static List<T> _reorder<T>(List<T> l, int from, int to) {
    if (from < 0 || from >= l.length) return l;
    final t = to.clamp(0, l.length - 1);
    if (t == from) return l;
    final out = [...l];
    out.insert(t, out.removeAt(from));
    return out;
  }

  Map<String, dynamic> toJson(int uid) => {
        'v': 1,
        'u': uid,
        'order': [for (final s in order) s.id],
        'hidden': [for (final s in hidden) s.id],
        'sOn': [for (final s in shortcutOn) s.id],
      };

  /// Kayıttan okur; bozuk/eski/başka kullanıcıya ait kayıt güvenle [defaults]'a düşer. Bilinmeyen kimlikler atılır,
  /// kayıtta olmayan (yeni eklenmiş) bölümler varsayılan görünürlükle sona eklenir.
  static HomeLayout fromJson(Object? raw, int uid) {
    try {
      if (raw is! Map || raw['u'] != uid) return defaults;
      List<T> ids<T>(Object? v, T? Function(Object?) by) {
        final out = <T>[];
        for (final e in (v is List ? v : const [])) {
          final x = by(e);
          if (x != null && !out.contains(x)) out.add(x);
        }
        return out;
      }

      final order = ids<HomeSection>(raw['order'], HomeSection.byId);
      final known = {...order};
      final hidden = ids<HomeSection>(raw['hidden'], HomeSection.byId).where(known.contains).toSet();
      for (final s in HomeSection.values) {
        if (known.contains(s)) continue;
        order.add(s); // yeni bölüm: sona, varsayılan görünürlükle
        if (!s.defaultVisible) hidden.add(s);
      }
      var on = ids<HomeShortcut>(raw['sOn'], HomeShortcut.byId).take(maxShortcuts).toList();
      if (on.isEmpty) on = [...defaults.shortcutOn];
      return HomeLayout(order: order, hidden: hidden, shortcutOn: on);
    } catch (_) {
      return defaults;
    }
  }

  @override
  bool operator ==(Object other) => other is HomeLayout && listEquals(order, other.order) && setEquals(hidden, other.hidden) && listEquals(shortcutOn, other.shortcutOn);

  @override
  int get hashCode => Object.hash(Object.hashAll(order), Object.hashAllUnordered(hidden), Object.hashAll(shortcutOn));
}

/// Yerel ve kullanıcıya özel kalıcılık (sunucu ucu yok): güvenli depoda tek anahtar, kayıt kullanıcı kimliğini taşır.
/// Çıkış / hesap silme / oturum değişiminde [clear] silinir (bkz. `registerUserDataCleaners`, KVKK).
class HomeLayoutStore {
  const HomeLayoutStore._();

  static const key = 'home_layout';
  static const _storage = FlutterSecureStorage();

  /// [uid] null (kimlik henüz bilinmiyor) ise 0 kabul edilir.
  static Future<HomeLayout> load(int? uid) async {
    try {
      final raw = await _storage.read(key: key);
      if (raw == null) return HomeLayout.defaults;
      return HomeLayout.fromJson(jsonDecode(raw), uid ?? 0);
    } catch (_) {
      return HomeLayout.defaults;
    }
  }

  /// Varsayılan düzen kayıt tutmaz (anahtar silinir).
  static Future<void> save(HomeLayout layout, int? uid) async {
    try {
      if (layout.isDefault) {
        await _storage.delete(key: key);
      } else {
        await _storage.write(key: key, value: jsonEncode(layout.toJson(uid ?? 0)));
      }
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }
}

/// Ekranın tuttuğu düzen: değişince dinleyicilere haber verir ve kaydeder.
class HomeLayoutController extends ChangeNotifier {
  HomeLayoutController({this.uid});

  final int? uid;
  HomeLayout _value = HomeLayout.defaults;
  bool _loaded = false;

  HomeLayout get value => _value;
  bool get loaded => _loaded;

  Future<void> load() async {
    _value = await HomeLayoutStore.load(uid);
    _loaded = true;
    notifyListeners();
  }

  /// Düzeni değiştirir (aynıysa hiçbir şey yapmaz) ve kaydeder.
  void update(HomeLayout Function(HomeLayout current) f) {
    final next = f(_value);
    if (next == _value) return;
    _value = next;
    notifyListeners();
    HomeLayoutStore.save(next, uid);
  }

  void reset() => update((_) => HomeLayout.defaults);
}
