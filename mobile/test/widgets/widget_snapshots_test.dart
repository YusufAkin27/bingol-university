import 'dart:convert';

import 'package:bu_kampus/features/academic/academic_models.dart';
import 'package:bu_kampus/features/menu/menu_models.dart';
import 'package:bu_kampus/features/widgets/widget_snapshots.dart';
import 'package:bu_kampus/features/widgets/widget_strings.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cuma 6 Kasim 2026, 10:00 Istanbul (= 07:00 UTC).
final DateTime kNow = DateTime.utc(2026, 11, 6, 7, 0);
final DateTime kToday = DateTime.utc(2026, 11, 6);

WidgetSnapshotBuilder b(String lang) => WidgetSnapshotBuilder(lang: lang, now: kNow);

MenuDay fullMenu({bool complete = true}) => MenuDay(
      items: const ['Mercimek Corbasi', 'Tavuk Sote', 'Pilav', 'Salata', 'Ayran'],
      dishes: const [
        MenuDish('Mercimek Çorbası', 150),
        MenuDish('Tavuk Sote', 420),
        MenuDish('Pilav', 380),
        MenuDish('Salata', 120),
        MenuDish('Ayran', 500),
      ],
      totalKcal: 1570,
      kcalComplete: complete,
    );

Course course(String name, int day, String start, String end, [String? room]) => Course(
      id: name.hashCode,
      name: name,
      sessions: [CourseSession(dayOfWeek: day, start: start, end: end, room: room)],
    );

Map<String, Object?> asJson(Map<String, Object?> m) => jsonDecode(jsonEncode(m)) as Map<String, Object?>;

