/// Ana ekran widget'larından gelen derin bağlantılar: `bukampus://<hedef>[/<id>]`.
///
/// Şema `bukampus` zaten iOS `CFBundleURLTypes` ve Android `intent-filter` (`<data android:scheme="bukampus"/>`)
/// içinde kayıtlıdır; gelen bağlantıyı `app_links` (ShareLinks) verir. `bukampus://s/{t}/{id}` paylaşım bağlantısıdır
/// (ShareType) ve BURADA tanınmaz. Saf Dart: UI'siz test edilir; bozuk girdide exception yerine null döner.
library;

/// Widget hedefi.
enum WidgetDest {
  home('home'),
  menu('menu'),
  timetable('timetable'),
  events('events'),
  event('events'),
  clubs('clubs'),
  club('clubs'),
  chat('chat'),
  qr('qr'),
  news('news'),
  newsItem('news'),
  search('search'),
  notifications('notifications'),
  discover('discover'),
  poll('poll'),
  exams('exams'),
  academic('academic');

  const WidgetDest(this.host);

  /// Bağlantıdaki ana makine bölümü (`bukampus://<host>`).
  final String host;
}

const String kWidgetScheme = 'bukampus';

/// Kimlik üst sınırı: JS güvenli tamsayı (paylaşım bağlantısıyla aynı).
const int _kMaxId = 9007199254740991;

class WidgetLink {
  const WidgetLink(this.dest, [this.id]);

  final WidgetDest dest;

  /// Yalnız [WidgetDest.event], [WidgetDest.club], [WidgetDest.newsItem], [WidgetDest.poll] için.
  final int? id;

  static const home = WidgetLink(WidgetDest.home);
  static const menu = WidgetLink(WidgetDest.menu);
  static const timetable = WidgetLink(WidgetDest.timetable);
  static const events = WidgetLink(WidgetDest.events);
  static const clubs = WidgetLink(WidgetDest.clubs);
  static const chat = WidgetLink(WidgetDest.chat);
  static const qr = WidgetLink(WidgetDest.qr);
  static const news = WidgetLink(WidgetDest.news);
  static const search = WidgetLink(WidgetDest.search);
  static const notifications = WidgetLink(WidgetDest.notifications);
  static const discover = WidgetLink(WidgetDest.discover);
  static const exams = WidgetLink(WidgetDest.exams);
  static const academic = WidgetLink(WidgetDest.academic);

  static WidgetLink event(int id) => WidgetLink(WidgetDest.event, id);
  static WidgetLink club(int id) => WidgetLink(WidgetDest.club, id);
  static WidgetLink newsItem(int id) => WidgetLink(WidgetDest.newsItem, id);

  /// Anket kimliği yoksa Ana Sayfa (sözleşme: anket yoksa `bukampus://home`).
  static WidgetLink poll(int? id) => id == null || id <= 0 ? home : WidgetLink(WidgetDest.poll, id);

  /// Snapshot'a yazılan adres.
  String get uri => id == null ? '$kWidgetScheme://${dest.host}' : '$kWidgetScheme://${dest.host}/$id';

  @override
  bool operator ==(Object other) => other is WidgetLink && other.dest == dest && other.id == id;

  @override
  int get hashCode => Object.hash(dest, id);

  @override
  String toString() => 'WidgetLink($uri)';

  /// Gelen adresi ayrıştırır; widget bağlantısı değilse (paylaşım `s`, başka şema, bozuk kimlik) null.
  /// Kabul: `bukampus://menu`, `bukampus:///menu`, `bukampus://events/12`, büyük/küçük harf fark etmez.
  static WidgetLink? parse(Object? raw) {
    try {
      final Uri? u = raw is Uri ? raw : (raw is String ? Uri.tryParse(raw.trim()) : null);
      if (u == null || u.scheme.toLowerCase() != kWidgetScheme || u.userInfo.isNotEmpty) return null;
      final seg = <String>[
        if (u.host.isNotEmpty) u.host.toLowerCase(),
        ...u.pathSegments.where((s) => s.isNotEmpty).map((s) => s.toLowerCase()),
      ];
      if (seg.isEmpty || seg.length > 2) return null;
      final head = seg.first;
      int? id;
      if (seg.length == 2) {
        if (!RegExp(r'^[0-9]{1,16}$').hasMatch(seg[1])) return null;
        id = int.tryParse(seg[1]);
        if (id == null || id <= 0 || id > _kMaxId) return null;
      }
      switch (head) {
        case 'home':
          return seg.length == 1 ? home : null;
        case 'menu':
          return seg.length == 1 ? menu : null;
        case 'timetable':
          return seg.length == 1 ? timetable : null;
        case 'events':
          return id == null ? events : event(id);
        case 'clubs':
          return id == null ? clubs : club(id);
        case 'chat':
          return seg.length == 1 ? chat : null;
        case 'qr':
          return seg.length == 1 ? qr : null;
        case 'news':
          return id == null ? news : newsItem(id);
        case 'search':
          return seg.length == 1 ? search : null;
        case 'notifications':
          return seg.length == 1 ? notifications : null;
        case 'discover':
          return seg.length == 1 ? discover : null;
        case 'exams':
          return seg.length == 1 ? exams : null;
        case 'academic':
          return seg.length == 1 ? academic : null;
        case 'poll':
          return poll(id);
        default:
          return null; // `s` (paylaşım) ve bilinmeyenler
      }
    } catch (_) {
      return null;
    }
  }
}
