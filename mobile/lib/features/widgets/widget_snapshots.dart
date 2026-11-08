/// Ana ekran widget'ları için snapshot JSON üreticileri (SAF; ağ/depo yok, UI'siz test edilir).
///
/// Sözleşme: design/widget-previews/DATA_CONTRACT.md. Her widget için TEK bir snapshot (`bu_widget_<slug>`) ve ortak
/// `bu_widget_meta` üretilir. Metinler alıcının dilinde HAZIR yazılır (widget'ta çeviri tablosu yok). KVKK: başka
/// kullanıcının adı, mesaj içeriği, fotoğrafı ASLA girmez; sosyal özet yalnız sayıdır.
library;

import '../academic/academic_models.dart' show Course, Semester, istanbulWall, slotsForDay, two;
import '../menu/menu_models.dart' show MenuDay;
import 'widget_link.dart';
import 'widget_strings.dart';

/// Sözleşme sürümü. Alan KALDIRMA/anlam değiştirme = sürüm artışı; alan EKLEME sürümü artırmaz.
const int kWidgetSchema = 1;

/// Paylaşımlı depo anahtarları.
const String kWidgetMetaKey = 'bu_widget_meta';

enum WidgetSlug {
  menu('menu', 'BUMenuWidget', 'MenuWidgetReceiver'),
  timetable('timetable', 'BUTimetableWidget', 'TimetableWidgetReceiver'),
  events('events', 'BUEventsWidget', 'EventsWidgetReceiver'),
  announcements('announcements', 'BUAnnouncementsWidget', 'AnnouncementsWidgetReceiver'),
  poll('poll', 'BUPollWidget', 'PollWidgetReceiver'),
  quickaccess('quickaccess', 'BUQuickAccessWidget', 'QuickAccessWidgetReceiver'),
  social('social', 'BUSocialWidget', 'SocialWidgetReceiver'),
  exams('exams', 'BUExamsWidget', 'ExamsWidgetReceiver'),
  academic('academic', 'BUAcademicWidget', 'AcademicWidgetReceiver');

  const WidgetSlug(this.slug, this.iosKind, this.androidReceiver);

  final String slug;

  /// WidgetKit `kind` (iOS ajanı widget'ı bu kind ile tanımlar).
  final String iosKind;

  /// Android AppWidgetProvider (GlanceAppWidgetReceiver) sınıf adı; paket `edu.bingol.bu_kampus.widgets`.
  final String androidReceiver;

  String get key => 'bu_widget_$slug';

  String get androidQualified => 'edu.bingol.bu_kampus.widgets.$androidReceiver';
}

// ---------------------------------------------------------------- girdi modelleri

class WidgetEventInput {
  const WidgetEventInput({required this.id, required this.title, required this.communityName, required this.startsAt, this.venue});

  final int id;
  final String title;
  final String communityName;
  final DateTime startsAt;
  final String? venue;
}

class WidgetNewsInput {
  const WidgetNewsInput({required this.id, required this.title, required this.publishedDay, this.sourceName, this.urgent = false});

  final int id;
  final String title;

  /// İstanbul takvim günü (UTC işaretli DateTime; yalnız y/m/d kullanılır).
  final DateTime publishedDay;
  final String? sourceName;
  final bool urgent;
}

/// Kullanıcının KENDİ sınavı (başkasının verisi girmez).
class WidgetExamInput {
  const WidgetExamInput({required this.id, required this.title, this.courseName, this.type = 'DIGER', required this.startsAt, this.room});

  final int id;
  final String title;
  final String? courseName;
  final String type; // VIZE | FINAL | BUT | QUIZ | ODEV | DIGER
  final DateTime startsAt;
  final String? room;
}

/// Herkese açık akademik takvim kaydı (dönem başı, ders kaydı, sınav haftası, tatil...).
class WidgetAcademicInput {
  const WidgetAcademicInput({required this.id, required this.kind, required this.title, required this.startsAt, this.endsAt});

  final int id;
  final String kind;
  final String title;
  final DateTime startsAt;
  final DateTime? endsAt;
}

class WidgetPollOptionInput {
  const WidgetPollOptionInput(this.label, [this.count = 0]);

  final String label;
  final int count;
}

class WidgetPollInput {
  const WidgetPollInput({
    required this.id,
    required this.question,
    required this.options,
    required this.userVoted,
    required this.resultsVisible,
    this.totalVotes,
    this.closesAt,
    this.multi = false,
  });