void main() {
  group('zarf (envelope)', () {
    test('ortak alanlar, ISO +03:00, dil ve RTL', () {
      final m = asJson(b('tr').social(unreadMessages: 1, newNotifications: 0, newLikesAndFollowers: 0));
      expect(m['schema'], 1);
      expect(m['slug'], 'social');
      expect(m['generatedAt'], '2026-11-06T10:00:00+03:00');
      expect(m['lang'], 'tr');
      expect(m['rtl'], false);
      expect(asJson(b('ar').quickAccess())['rtl'], true);
      expect(m['strings'], isA<Map>());
      expect((m['strings'] as Map)['signedOutTitle'], 'Giriş yap');
    });

    test('desteklenmeyen dil Ingilizce olur', () {
      expect(asJson(b('de').quickAccess())['lang'], 'en');
    });

    test('meta: signedIn, tema sistem, oturumsuz metinleri', () {
      final m = asJson(b('en').meta(signedIn: false));
      expect(m['schema'], 1);
      expect(m['signedIn'], false);
      expect(m['theme'], 'system');
      expect(m['lang'], 'en');
      expect((m['strings'] as Map)['signedOutTitle'], 'Sign in');
      expect(asJson(b('tr').meta(signedIn: true))['signedIn'], true);
    });

    test('oturumsuz snapshot her slug icin Giris yap metnini tasir', () {
      for (final s in WidgetSlug.values) {
        final m = asJson(b('tr').signedOut(s));
        expect(m['state'], 'signedOut');
        expect(m['deepLink'], 'bukampus://home');
        expect((m['strings'] as Map)['signedOutSub'], "BÜ Kampüs'ü aç");
      }
    });

    test('uc dilin metin anahtar kumesi ve yer tutuculari ayni', () {
      final tr = WidgetStrings.of('tr');
      final ph = RegExp(r'\{(\w+)\}');
      for (final l in ['en', 'ar']) {
        final o = WidgetStrings.of(l);
        expect(o.keys.toSet(), tr.keys.toSet(), reason: l);
        for (final k in tr.keys) {
          expect(ph.allMatches(o[k]).map((e) => e[1]).toSet(), ph.allMatches(tr[k]).map((e) => e[1]).toSet(), reason: '$l $k');
          expect(o[k].trim(), isNotEmpty, reason: '$l $k');
        }
      }
    });
  });

  group('menu', () {
    test('dolu gun: Turkce metinler, kcal, small ozeti, ertesi gun', () {
      final m = asJson(b('tr').menu({kToday: fullMenu(), kToday.add(const Duration(days: 1)): fullMenu()}));
      expect(m['state'], 'ok');
      expect(m['date'], '2026-11-06');
      expect(m['dateLabel'], 'Cuma, 6 Kasım');
      expect(m['empty'], false);
      expect(m['totalKcal'], 1570);
      expect(m['totalLine'], 'Toplam 1.570 kcal');
      final meal = (m['meals'] as List).single as Map;
      expect(meal['id'], 'lunch');
      expect(meal['label'], 'ÖĞLE');
      expect((meal['items'] as List).first, {'name': 'Mercimek Çorbası', 'kcal': 150, 'kcalText': '150 kcal'});
      final small = m['small'] as Map;
      expect(small['main'], 'Mercimek Çorbası');
      expect(small['sub'], 'Tavuk Sote · Pilav · Salata');
      expect(small['kcalLine'], '1.570 kcal bugün');
      expect((m['upcoming'] as List).length, 1);
      expect(m['deepLink'], 'bukampus://menu');
      expect(m['expiresAt'], '2026-11-08T00:00:00+03:00'); // son dahil gunun (7 Kasim) bitisi
    });

    test('kalori eksikse ~ onekli toplam, kalorisiz yemek kcal null', () {
      final m = asJson(b('tr').menu({
        kToday: const MenuDay(dishes: [MenuDish('Pilav', 380), MenuDish('Ayran')], totalKcal: 380, kcalComplete: false),
      }));
      expect(m['totalLine'], 'Toplam ~380 kcal');
      expect((((m['meals'] as List).single as Map)['items'] as List)[1]['kcal'], isNull);
    });

    test('kcal hic yoksa toplam satiri null', () {
      final m = asJson(b('tr').menu({kToday: const MenuDay(dishes: [MenuDish('Pilav')])}));
      expect(m['totalLine'], isNull);
      expect((m['small'] as Map)['kcalLine'], isNull);
    });

    test('menu yok: bos durum, yine de yarinin menusu upcoming icinde', () {
      final m = asJson(b('tr').menu({kToday.add(const Duration(days: 1)): fullMenu()}));
      expect(m['state'], 'empty');
      expect(m['empty'], true);
      expect(m['meals'], isEmpty);
      expect((m['upcoming'] as List).single['date'], '2026-11-07');
      expect((m['strings'] as Map)['emptyTitle'], 'Bugün menü yok');
    });

    test('Ingilizce binlik ayirac virgul, Arapca RTL', () {
      expect(asJson(b('en').menu({kToday: fullMenu()}))['totalLine'], 'Total 1,570 kcal');
      final ar = asJson(b('ar').menu({kToday: fullMenu()}));
      expect(ar['rtl'], true);
      expect(((ar['meals'] as List).single as Map)['label'], 'الغداء');
      expect(ar['dateLabel'], 'الجمعة, 6 نوفمبر');
    });
  });

  group('timetable', () {
    test('bugunun dersleri sirali, derslik 8 karakter ile sinirli, siradaki', () {
      final m = asJson(b('tr').timetable([
        course('Algoritma', 5, '10:30', '11:20', 'B-204'),
        course('Veri Yapıları', 5, '08:30', '09:20', 'ÇOKUZUNDERSLIK'),
        course('Pazartesi Dersi', 1, '08:30', '09:20'),
      ], null));
      expect(m['state'], 'ok');
      expect(m['count'], 2);
      final l = m['lessons'] as List;
      expect(l.first['title'], 'Veri Yapıları');
      expect(l.first['room'], 'ÇOKUZUND');
      expect(l.last['start'], '10:30');
      expect(l.last['startMin'], 630);
      expect(m['next'], containsPair('labelFull', 'Cuma 10:30'));
      expect((m['upcoming'] as List).length, 6);
      expect((m['upcoming'] as List).first['dayName'], 'Cumartesi');
    });

    test('bugun ders yok: bos durum ve sonraki ders metni', () {
      final m = asJson(b('tr').timetable([course('Pazartesi Dersi', 1, '08:30', '09:20')], null));
      expect(m['state'], 'empty');
      expect(m['count'], 0);
      expect(m['next'], containsPair('labelFull', 'Pazartesi 08:30'));
      expect((m['next'] as Map)['labelShort'], 'Pzt 08:30');
    });

    test('hic ders yok: next null', () {
      final m = asJson(b('en').timetable(const [], null));
      expect(m['state'], 'empty');
      expect(m['next'], isNull);
    });
  });

  group('events', () {
    test('gecmis elenir, tarihe gore artan, en cok 3, bos mekan null, rozet alanlari', () {
      final m = asJson(b('tr').events([
        WidgetEventInput(id: 4, title: 'Eski', communityName: 'K', startsAt: kNow.subtract(const Duration(hours: 3))),
        WidgetEventInput(id: 3, title: 'Üçüncü', communityName: 'Kulüp C', startsAt: DateTime.utc(2026, 11, 20, 11, 0), venue: '  '),
        WidgetEventInput(id: 1, title: 'Birinci', communityName: 'Kulüp A', startsAt: DateTime.utc(2026, 11, 12, 11, 0), venue: 'Amfi 2'),
        WidgetEventInput(id: 2, title: 'İkinci', communityName: 'Kulüp B', startsAt: DateTime.utc(2026, 11, 15, 11, 0)),
        WidgetEventInput(id: 5, title: 'Dördüncü', communityName: 'Kulüp D', startsAt: DateTime.utc(2026, 12, 1, 11, 0)),
        WidgetEventInput(id: 6, title: 'Devam ediyor', communityName: 'Kulüp E', startsAt: kNow.subtract(const Duration(minutes: 30))),
      ]));
      final ids = [for (final e in m['events'] as List) (e as Map)['id']];
      expect(ids, [6, 1, 2]);
      final e = (m['events'] as List)[1] as Map;
      expect(e['day'], '12');
      expect(e['monthCaps'], 'KAS');
      expect(e['timeLabel'], '14:00');
      expect(e['venue'], 'Amfi 2');
      expect(e['deepLink'], 'bukampus://events/1');
      expect(((m['events'] as List)[2] as Map)['venue'], isNull);
      expect(m['count'], 3);
      expect(m['countLabel'], '3 etkinlik');
    });

    test('bos', () {
      final m = asJson(b('tr').events(const []));
      expect(m['state'], 'empty');
      expect(m['events'], isEmpty);
      expect(m['deepLink'], 'bukampus://events');
    });
  });

  group('announcements', () {
    test('acil en uste, tarih azalan, en cok 4, meta metni ve tarih bicimi', () {
      DateTime d(int day) => DateTime.utc(2026, 11, day);
      final m = asJson(b('tr').announcements([
        WidgetNewsInput(id: 1, title: 'A', publishedDay: d(5), sourceName: 'SKS'),
        WidgetNewsInput(id: 2, title: 'B', publishedDay: d(4)),
        WidgetNewsInput(id: 3, title: 'C', publishedDay: d(2), urgent: true, sourceName: 'Kütüphane'),
        WidgetNewsInput(id: 4, title: 'D', publishedDay: d(1)),
        WidgetNewsInput(id: 5, title: 'E', publishedDay: d(3)),
      ]));
      final items = (m['items'] as List).cast<Map>();
      expect([for (final i in items) i['id']], [3, 1, 2, 5]);
      expect(items[0]['metaText'], 'Acil · Kütüphane · 02 Kas');
      expect(items[0]['urgent'], true);
      expect(items[1]['metaText'], 'SKS · 05 Kas');
      expect(items[2]['metaText'], '04 Kas'); // kaynak adi yoksa yalniz tarih
      expect(items[1]['deepLink'], 'bukampus://news/1');
      expect(m['lastLabel'], 'Son 4');
    });

    test('bos', () {
      final m = asJson(b('en').announcements(const []));
      expect(m['state'], 'empty');
      expect((m['strings'] as Map)['emptyTitle'], 'No new announcements');
    });
  });

  group('poll', () {
    WidgetPollInput poll({bool voted = true, bool visible = true, List<int> counts = const [691, 397, 192], bool multi = false}) =>
        WidgetPollInput(
          id: 42,
          question: 'Yemekhanede akşam menüsü nasıl?',
          options: [
            WidgetPollOptionInput('Çok iyi', counts[0]),
            WidgetPollOptionInput('İdare eder', counts[1]),
            WidgetPollOptionInput('Kötü', counts[2]),
          ],
          userVoted: voted,
          resultsVisible: visible,
          totalVotes: counts.fold<int>(0, (a, c) => a + c),
          multi: multi,
        );

    test('yuzdeler 100e yuvarlanir, lider, oy sayisi etiketi', () {
      final m = asJson(b('tr').poll(poll()));
      final pcts = [for (final o in m['options'] as List) (o as Map)['percent'] as int];
      expect(pcts.fold<int>(0, (a, c) => a + c), 100);
      expect(pcts.first, 54);
      expect(m['leaderIndex'], 0);
      expect(m['totalVotesLabel'], '1.280 oy');
      expect((m['options'] as List).first['percentText'], '%54');
      expect(m['microLine'], '1.280 oy · gizli');
      expect(m['secretLine'], 'Oylar gizlidir · 1.280 oy');
      expect(m['deepLink'], 'bukampus://poll/42');
    });

    test('oy verilmediyse yuzde YOK', () {
      final m = asJson(b('tr').poll(poll(voted: false)));
      expect(m['userVoted'], false);
      expect([for (final o in m['options'] as List) (o as Map)['percent']], [null, null, null]);
      expect(m['leaderIndex'], isNull);
      expect(m['resultsVisible'], false);
    });

    test('sonuc gizliyse oy sayisi null', () {
      final m = asJson(b('tr').poll(poll(visible: false)));
      expect(m['totalVotes'], isNull);
      expect(m['totalVotesLabel'], isNull);
    });

    test('anket yok ya da tek secenek: bos durum, Ana Sayfa baglantisi', () {
      const single = WidgetPollInput(
          id: 1, question: 'x', options: [WidgetPollOptionInput('a')], userVoted: false, resultsVisible: false);
      for (final p in <WidgetPollInput?>[null, single]) {
        final m = asJson(b('tr').poll(p));
        expect(m['state'], 'empty');
        expect(m['pollId'], isNull);
        expect(m['deepLink'], 'bukampus://home');
      }
    });

    test('roundPercents', () {
      expect(WidgetSnapshotBuilder.roundPercents([1, 1, 1], normalize: true).fold<int>(0, (a, c) => a + c), 100);
      expect(WidgetSnapshotBuilder.roundPercents([0, 0], normalize: true), [0, 0]);
      expect(WidgetSnapshotBuilder.roundPercents([3, 1], normalize: false), [75, 25]);
    });
  });

  group('quickaccess', () {
    test('varsayilan 8 karo, small 4 kisayol, derin baglantilar', () {
      final m = asJson(b('tr').quickAccess());
      final items = (m['items'] as List).cast<Map>();
      expect(items.length, 8);
      expect(items.map((e) => e['deepLink']).toList(), [
        'bukampus://menu',
        'bukampus://timetable',
        'bukampus://events',
        'bukampus://clubs',
        'bukampus://chat',
        'bukampus://qr',
        'bukampus://news',
        'bukampus://search',
      ]);
      expect(m['smallIds'], ['menu', 'events', 'chat', 'qr']);
      expect(items[1]['label'], 'Ders');
      expect(items[1]['a11yLabel'], 'Ders Programı');
      expect(items[0]['icon'], 'utensils');
      expect(m['state'], 'ok');
    });

    test('kisisellestirme: sira, yinelenen ve bilinmeyen kimlik, eksikler sona', () {
      final m = asJson(b('tr').quickAccess(order: ['qr', 'qr', 'zzz', 'search']));
      final ids = [for (final e in m['items'] as List) (e as Map)['id']];
      expect(ids.take(2).toList(), ['qr', 'search']);
      expect(ids.length, 8);
      expect(ids.toSet().length, 8);
      expect((m['smallIds'] as List).length, 4);
      expect((m['smallIds'] as List).first, 'qr');
    });
  });

  group('social (KVKK: yalniz sayilar)', () {
    test('sayilar, 99+ ve baglantilar', () {
      final m = asJson(b('tr').social(unreadMessages: 3, newNotifications: 120, newLikesAndFollowers: 7));
      expect(m['unreadMessages'], 3);
      expect(m['newNotificationsText'], '99+');
      expect(m['allZero'], false);
      expect(m['deepLink'], 'bukampus://chat');
      expect((m['links'] as Map)['likes'], 'bukampus://discover');
    });

    test('hepsi 0: bos durum; kucuk widget ilk sifir olmayan hedefe gider', () {
      expect(asJson(b('tr').social(unreadMessages: 0, newNotifications: 0, newLikesAndFollowers: 0))['state'], 'empty');
      expect(asJson(b('tr').social(unreadMessages: 0, newNotifications: 2, newLikesAndFollowers: 0))['deepLink'], 'bukampus://notifications');
      expect(asJson(b('tr').social(unreadMessages: 0, newNotifications: 0, newLikesAndFollowers: 2))['deepLink'], 'bukampus://discover');
    });

    test('negatif sayi 0 olur', () {
      expect(asJson(b('tr').social(unreadMessages: -4, newNotifications: 0, newLikesAndFollowers: 0))['unreadMessages'], 0);
    });

    test('snapshot kisi adi, mesaj, avatar, e-posta anahtari tasimaz', () {
      final snap = b('tr').social(unreadMessages: 5, newNotifications: 5, newLikesAndFollowers: 5);
      final keys = <String>{};
      void walk(Object? o) {
        if (o is Map) {
          for (final e in o.entries) {
            keys.add('${e.key}'.toLowerCase());
            if (e.key != 'strings') walk(e.value); // sabit arayuz etiketleri (kisi verisi degil)
          }
        } else if (o is List) {
          o.forEach(walk);
        }
      }

      walk(snap);
      for (final k in keys) {
        for (final banned in ['avatar', 'photo', 'sender', 'email', 'displayname', 'username', 'fullname']) {
          expect(k.contains(banned), isFalse, reason: 'yasak anahtar: $k');
        }
        for (final exact in ['message', 'body', 'name', 'text', 'content']) {
          expect(k, isNot(exact), reason: 'yasak anahtar: $k');
        }
      }
      expect(keys.containsAll({'unreadmessages', 'newnotifications', 'newlikesandfollowers'}), isTrue);
    });
  });

  group('tum snapshotlar', () {
    test('uc dilde JSON kodlanir, doldurulmamis yer tutucu kalmaz (sablon alanlari haric)', () {
      for (final lang in kWidgetLangs) {
        final bb = b(lang);
        final snaps = <Map<String, Object?>>[
          bb.menu({kToday: fullMenu()}),
          bb.timetable([course('X', 5, '10:30', '11:20', 'A1')], null),
          bb.events([WidgetEventInput(id: 1, title: 'E', communityName: 'K', startsAt: DateTime.utc(2026, 11, 12, 11))]),
          bb.announcements([WidgetNewsInput(id: 1, title: 'N', publishedDay: DateTime.utc(2026, 11, 5))]),
          bb.poll(null),
          bb.quickAccess(),
          bb.social(unreadMessages: 1, newNotifications: 1, newLikesAndFollowers: 1),
          bb.exams([WidgetExamInput(id: 1, title: 'V', courseName: 'C', type: 'VIZE', startsAt: DateTime.utc(2026, 11, 12, 7))]),
          bb.academic([WidgetAcademicInput(id: 1, kind: 'TATIL', title: 'T', startsAt: DateTime.utc(2026, 11, 12, 7))]),
        ];
        for (final s in snaps) {
          final text = jsonEncode(s);
          expect(text.length, lessThan(16 * 1024), reason: '${s['slug']} boyutu');
          final dec = jsonDecode(text) as Map<String, dynamic>..remove('strings');
          expect(jsonEncode(dec).contains(RegExp(r'\{[a-zA-Z]+\}')), isFalse, reason: '${s['slug']} $lang');
          expect(dec['lang'], lang);
        }
      }
    });
  });

  group('sinavlar ve akademik takvim', () {
    test('sinavlar: gecmis elenir, tarihe gore siralanir, 4 ile sinirli, mutlak tarih', () {
      final m = asJson(b('tr').exams([
        WidgetExamInput(id: 1, title: 'Eski', type: 'VIZE', startsAt: DateTime.utc(2026, 11, 5, 7)),
        WidgetExamInput(id: 2, title: 'Final', courseName: 'Algoritma', type: 'FINAL', startsAt: DateTime.utc(2026, 11, 20, 7), room: 'A-1'),
        WidgetExamInput(id: 3, title: 'Vize', courseName: 'Fizik', type: 'VIZE', startsAt: DateTime.utc(2026, 11, 10, 7)),
      ]));
      expect(m['slug'], 'exams');
      expect(m['state'], 'ok');
      expect(m['deepLink'], 'bukampus://exams');
      final items = m['items'] as List;
      expect(items.map((e) => (e as Map)['title']), ['Fizik', 'Algoritma']);
      expect((items[0] as Map)['metaText'], 'Vize · 10 Kas 10:00');
      expect((items[1] as Map)['metaText'], 'Final · 20 Kas 10:00 · A-1');
      expect(jsonEncode(m).contains('gün kaldı'), isFalse);
    });

    test('sinavlar: bos liste bos durum, bilinmeyen tur Sinav olur', () {
      expect(asJson(b('en').exams(const []))['state'], 'empty');
      final m = asJson(b('en').exams([WidgetExamInput(id: 1, title: 'X', type: 'ZZZ', startsAt: DateTime.utc(2026, 11, 12, 7))]));
      expect(((m['items'] as List).first as Map)['metaText'], 'Exam · 12 Nov 10:00');
    });

    test('sinavlar: oda ve tur dilde, yer tutucu kalmaz (ar)', () {
      final m = asJson(b('ar').exams([WidgetExamInput(id: 1, title: 'X', type: 'FINAL', startsAt: DateTime.utc(2026, 11, 12, 7))]));
      expect(m['rtl'], true);
      expect(((m['items'] as List).first as Map)['metaText'], startsWith('نهائي'));
    });

    test('akademik takvim: biten elenir, aralik bicimi, ay gecisi', () {
      final m = asJson(b('tr').academic([
        WidgetAcademicInput(id: 1, kind: 'TATIL', title: 'Bitti', startsAt: DateTime.utc(2026, 11, 1), endsAt: DateTime.utc(2026, 11, 3)),
        WidgetAcademicInput(id: 2, kind: 'VIZE', title: 'Devam eden', startsAt: DateTime.utc(2026, 11, 3, 21), endsAt: DateTime.utc(2026, 11, 8, 21)),
        WidgetAcademicInput(id: 3, kind: 'DERS_KAYIT', title: 'Aylar arasi', startsAt: DateTime.utc(2026, 11, 28, 21), endsAt: DateTime.utc(2026, 12, 2, 21)),
        WidgetAcademicInput(id: 4, kind: 'RESMI_TATIL', title: 'Tek gun', startsAt: DateTime.utc(2026, 11, 9, 21)),
      ]));
      final items = (m['items'] as List).cast<Map>();
      expect(items.map((e) => e['title']), ['Devam eden', 'Tek gun', 'Aylar arasi']);
      expect(items[0]['metaText'], 'Vize · 4 – 9 Kas');
      expect(items[1]['metaText'], 'Resmi tatil · 10 Kas');
      expect(items[2]['metaText'], 'Ders kaydı · 29 Kas – 3 Ara');
      expect(m['deepLink'], 'bukampus://academic');
    });

    test('akademik takvim: bos durum', () {
      final m = asJson(b('tr').academic(const []));
      expect(m['state'], 'empty');
      expect((m['strings'] as Map)['emptyTitle'], 'Yaklaşan akademik tarih yok');
      expect((m['strings'] as Map).containsKey('kind.VIZE'), isFalse);
    });
  });
}
