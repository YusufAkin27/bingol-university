import 'package:bu_kampus/features/clubs/club_manage_page.dart';
import 'package:bu_kampus/features/home/home_parts.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:bu_kampus/features/profile/my_clubs_page.dart';
import 'package:bu_kampus/features/profile/my_events_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Kulüp ve Etkinlik Merkezi: Kulüplerim özeti, yönetim paneli (izne bağlı araçlar), Etkinliklerim alt sekmeleri,
/// ana sayfa kısayolu.
Future<void> _pump(WidgetTester tester, Widget w, {Brightness b = Brightness.light, Size size = kPhoneMedium}) async {
  useScreen(tester, size);
  await tester.pumpWidget(buildApp(w, brightness: b, size: size));
  await settle(tester, const Duration(milliseconds: 700));
}

FakeBackend _clubs({bool owner = true, bool pending = true}) => FakeBackend()
  ..on('/me/communities*', {
    'items': [
      if (owner) {'id': 1, 'name': 'Fotoğrafçılık Kulübü', 'memberCount': 128, 'myStatus': 'ACTIVE', 'myRole': 'OWNER'},
      {'id': 2, 'name': 'Satranç Kulübü', 'memberCount': 12, 'myStatus': 'ACTIVE', 'myRole': 'MEMBER'},
      if (pending) {'id': 3, 'name': 'Tiyatro Kulübü', 'myStatus': 'PENDING'},
    ],
    'nextCursor': null,
  })
  ..on('/me/events?mode=upcoming*', {
    'items': [
      {'id': 5, 'title': 'Fotoğraf Yürüyüşü', 'startsAt': '2098-11-14T14:00:00', 'communityName': 'Fotoğrafçılık Kulübü'},
    ],
    'nextCursor': null,
  });

FakeBackend _manage({required List<String> perms, String role = 'OWNER'}) => FakeBackend()
  ..on('/communities/1', {'id': 1, 'name': 'Fotoğrafçılık Kulübü', 'memberCount': 128, 'myStatus': 'ACTIVE', 'myRole': role, 'visibility': 'PUBLIC'})
  ..on('/communities/1/permissions/me', {'role': role, 'permissions': perms})
  ..on('/communities/1/requests*', {
    'items': [
      {'userId': 8, 'displayName': 'Ali'},
      {'userId': 9, 'displayName': 'Ayşe'},
    ],
    'nextCursor': null,
  })
  ..on('/events?communityId=1*', {
    'items': [
      {'id': 5, 'title': 'Yürüyüş', 'startsAt': '2098-11-14T14:00:00', 'status': 'ACTIVE'},
    ],
    'nextCursor': null,
  })
  ..on('/communities/2', {'id': 2, 'name': 'Satranç Kulübü', 'memberCount': 12, 'myStatus': 'ACTIVE', 'myRole': 'ADMIN'})
  ..on('/communities/2/permissions/me', {'role': 'ADMIN', 'permissions': ['MANAGE_MEMBERS']})
  ..on('/communities/2/requests*', {'items': [], 'nextCursor': null})
  ..on('/events?communityId=2*', {'items': [], 'nextCursor': null});

const _all = ['EDIT_INFO', 'MANAGE_MEMBERS', 'MANAGE_EVENTS', 'MANAGE_POSTS', 'MANAGE_ROLES', 'INVITE'];