  final int id;
  final String question;
  final List<WidgetPollOptionInput> options;
  final bool userVoted;
  final bool resultsVisible;
  final int? totalVotes;
  final DateTime? closesAt;
  final bool multi;
}

/// Hızlı erişim kısayolu (kimlik kalıcıdır). Varsayılan sıra README'deki 8'li listedir.
class QuickAccessItem {
  const QuickAccessItem(this.id, this.icon, this.link);

  final String id;
  final String icon; // Lucide adı
  final WidgetLink link;
}

const List<QuickAccessItem> kQuickAccessCatalog = [
  QuickAccessItem('menu', 'utensils', WidgetLink.menu),
  QuickAccessItem('timetable', 'calendar-clock', WidgetLink.timetable),
  QuickAccessItem('events', 'ticket', WidgetLink.events),
  QuickAccessItem('clubs', 'users', WidgetLink.clubs),
  QuickAccessItem('chat', 'message-circle', WidgetLink.chat),
  QuickAccessItem('qr', 'qr-code', WidgetLink.qr),
  QuickAccessItem('news', 'newspaper', WidgetLink.news),
  QuickAccessItem('search', 'search', WidgetLink.search),
];

/// Small/2x2 için varsayılan 4 kısayol (README: 1 Yemek, 3 Etkinlik, 5 Sohbet, 6 QR Kodum).
const List<String> kQuickAccessSmallDefault = ['menu', 'events', 'chat', 'qr'];

// ---------------------------------------------------------------- yardımcılar

String _clip(String s, int max) {
  final t = s.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.length <= max) return t;
  return '${t.substring(0, max - 1).trimRight()}…';
}