void main() {
  setUpAll(loadTestFonts);

  group('Kulüplerim özeti', () {
    testWidgets('özet, yönetim paneli düğmesi ve yaklaşan etkinlik', (tester) async {
      await _pump(tester, MyClubsPage(session: makeSession(_clubs())));
      final sum = find.byKey(const ValueKey('hub-summary'));
      expect(sum, findsOneWidget);
      expect(find.descendant(of: sum, matching: find.text('Yönettiğim')), findsOneWidget);
      expect(find.descendant(of: sum, matching: find.text('Bekleyen başvuru')), findsOneWidget);
      expect(find.byKey(const ValueKey('panel-1')), findsOneWidget);
      expect(find.text('YAKLAŞAN ETKİNLİKLERİM'), findsOneWidget);
      expect(find.text('Fotoğraf Yürüyüşü'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('yalniz uye: yonetim araci ve Yonettigim sayaci YOK', (tester) async {
      await _pump(tester, MyClubsPage(session: makeSession(_clubs(owner: false, pending: false))));
      expect(find.byKey(const ValueKey('panel-2')), findsNothing);
      expect(find.text('Yönetim Paneli'), findsNothing);
      expect(find.descendant(of: find.byKey(const ValueKey('hub-summary')), matching: find.text('Yönettiğim')), findsNothing);
      expect(find.text('Yönet'), findsNothing);
    });

    testWidgets('etkinlik yokken yonlendirici bos durum', (tester) async {
      final b = _clubs()..on('/me/events?mode=upcoming*', {'items': [], 'nextCursor': null});
      await _pump(tester, MyClubsPage(session: makeSession(b)));
      expect(find.text('Henüz katılacağın bir etkinlik yok.'), findsOneWidget);
      expect(find.text('Etkinlikleri keşfet'), findsOneWidget);
    });

    testWidgets('baslangicta bekleyen basvurulara kaydirir', (tester) async {
      await _pump(tester, MyClubsPage(session: makeSession(_clubs()), focusPending: true));
      expect(find.text('Tiyatro Kulübü'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('baskin kulup menusu: Yonetim Paneli acar', (tester) async {
      final b = _clubs()
        ..on('/communities/1', {'id': 1, 'name': 'Fotoğrafçılık Kulübü', 'memberCount': 128, 'myStatus': 'ACTIVE', 'myRole': 'OWNER'})
        ..on('/communities/1/permissions/me', {'role': 'OWNER', 'permissions': _all})
        ..on('/communities/1/requests*', {'items': [], 'nextCursor': null})
        ..on('/events?communityId=1*', {'items': [], 'nextCursor': null});
      await _pump(tester, MyClubsPage(session: makeSession(b)));
      await tester.tap(find.byKey(const ValueKey('panel-1')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byType(ClubManagePage), findsOneWidget);
      expect(find.byKey(const ValueKey('hub-club-card')), findsOneWidget);
    });
  });

  group('Yönetim paneli', () {
    testWidgets('tam yetki: kart sayaçları ve tüm hızlı işlemler', (tester) async {
      await _pump(tester, ClubManagePage(session: makeSession(_manage(perms: _all)), communityId: 1));
      expect(find.text('Fotoğrafçılık Kulübü'), findsOneWidget);
      expect(find.text('128'), findsOneWidget);
      final pend = find.byKey(const ValueKey('hub-stat-pending'));
      expect(find.descendant(of: pend, matching: find.text('2')), findsOneWidget);
      for (final k in ['requests', 'members', 'event', 'events', 'announce', 'posts', 'edit', 'roles']) {
        expect(find.byKey(ValueKey('hub-act-$k')), findsOneWidget, reason: k);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('kısmi yetki: yalniz izin verilen araclar', (tester) async {
      await _pump(tester, ClubManagePage(session: makeSession(_manage(perms: ['MANAGE_MEMBERS'], role: 'MODERATOR')), communityId: 1));
      expect(find.byKey(const ValueKey('hub-act-requests')), findsOneWidget);
      expect(find.byKey(const ValueKey('hub-act-members')), findsOneWidget);
      for (final k in ['event', 'events', 'announce', 'posts', 'edit', 'roles']) {
        expect(find.byKey(ValueKey('hub-act-$k')), findsNothing, reason: k);
      }
    });

    testWidgets('izin yok: hicbir arac yok, bilgi metni', (tester) async {
      await _pump(tester, ClubManagePage(session: makeSession(_manage(perms: [], role: 'MEMBER')), communityId: 1));
      expect(find.byKey(const ValueKey('hub-no-access')), findsOneWidget);
      expect(find.byKey(const ValueKey('hub-act-edit')), findsNothing);
      expect(find.byKey(const ValueKey('hub-stat-pending')), findsNothing);
    });

    testWidgets('izin ucu hata: arac gosterilmez (yetki yok varsayilir), hata ekrani', (tester) async {
      final b = _manage(perms: _all)..fail('/communities/1/permissions/me');
      await _pump(tester, ClubManagePage(session: makeSession(b), communityId: 1));
      expect(find.byKey(const ValueKey('hub-act-edit')), findsNothing);
      expect(find.byKey(const ValueKey('hub-club-card')), findsNothing);
    });

    testWidgets('birden fazla kulup: gecis cipleri', (tester) async {
      final b = _manage(perms: _all);
      await _pump(
          tester,
          ClubManagePage(
              session: makeSession(b),
              communityId: 1,
              managed: const [(id: 1, name: 'Fotoğrafçılık Kulübü'), (id: 2, name: 'Satranç Kulübü')]));
      expect(find.byKey(const ValueKey('hub-switcher')), findsOneWidget);
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('hub-switcher')), matching: find.text('Satranç Kulübü')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(b.requests.any((r) => r.contains('/communities/2/permissions/me')), isTrue);
      expect(find.byKey(const ValueKey('hub-act-members')), findsOneWidget);
      expect(find.byKey(const ValueKey('hub-act-edit')), findsNothing);
    });

    for (final br in Brightness.values) {
      for (final size in kPhoneSizes) {
        testWidgets('taşma yok ${br.name} ${size.width.toInt()}', (tester) async {
          await _pump(tester, ClubManagePage(session: makeSession(_manage(perms: _all)), communityId: 1), b: br, size: size);
          expect(tester.takeException(), isNull);
          await _pump(tester, MyClubsPage(session: makeSession(_clubs())), b: br, size: size);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('Etkinliklerim alt sekmeleri', () {
    FakeBackend ev() => FakeBackend()
      ..on('/me/events?mode=attending*', {
        'items': [
          {'id': 1, 'title': 'Kesin Katılım', 'startsAt': '2098-11-14T14:00:00', 'myRsvp': 'GOING'},
          {'id': 2, 'title': 'Bekleyen Atölye', 'startsAt': '2098-11-21T19:30:00', 'myRsvp': 'REQUESTED'},
        ],
        'nextCursor': null,
      })
      ..on('/me/events?mode=going*', {
        'items': [
          {'id': 1, 'title': 'Kesin Katılım', 'startsAt': '2098-11-14T14:00:00', 'myRsvp': 'GOING'},
        ],
        'nextCursor': null,
      })
      ..on('/me/events?mode=past*', {'items': [], 'nextCursor': null});

    testWidgets('dört alt sekme; Başvurularım yalniz bekleyenleri gosterir', (tester) async {
      await _pump(tester, MyEventsPage(session: makeSession(ev())));
      for (final t in ['Yaklaşan', 'Katılacaklarım', 'Geçmiş', 'Başvurularım']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.text('Kesin Katılım'), findsOneWidget);
      await tester.ensureVisible(find.text('Başvurularım'));
      await tester.pump();
      await tester.tap(find.text('Başvurularım'));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.text('Bekleyen Atölye'), findsOneWidget);
      expect(find.text('Kesin Katılım'), findsNothing);
      await tester.tap(find.text('Katılacaklarım'));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.text('Kesin Katılım'), findsOneWidget);
      expect(find.text('Bekleyen Atölye'), findsNothing);
    });

    testWidgets('initialSub (derin baglanti) dogrudan Başvurularım acar; bos durum', (tester) async {
      final b = FakeBackend()
        ..on('/me/events?mode=attending*', {'items': [], 'nextCursor': null})
        ..on('/me/events?mode=past*', {'items': [], 'nextCursor': null});
      await _pump(tester, MyEventsPage(session: makeSession(b), initialSub: 3));
      expect(find.text('Bekleyen başvurun yok.'), findsOneWidget);
      await tester.ensureVisible(find.text('Geçmiş'));
      await tester.pump();
      await tester.tap(find.text('Geçmiş'));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.text('Geçmiş etkinliğin yok.'), findsOneWidget);
    });

    for (final size in kPhoneSizes) {
      testWidgets('taşma yok ${size.width.toInt()}', (tester) async {
        await _pump(tester, MyEventsPage(session: makeSession(ev())), size: size);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Ana sayfa kısayolu', () {
    testWidgets('Kulüplerim karosu kişisel sayfayi acar', (tester) async {
      final b = FakeBackend()
        ..on('/menu/today', {'date': '2026-01-01', 'items': ['Pilav']})
        ..on('/me/communities*', {'items': [], 'nextCursor': null});
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(Scaffold(body: HomeTab(session: makeSession(b), onOpenTab: (i, {newsType}) {}))));
      await settle(tester, const Duration(seconds: 2));
      final bar = find.byType(HomeFeaturedShortcuts);
      await tester.tap(find.descendant(of: bar, matching: find.text('Kulüplerim')));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.byType(MyClubsPage), findsOneWidget);
      expect(find.text('Henüz bir kulübe katılmadın.'), findsOneWidget);
      expect(find.text('Kulüpleri keşfet'), findsOneWidget);
    });
  });
}