String _isoDay(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';

/// Türkiye saati (UTC+3, yaz saati yok) ofsetli ISO-8601: `2026-11-06T14:30:00+03:00`.
String widgetIso(DateTime instant) {
  final w = istanbulWall(instant);
  return '${_isoDay(w)}T${two(w.hour)}:${two(w.minute)}:${two(w.second)}+03:00';
}

class WidgetSnapshotBuilder {
  WidgetSnapshotBuilder({required String lang, DateTime? now})
      : s = WidgetStrings.of(lang),
        now = now ?? DateTime.now();

  final WidgetStrings s;
  final DateTime now;

  String get lang => s.lang;
  DateTime get wallNow => istanbulWall(now);
  DateTime get today => DateTime.utc(wallNow.year, wallNow.month, wallNow.day);

  String dateLabel(DateTime day) => '${s.dayName(day.weekday)}, ${day.day} ${s.monthName(day.month)}';

  /// `prefix.` ile başlayan metinleri (a11y hariç) kısa anahtarla toplar; widget'ın ihtiyaç duyduğu TÜM sabit metinler.
  Map<String, String> _strings(String prefix) => {
        'signedOutTitle': s['signedOutTitle'],
        'signedOutSub': s['signedOutSub'],
        for (final k in s.keys)
          // `type.*` / `kind.*` yalnız üretimde etiket seçmek içindir (metaText hazır gelir), widget'a taşınmaz.
          if (k.startsWith('$prefix.') && k != '$prefix.a11y' && !k.startsWith('$prefix.type.') && !k.startsWith('$prefix.kind.'))
            k.substring(prefix.length + 1): s[k],
      };

  Map<String, Object?> _env(WidgetSlug slug, String state,
          {required String deepLink, required String a11y, required String prefix, DateTime? expiresAt}) =>
      {
        'schema': kWidgetSchema,
        'slug': slug.slug,
        'state': state, // ok | empty | signedOut
        'generatedAt': widgetIso(now),
        'expiresAt': expiresAt == null ? null : widgetIso(expiresAt),
        'lang': lang,
        'rtl': s.rtl,
        'deepLink': deepLink,
        'a11y': a11y,
        'strings': _strings(prefix),
      };

  static const _prefix = {
    WidgetSlug.menu: 'm',
    WidgetSlug.timetable: 't',
    WidgetSlug.events: 'e',
    WidgetSlug.announcements: 'a',
    WidgetSlug.poll: 'p',
    WidgetSlug.quickaccess: 'q',
    WidgetSlug.social: 's',
    WidgetSlug.exams: 'x',
    WidgetSlug.academic: 'c',
  };

  /// Gün sonu (ertesi gün 00:00 İstanbul) gerçek anlık.
  DateTime _endOfDay(DateTime wallDay) => DateTime.utc(wallDay.year, wallDay.month, wallDay.day + 1).subtract(const Duration(hours: 3));

  // ------------------------------------------------------------ meta

  /// `bu_widget_meta`. [signedIn] false iken `strings` "Giriş yap" boş durumunu taşır (snapshot'lar silinmiştir).
  Map<String, Object?> meta({required bool signedIn}) => {
        'schema': kWidgetSchema,
        'updatedAt': widgetIso(now),
        'lang': lang,
        'rtl': s.rtl,
        'theme': 'system',
        'signedIn': signedIn,
        'strings': {'signedOutTitle': s['signedOutTitle'], 'signedOutSub': s['signedOutSub'], 'appName': s['appName']},
      };

  /// Oturumsuz durum (testlerde ve gerekirse doğrudan yazım için). Üretimde çıkışta snapshot SİLİNİR.
  Map<String, Object?> signedOut(WidgetSlug slug) => _env(slug, 'signedOut',
      deepLink: WidgetLink.home.uri, a11y: '${s['appName']}: ${s['signedOutTitle']}', prefix: _prefix[slug]!);

  // ------------------------------------------------------------ menü

  Map<String, Object?> _menuDay(DateTime day, MenuDay? m) {
    final dishes = m?.dishes ?? const [];
    if (m == null || dishes.isEmpty) {
      return {
        'date': _isoDay(day),
        'dateLabel': dateLabel(day),
        'empty': true,
        'meals': <Object?>[],
        'totalKcal': null,
        'totalText': null,
        'totalLine': null,
        'kcalComplete': false,
        'small': null,
      };
    }
    final total = m.totalKcal;
    final totalNum = total == null ? null : '${m.kcalComplete ? '' : '~'}${s.num(total)}';
    final unit = s['m.kcalUnit'];
    final items = [
      for (final d in dishes.take(16))
        {'name': _clip(d.name, 60), 'kcal': d.kcal, 'kcalText': d.kcal == null ? null : '${s.num(d.kcal!)} $unit'},
    ];
    final names = [for (final i in items) i['name'] as String];
    return {
      'date': _isoDay(day),
      'dateLabel': dateLabel(day),
      'empty': false,
      // Backend yemeği öğüne ayırmaz (tek liste = öğle): tek öğün. Akşam öğünü gelirse `meals`a ikinci öğe eklenir.
      'meals': [
        {
          'id': 'lunch',
          'label': s['m.caption'],
          'items': items,
          'totalKcal': total,
          'totalText': totalNum == null ? null : '$totalNum $unit',
        }
      ],
      'totalKcal': total,
      'totalText': totalNum == null ? null : '$totalNum $unit',
      'totalLine': totalNum == null ? null : s.fill('m.totalLine', {'kcal': totalNum}),
      'kcalComplete': m.kcalComplete,
      'small': {
        'caption': s['m.caption'],
        'main': names.first,
        'sub': names.length > 1 ? names.skip(1).take(3).join(' · ') : null,
        'kcalLine': totalNum == null ? null : s.fill('m.kcalToday', {'kcal': totalNum}),
      },
    };
  }

  /// [byDay]: İstanbul takvim günü (UTC 00:00) -> menü. Bugün + sonraki en çok 2 gün yazılır (gece yarısı geçişi).
  Map<String, Object?> menu(Map<DateTime, MenuDay> byDay) {
    final days = <DateTime>[today, today.add(const Duration(days: 1)), today.add(const Duration(days: 2))];
    final todayMenu = byDay[today];
    final first = _menuDay(today, todayMenu);
    final upcoming = [
      for (final d in days.skip(1))
        if (byDay[d] != null && byDay[d]!.dishes.isNotEmpty) _menuDay(d, byDay[d]),
    ];
    final lastDay = upcoming.isEmpty ? today : DateTime.parse('${upcoming.last['date']}T00:00:00Z');
    final empty = first['empty'] == true;
    final items = empty
        ? ''
        : [for (final e in ((first['meals'] as List).first as Map)['items'] as List) '${(e as Map)['name']}'].take(6).join(', ');
    return {
      ..._env(WidgetSlug.menu, empty ? 'empty' : 'ok',
          deepLink: WidgetLink.menu.uri,
          a11y: empty ? s['m.emptyTitle'] : s.fill('m.a11y', {'items': items}),
          prefix: 'm',
          expiresAt: _endOfDay(lastDay)),
      ...first,
      'upcoming': upcoming,
    };
  }

  // ------------------------------------------------------------ ders programı

  Map<String, Object?> _timetableDay(DateTime day, List<Course> courses, Semester? sem) {
    final slots = slotsForDay(courses, sem, day);
    final lessons = [
      for (final sl in slots.take(8))
        {
          'start': sl.session.start,
          'end': sl.session.end,
          'startMin': sl.session.startMin,
          'endMin': sl.session.endMin,
          'title': _clip(sl.course.name, 60),
          'room': () {
            final r = sl.session.room?.trim() ?? '';
            return r.isEmpty ? null : (r.length > 8 ? r.substring(0, 8) : r);
          }(),
        },
    ];
    return {
      'date': _isoDay(day),
      'dateLabel': dateLabel(day),
      'dayName': s.dayName(day.weekday),
      'count': slots.length,
      'lessons': lessons,
    };
  }

  Map<String, Object?> timetable(List<Course> courses, Semester? sem) {
    final first = _timetableDay(today, courses, sem);
    final upcoming = [for (var i = 1; i <= 6; i++) _timetableDay(today.add(Duration(days: i)), courses, sem)];
    // Sıradaki ders (bugünden sonra ya da bugün henüz başlamamış): boş durum alt metni.
    Map<String, Object?>? next;
    final nowMin = wallNow.hour * 60 + wallNow.minute;
    outer:
    for (var i = 0; i <= 7; i++) {
      final day = today.add(Duration(days: i));
      for (final sl in slotsForDay(courses, sem, day)) {
        if (i == 0 && sl.session.startMin <= nowMin) continue;
        final time = sl.session.start;
        next = {
          'date': _isoDay(day),
          'time': time,
          'dayName': s.dayName(day.weekday),
          'dayShort': s.dayShort(day.weekday),
          'labelFull': '${s.dayName(day.weekday)} $time',
          'labelShort': '${s.dayShort(day.weekday)} $time',
        };
        break outer;
      }
    }
    final count = first['count'] as int;
    final lessons = first['lessons'] as List;
    final summary = count == 0
        ? s['t.emptyTitle']
        : lessons.take(4).map((e) => '${(e as Map)['start']} ${e['title']}').join(', ');
    return {
      ..._env(WidgetSlug.timetable, count == 0 ? 'empty' : 'ok',
          deepLink: WidgetLink.timetable.uri,
          a11y: s.fill('t.a11y', {'summary': summary}),
          prefix: 't',
          expiresAt: _endOfDay(today.add(const Duration(days: 6)))),
      ...first,
      'next': next,
      'upcoming': upcoming,
    };
  }

  // ------------------------------------------------------------ etkinlikler

  Map<String, Object?> events(List<WidgetEventInput> input) {
    final cutoff = now.subtract(const Duration(hours: 1));
    final list = input.where((e) => !e.startsAt.isBefore(cutoff)).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final items = [
      for (final e in list.take(3))
        () {
          final w = istanbulWall(e.startsAt);
          final venue = e.venue?.trim() ?? '';
          return {
            'id': e.id,
            'title': _clip(e.title, 80),
            'communityName': _clip(e.communityName, 40),
            'startsAt': widgetIso(e.startsAt),
            'day': '${w.day}',
            'monthCaps': s.monthCaps(w.month),
            'timeLabel': '${two(w.hour)}:${two(w.minute)}',
            'venue': venue.isEmpty ? null : _clip(venue, 40),
            'deepLink': WidgetLink.event(e.id).uri,
          };
        }(),
    ];
    final summary = items.isEmpty ? s['e.emptyTitle'] : items.map((e) => '${e['title']} ${e['day']} ${e['monthCaps']} ${e['timeLabel']}').join('; ');
    return {
      ..._env(WidgetSlug.events, items.isEmpty ? 'empty' : 'ok',
          deepLink: WidgetLink.events.uri,
          a11y: s.fill('e.a11y', {'summary': summary}),
          prefix: 'e',
          expiresAt: now.add(const Duration(hours: 36))),
      'count': items.length,
      'countLabel': s.fill('e.countLabel', {'n': '${items.length}'}),
      'events': items,
    };
  }

  // ------------------------------------------------------------ duyurular

  Map<String, Object?> announcements(List<WidgetNewsInput> input) {
    // Acil olanlar her zaman üste; kendi içinde ve diğerleri yayın tarihine göre azalan (kararlı sıra).
    final list = [...input];
    final indexed = {for (var i = 0; i < list.length; i++) list[i]: i};
    list.sort((a, b) {
      if (a.urgent != b.urgent) return a.urgent ? -1 : 1;
      final c = b.publishedDay.compareTo(a.publishedDay);
      return c != 0 ? c : indexed[a]!.compareTo(indexed[b]!);
    });
    final items = [
      for (final n in list.take(4))
        () {
          final dl = '${two(n.publishedDay.day)} ${s.monthShort(n.publishedDay.month)}';
          final src = (n.sourceName?.trim().isEmpty ?? true) ? null : _clip(n.sourceName!, 30);
          final urgentLabel = n.urgent ? s['a.urgent'] : null;
          return {
            'id': n.id,
            'title': _clip(n.title, 140),
            'sourceName': src,
            'publishedAt': _isoDay(n.publishedDay),
            'dateLabel': dl,
            'urgent': n.urgent,
            'urgentLabel': urgentLabel,
            'metaText': [if (urgentLabel != null) urgentLabel, if (src != null) src, dl].join(' · '),
            'deepLink': WidgetLink.newsItem(n.id).uri,
          };
        }(),
    ];
    final summary = items.isEmpty ? s['a.emptyTitle'] : items.take(3).map((e) => '${e['title']}').join('; ');
    return {
      ..._env(WidgetSlug.announcements, items.isEmpty ? 'empty' : 'ok',
          deepLink: WidgetLink.news.uri,
          a11y: s.fill('a.a11y', {'summary': summary}),
          prefix: 'a',
          expiresAt: now.add(const Duration(hours: 72))),
      'count': items.length,
      'lastLabel': s.fill('a.last', {'n': '${items.length}'}),
      'items': items,
    };
  }

  // ------------------------------------------------------------ sınavlar / akademik takvim
  // İkisi de duyuru snapshot'ıyla AYNI satır biçimini taşır (items[title, metaText, deepLink]); native tarafta tek
  // çizim kodu kullanılır. Göreli gün ("6 gün kaldı") YAZILMAZ: snapshot günü geçince yanlışlaşırdı; tarih mutlaktır.

  String _shortDate(DateTime d) => '${d.day} ${s.monthShort(d.month)}';

  Map<String, Object?> exams(List<WidgetExamInput> input) {
    final cutoff = now.subtract(const Duration(hours: 1));
    final list = input.where((e) => !e.startsAt.isBefore(cutoff)).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final items = [
      for (final e in list.take(4))
        () {
          final w = istanbulWall(e.startsAt);
          final day = DateTime.utc(w.year, w.month, w.day);
          final course = (e.courseName?.trim().isEmpty ?? true) ? e.title : e.courseName!;
          final type = s['x.type.${const {'VIZE', 'FINAL', 'BUT', 'QUIZ', 'ODEV'}.contains(e.type) ? e.type : 'DIGER'}'];
          final room = e.room?.trim() ?? '';
          final dl = _shortDate(day);
          return {
            'id': e.id,
            'title': _clip(course, 80),
            'sourceName': null,
            'publishedAt': _isoDay(day),
            'startsAt': widgetIso(e.startsAt),
            'dateLabel': dl,
            'urgent': false,
            'urgentLabel': null,
            'metaText': [type, '$dl ${two(w.hour)}:${two(w.minute)}', if (room.isNotEmpty) _clip(room, 12)].join(' · '),
            'deepLink': WidgetLink.exams.uri,
          };
        }(),
    ];
    final summary = items.isEmpty ? s['x.emptyTitle'] : items.take(3).map((e) => '${e['title']} ${e['metaText']}').join('; ');
    final firstEnd = list.isEmpty ? null : list.first.startsAt.add(const Duration(hours: 1));
    final cap = now.add(const Duration(hours: 72));
    return {
      ..._env(WidgetSlug.exams, items.isEmpty ? 'empty' : 'ok',
          deepLink: WidgetLink.exams.uri,
          a11y: s.fill('x.a11y', {'summary': summary}),
          prefix: 'x',
          expiresAt: firstEnd != null && firstEnd.isBefore(cap) ? firstEnd : cap),
      'count': items.length,
      'lastLabel': s.fill('x.last', {'n': '${items.length}'}),
      'items': items,
    };
  }

  Map<String, Object?> academic(List<WidgetAcademicInput> input) {
    DateTime dayOf(DateTime t) {
      final w = istanbulWall(t);
      return DateTime.utc(w.year, w.month, w.day);
    }

    DateTime endOf(WidgetAcademicInput e) {
      final d = e.endsAt == null ? dayOf(e.startsAt) : dayOf(e.endsAt!);
      return d.isBefore(dayOf(e.startsAt)) ? dayOf(e.startsAt) : d;
    }

    final list = input.where((e) => !endOf(e).isBefore(today)).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    String range(DateTime a, DateTime b) {
      if (a == b) return _shortDate(a);
      if (a.month == b.month) return '${a.day} – ${b.day} ${s.monthShort(b.month)}';
      return '${_shortDate(a)} – ${_shortDate(b)}';
    }

    final items = [
      for (final e in list.take(4))
        () {
          final a = dayOf(e.startsAt), z = endOf(e);
          final kind = s['c.kind.${const {'DONEM_BASLANGIC', 'DERS_KAYIT', 'VIZE', 'FINAL', 'BUT', 'TATIL', 'RESMI_TATIL'}.contains(e.kind) ? e.kind : 'DIGER'}'];
          return {
            'id': e.id,
            'title': _clip(e.title, 80),
            'sourceName': null,
            'publishedAt': _isoDay(a),
            'startsAt': widgetIso(e.startsAt),
            'dateLabel': range(a, z),
            'urgent': false,
            'urgentLabel': null,
            'metaText': '$kind · ${range(a, z)}',
            'deepLink': WidgetLink.academic.uri,
          };
        }(),
    ];
    final summary = items.isEmpty ? s['c.emptyTitle'] : items.take(3).map((e) => '${e['title']} ${e['dateLabel']}').join('; ');
    final firstEnd = list.isEmpty ? null : _endOfDay(endOf(list.first));
    final cap = now.add(const Duration(hours: 72));
    return {
      ..._env(WidgetSlug.academic, items.isEmpty ? 'empty' : 'ok',
          deepLink: WidgetLink.academic.uri,
          a11y: s.fill('c.a11y', {'summary': summary}),
          prefix: 'c',
          expiresAt: firstEnd != null && firstEnd.isBefore(cap) ? firstEnd : cap),
      'count': items.length,
      'lastLabel': s.fill('c.last', {'n': '${items.length}'}),
      'items': items,
    };
  }

  // ------------------------------------------------------------ anket

  /// Yüzdeleri 100'e yuvarlar (en büyük kalan yöntemi); çoklu seçimde her seçenek bağımsız yuvarlanır.
  static List<int> roundPercents(List<int> counts, {required bool normalize}) {
    final total = counts.fold<int>(0, (a, b) => a + b);
    if (total <= 0) return List.filled(counts.length, 0);
    if (!normalize) return [for (final c in counts) (c * 100 / total).round().clamp(0, 100)];
    final raw = [for (final c in counts) c * 100 / total];
    final floors = [for (final r in raw) r.floor()];
    var rest = 100 - floors.fold<int>(0, (a, b) => a + b);
    final order = List.generate(counts.length, (i) => i)..sort((a, b) => (raw[b] - floors[b]).compareTo(raw[a] - floors[a]));
    for (final i in order) {
      if (rest <= 0) break;
      floors[i]++;
      rest--;
    }
    return floors;
  }

  Map<String, Object?> poll(WidgetPollInput? p) {
    if (p == null || p.options.length < 2) {
      return {
        ..._env(WidgetSlug.poll, 'empty',
            deepLink: WidgetLink.home.uri,
            a11y: s.fill('p.a11y', {'summary': s['p.emptyTitle']}),
            prefix: 'p',
            expiresAt: now.add(const Duration(hours: 24))),
        'pollId': null,
        'question': null,
        'options': <Object?>[],
      };
    }
    final opts = p.options.take(4).toList();
    final showPct = p.userVoted && p.resultsVisible;
    final pct = showPct ? roundPercents([for (final o in opts) o.count], normalize: !p.multi) : null;
    var leader = -1;
    if (pct != null) {
      var best = 0;
      for (var i = 0; i < pct.length; i++) {
        if (pct[i] > best) {
          best = pct[i];
          leader = i;
        }
      }
    }
    final total = p.resultsVisible ? p.totalVotes : null;
    final votesLabel = total == null ? null : s.fill('p.voteCount', {'n': s.num(total)});
    final exp = p.closesAt != null && p.closesAt!.isBefore(now.add(const Duration(hours: 24))) ? p.closesAt! : now.add(const Duration(hours: 24));
    return {
      ..._env(WidgetSlug.poll, 'ok',
          deepLink: WidgetLink.poll(p.id).uri,
          a11y: s.fill('p.a11y', {'summary': _clip(p.question, 80)}),
          prefix: 'p',
          expiresAt: exp),
      'pollId': p.id,
      'question': _clip(p.question, 120),
      'userVoted': p.userVoted,
      'resultsVisible': showPct,
      'totalVotes': total,
      'totalVotesLabel': votesLabel,
      'microLine': votesLabel == null ? null : s.fill('p.voteMicro', {'votes': votesLabel}),
      'secretLine': votesLabel == null ? null : s.fill('p.secretLine', {'votes': votesLabel}),
      'leaderIndex': leader < 0 ? null : leader,
      'options': [
        for (var i = 0; i < opts.length; i++)
          {'label': _clip(opts[i].label, 40), 'percent': pct?[i], 'percentText': pct == null ? null : '%${pct[i]}'},
      ],
    };
  }

  // ------------------------------------------------------------ hızlı erişim

  /// [order]: kullanıcının seçtiği kısayol kimlikleri (boş/bozuk = varsayılan 8'li liste). Kataloğun hepsi 8'dir.
  Map<String, Object?> quickAccess({List<String> order = const []}) {
    final byId = {for (final c in kQuickAccessCatalog) c.id: c};
    final seen = <String>{};
    final chosen = <QuickAccessItem>[
      for (final id in order)
        if (byId.containsKey(id) && seen.add(id)) byId[id]!,
    ];
    for (final c in kQuickAccessCatalog) {
      if (seen.add(c.id)) chosen.add(c); // eksikler sona eklenir: her zaman 8 karo
    }
    final custom = order.isNotEmpty;
    final small = custom ? [for (final c in chosen.take(4)) c.id] : kQuickAccessSmallDefault;
    String label(String id) => s['q.$id'];
    return {
      ..._env(WidgetSlug.quickaccess, 'ok', deepLink: WidgetLink.home.uri, a11y: s['q.a11y'], prefix: 'q'),
      'smallIds': small,
      'items': [
        for (final c in chosen)
          {
            'id': c.id,
            'icon': c.icon,
            'label': label(c.id),
            'a11yLabel': c.id == 'timetable' ? s['q.timetableFull'] : label(c.id),
            'deepLink': c.link.uri,
          },
      ],
    };
  }

  // ------------------------------------------------------------ sosyal (yalnız sayılar)

  Map<String, Object?> social({required int unreadMessages, required int newNotifications, required int newLikesAndFollowers}) {
    int c(int v) => v < 0 ? 0 : v;
    final m = c(unreadMessages), n = c(newNotifications), l = c(newLikesAndFollowers);
    final all0 = m == 0 && n == 0 && l == 0;
    final smallLink = m > 0 ? WidgetLink.chat : (n > 0 ? WidgetLink.notifications : (l > 0 ? WidgetLink.discover : WidgetLink.chat));
    final summary = all0
        ? s['s.emptyTitle']
        : '${s['s.labelMessages']} ${s.count(m)}, ${s['s.labelNotifications']} ${s.count(n)}, ${s['s.labelLikes']} ${s.count(l)}';
    return {
      ..._env(WidgetSlug.social, all0 ? 'empty' : 'ok',
          deepLink: smallLink.uri, a11y: s.fill('s.a11y', {'summary': summary}), prefix: 's'),
      'unreadMessages': m,
      'newNotifications': n,
      'newLikesAndFollowers': l,
      'unreadMessagesText': s.count(m),
      'newNotificationsText': s.count(n),
      'newLikesAndFollowersText': s.count(l),
      'allZero': all0,
      'links': {
        'messages': WidgetLink.chat.uri,
        'notifications': WidgetLink.notifications.uri,
        'likes': WidgetLink.discover.uri,
        'header': WidgetLink.home.uri,
      },
    };
  }
}
