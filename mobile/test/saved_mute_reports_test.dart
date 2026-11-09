import 'dart:convert';

import 'package:bu_kampus/core/icons/bu_icons.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/clubs/club_detail_page.dart';
import 'package:bu_kampus/features/events/event_detail_page.dart';
import 'package:bu_kampus/features/saved/muted_items_page.dart';
import 'package:bu_kampus/features/saved/my_reports_page.dart';
import 'package:bu_kampus/features/saved/saved_items_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

const _wait = Duration(milliseconds: 800);

Map<String, dynamic> _saved(String type, int id, String title, {String sub = 'Alt metin'}) =>
    {'type': type, 'targetId': id, 'savedAt': '2026-11-01T10:00:00Z', 'title': title, 'subtitle': sub, 'imageUrl': null, 'link': '/x/$id', 'news': null};

/// /bookmarks: ALL iki sayfa (imleç 2), EVENT süzgeci tek sayfa.
FakeBackend _savedBackend({bool empty = false}) {
  final b = FakeBackend();
  b.handlers.add((req, path) {
    if (path != '/bookmarks' || req.method != 'GET') return null;
    if (empty) return const FakeResult.json({'items': [], 'nextCursor': null});
    final type = req.url.queryParameters['type'] ?? 'ALL';
    final cursor = req.url.queryParameters['cursor'];
    if (type == 'EVENT') {
      return FakeResult.json({'items': [_saved('EVENT', 12, 'Yaz şenliği')], 'nextCursor': null});
    }
    if (type != 'ALL') return const FakeResult.json({'items': [], 'nextCursor': null});
    if (cursor == null) {
      return FakeResult.json({'items': [_saved('EVENT', 12, 'Yaz şenliği'), _saved('COMMUNITY', 3, 'Satranç Kulübü')], 'nextCursor': 2});
    }
    return FakeResult.json({'items': [_saved('POLL', 9, 'Yemekhane anketi')], 'nextCursor': null});
  });
  return b;
}

Future<void> _app(WidgetTester t, Widget home, {Size size = kPhoneMedium, Locale? locale}) async {
  useScreen(t, size);
  await t.pumpWidget(locale == null
      ? buildApp(home, size: size)
      : MaterialApp(
          theme: BuTheme.light(),
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: MediaQuery(data: MediaQueryData(size: size), child: home),
        ));
  await settle(t, _wait);
}

bool _hasIcon(WidgetTester t, Finder within, IconData icon) =>
    t.widgetList<Icon>(find.descendant(of: within, matching: find.byType(Icon))).any((i) => i.icon == icon);

void main() {
  setUpAll(loadTestFonts);

  group('Kaydedilenler', () {
    testWidgets('birleşik liste, imleç devamı ve tür süzgeci', (t) async {
      final b = _savedBackend();
      await _app(t, SavedItemsPage(session: makeSession(b)));
      expect(find.text('Yaz şenliği'), findsOneWidget);
      expect(find.text('Satranç Kulübü'), findsOneWidget);
      // Liste ekranı doldurmadığı için devam sayfası kendiliğinden istenir.
      expect(b.requests.any((r) => r.contains('cursor=2')), isTrue);
      expect(find.text('Yemekhane anketi'), findsOneWidget);
      await t.tap(find.text('Etkinlikler'));
      await settle(t, _wait);
      expect(b.requests.any((r) => r.contains('type=EVENT')), isTrue);
      expect(find.text('Yaz şenliği'), findsOneWidget);
      expect(find.text('Satranç Kulübü'), findsNothing);
      await unmount(t);
    });

    testWidgets('bos sayfa + nextCursor: bos durum cizilmez, sonraki sayfa istenir (I3-02)', (t) async {
      final b = FakeBackend();
      b.handlers.add((req, path) {
        if (path != '/bookmarks') return null;
        final cursor = req.url.queryParameters['cursor'];
        if (cursor == null) return const FakeResult.json({'items': [], 'nextCursor': 5});
        return FakeResult.json({'items': [_saved('EVENT', 12, 'Yaz şenliği'), _saved('POLL', 9, 'Anket A')], 'nextCursor': null});
      });
      await _app(t, SavedItemsPage(session: makeSession(b)));
      expect(find.byKey(const ValueKey('saved-empty')), findsNothing);
      expect(find.text('Yaz şenliği'), findsOneWidget);
      expect(find.text('Anket A'), findsOneWidget);
      expect(b.requests.any((r) => r.contains('cursor=5')), isTrue);
      await unmount(t);
    });

    testWidgets('boş durum ve tür boşsa süzgeç metni', (t) async {
      await _app(t, SavedItemsPage(session: makeSession(_savedBackend(empty: true))));
      expect(find.byKey(const ValueKey('saved-empty')), findsOneWidget);
      expect(find.text('Henüz kaydettiğin bir şey yok'), findsOneWidget);
      await t.ensureVisible(find.text('Anketler'));
      await t.tap(find.text('Anketler'));
      await settle(t, _wait);
      expect(find.text('Bu türde kayıt yok'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('hata durumu ve yeniden dene', (t) async {
      final b = FakeBackend()..fail('/bookmarks', status: 500);
      await _app(t, SavedItemsPage(session: makeSession(b)));
      expect(find.text('Yeniden dene'), findsWidgets);
      b.reset('/bookmarks');
      b.on('/bookmarks', {'items': [_saved('EVENT', 12, 'Yaz şenliği')], 'nextCursor': null});
      await t.tap(find.text('Yeniden dene').first);
      await settle(t, _wait);
      expect(find.text('Yaz şenliği'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('uzun basma ile kaldır: DELETE gider; hata olursa satır geri gelir', (t) async {
      final b = _savedBackend();
      await _app(t, SavedItemsPage(session: makeSession(b)));
      await t.longPress(find.byKey(const ValueKey('saved-row-EVENT:12')));
      await settle(t, _wait);
      await t.tap(find.byKey(const ValueKey('saved-sheet-remove')));
      await settle(t, _wait);
      expect(b.requests, contains('DELETE /bookmarks/event/12'));
      expect(find.text('Yaz şenliği'), findsNothing);

      b.fail('/bookmarks/community/3', status: 500);
      await t.longPress(find.byKey(const ValueKey('saved-row-COMMUNITY:3')));
      await settle(t, _wait);
      await t.tap(find.byKey(const ValueKey('saved-sheet-remove')));
      await settle(t, _wait);
      expect(find.text('Satranç Kulübü'), findsOneWidget);
      await unmount(t);
    });

    for (final loc in [const Locale('tr'), const Locale('ar')]) {
      testWidgets('320dp taşma yok (${loc.languageCode})', (t) async {
        final b = _savedBackend();
        b.handlers.insert(0, (req, path) {
          if (path != '/bookmarks') return null;
          return FakeResult.json({
            'items': [_saved('EVENT', 1, 'Çok uzun bir etkinlik başlığı ' * 4, sub: 'Çok uzun alt başlık ' * 5)],
            'nextCursor': null
          });
        });
        await _app(t, SavedItemsPage(session: makeSession(b)), size: kPhoneSmall, locale: loc);
        expect(t.takeException(), isNull);
        await unmount(t);
      });
    }
  });

  group('Etkinlik: kaydet ve sessize al', () {
    FakeBackend be({bool failPut = false}) {
      final s = DateTime.now().add(const Duration(hours: 3)).toUtc().toIso8601String();
      final b = FakeBackend()
        ..on('/events/5', {
          'id': 5,
          'title': 'Halı saha',
          'description': 'Maç',
          'startsAt': s,
          'endsAt': s,
          'location': 'Saha',
          'goingCount': 1,
          'interestedCount': 0,
          'canManage': false,
          'joinPolicy': 'OPEN',
          'createdBy': 2,
          'organizer': {'id': 2, 'displayName': 'M', 'avatarUrl': null},
          'organizerName': 'M',
        })
        ..on('/events/5/attendees/preview', {'goingCount': 1, 'avatars': []});
      var muted = false;
      var saved = false;
      b.handlers.add((req, path) {
        if (path == '/events/5/notification-mute') {
          if (req.method == 'PUT') {
            if (failPut) return const FakeResult.json({'code': 'VALIDATION_ERROR', 'message': 'Sınır'}, status: 422);
            muted = (jsonDecode(req.body) as Map)['muted'] == true;
          }
          return FakeResult.json({'muted': muted});
        }
        if (path == '/bookmarks/event/ids') return FakeResult.json({'ids': saved ? [5] : []});
        if (path == '/bookmarks/event/5') {
          if (failPut) return const FakeResult.json({'code': 'BOOKMARK_LIMIT', 'message': 'Sınır'}, status: 409);
          saved = req.method == 'PUT';
          return const FakeResult.json({});
        }
        return null;
      });
      return b;
    }

    testWidgets('kaydet düğmesi iyimser çevirir ve PUT gönderir', (t) async {
      final b = be();
      await _app(t, EventDetailPage(session: makeSession(b), eventId: 5));
      final btn = find.byKey(const ValueKey('event-save'));
      expect(btn, findsOneWidget);
      expect(_hasIcon(t, btn, BuIcons.bookmark), isTrue);
      await t.tap(btn);
      await t.pump();
      expect(_hasIcon(t, btn, BuIcons.bookmarkFilled), isTrue); // iyimser
      await settle(t, _wait);
      expect(b.requests, contains('PUT /bookmarks/event/5'));
      expect(_hasIcon(t, btn, BuIcons.bookmarkFilled), isTrue);
      await unmount(t);
    });

    testWidgets('kaydet hata verirse geri alınır', (t) async {
      final b = be(failPut: true);
      await _app(t, EventDetailPage(session: makeSession(b), eventId: 5));
      final btn = find.byKey(const ValueKey('event-save'));
      await t.tap(btn);
      await settle(t, _wait);
      expect(_hasIcon(t, btn, BuIcons.bookmark), isTrue);
      await unmount(t);
    });

    testWidgets('menüden sessize al: PUT {muted:true}; etiket "Bildirimleri aç" olur', (t) async {
      final b = be();
      await _app(t, EventDetailPage(session: makeSession(b), eventId: 5));
      await t.tap(find.byTooltip('Şikâyet et'));
      await settle(t, _wait);
      await t.tap(find.text('Bildirimleri sessize al'));
      await settle(t, _wait);
      expect(b.bodies['PUT /events/5/notification-mute'], {'muted': true});
      await t.tap(find.byTooltip('Şikâyet et'));
      await settle(t, _wait);
      expect(find.text('Bildirimleri aç'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('sessize alma hata verirse geri alınır', (t) async {
      final b = be(failPut: true);
      await _app(t, EventDetailPage(session: makeSession(b), eventId: 5));
      await t.tap(find.byTooltip('Şikâyet et'));
      await settle(t, _wait);
      await t.tap(find.text('Bildirimleri sessize al'));
      await settle(t, _wait);
      await t.tap(find.byTooltip('Şikâyet et'));
      await settle(t, _wait);
      expect(find.text('Bildirimleri sessize al'), findsOneWidget);
      await unmount(t);
    });
  });

  group('Kulüp: kaydet ve sessize al', () {
    FakeBackend be() {
      final b = FakeBackend()
        ..on('/communities/7', {
          'id': 7,
          'name': 'Satranç',
          'description': 'Kulüp',
          'category': 'Sosyal',
          'memberCount': 4,
          'visibility': 'PUBLIC',
          'joinPolicy': 'OPEN',
          'myStatus': 'ACTIVE',
          'myRole': 'MEMBER',
        })
        ..on('/communities/7/posts*', {'items': [], 'nextCursor': null})
        ..on('/communities/7/requests*', {'items': [], 'nextCursor': null})
        ..on('/events*', {'items': [], 'nextCursor': null});
      var muted = false;
      b.handlers.add((req, path) {
        if (path == '/communities/7/notification-mute') {
          if (req.method == 'PUT') muted = (jsonDecode(req.body) as Map)['muted'] == true;
          return FakeResult.json({'muted': muted});
        }
        if (path == '/bookmarks/community/ids') return const FakeResult.json({'ids': [7]});
        return null;
      });
      return b;
    }

    testWidgets('kayıtlı açılır; dokununca DELETE; menüde sessize al', (t) async {
      final b = be();
      await _app(t, ClubDetailPage(session: makeSession(b), communityId: 7));
      final btn = find.byKey(const ValueKey('club-save'));
      expect(btn, findsOneWidget);
      expect(_hasIcon(t, btn, BuIcons.bookmarkFilled), isTrue);
      await t.tap(btn);
      await settle(t, _wait);
      expect(b.requests, contains('DELETE /bookmarks/community/7'));
      expect(_hasIcon(t, btn, BuIcons.bookmark), isTrue);

      await t.tap(find.byTooltip('Kulüp seçenekleri'));
      await settle(t, _wait);
      await t.tap(find.text('Bildirimleri sessize al'));
      await settle(t, _wait);
      expect(b.bodies['PUT /communities/7/notification-mute'], {'muted': true});
      await unmount(t);
    });
  });

  group('Sessize alınanlar', () {
    FakeBackend be() {
      final b = FakeBackend()
        ..on('/me/notification-mutes', {'communities': [7], 'events': [5]})
        ..on('/communities/7', {'id': 7, 'name': 'Satranç Kulübü'})
        ..on('/events/5', {'id': 5, 'title': 'Halı saha'});
      return b;
    }

    testWidgets('liste, ad çözümü, açma ve boş durum', (t) async {
      final b = be();
      await _app(t, MutedItemsPage(session: makeSession(b)));
      expect(find.text('Satranç Kulübü'), findsOneWidget);
      expect(find.text('Halı saha'), findsOneWidget);
      expect(find.textContaining('önemli bildirimler'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('muted-event-5-unmute')));
      await settle(t, _wait);
      expect(b.bodies['PUT /events/5/notification-mute'], {'muted': false});
      expect(find.text('Halı saha'), findsNothing);
      await t.tap(find.byKey(const ValueKey('muted-club-7-unmute')));
      await settle(t, _wait);
      expect(find.byKey(const ValueKey('muted-empty')), findsOneWidget);
      await unmount(t);
    });

    testWidgets('açma hatasında satır geri gelir; liste hatası yeniden dene', (t) async {
      final b = be()..fail('/events/5/notification-mute', status: 422, code: 'VALIDATION_ERROR');
      await _app(t, MutedItemsPage(session: makeSession(b)));
      await t.tap(find.byKey(const ValueKey('muted-event-5-unmute')));
      await settle(t, _wait);
      expect(find.text('Halı saha'), findsOneWidget);
      await unmount(t);

      final e = FakeBackend()..fail('/me/notification-mutes', status: 500);
      await _app(t, MutedItemsPage(session: makeSession(e)));
      expect(find.text('Yeniden dene'), findsWidgets);
      await unmount(t);
    });

    testWidgets('320dp ar taşma yok', (t) async {
      final b = FakeBackend()
        ..on('/me/notification-mutes', {'communities': [7], 'events': [5]})
        ..on('/communities/7', {'id': 7, 'name': 'نادي الشطرنج الجامعي الطويل جدا جدا ' * 2})
        ..on('/events/5', {'id': 5, 'title': 'فعالية ' * 12});
      await _app(t, MutedItemsPage(session: makeSession(b)), size: kPhoneSmall, locale: const Locale('ar'));
      expect(t.takeException(), isNull);
      await unmount(t);
    });
  });

  group('Şikayetlerim', () {
    Map<String, dynamic> r(int id, String type, String reason, String status) =>
        {'id': id, 'targetType': type, 'reason': reason, 'status': status, 'createdAt': '2026-11-01T10:00:00Z', 'resolvedAt': status == 'RESOLVED' ? '2026-11-03T10:00:00Z' : null};

    testWidgets('etiketler, durum rozetleri ve imleç devamı', (t) async {
      final b = FakeBackend();
      b.handlers.add((req, path) {
        if (path != '/reports/mine') return null;
        if (req.url.queryParameters['cursor'] == null) {
          return FakeResult.json({'items': [r(30, 'FORUM_TOPIC', 'SPAM', 'OPEN')], 'nextCursor': 20});
        }
        return FakeResult.json({'items': [r(20, 'POST', 'HARASSMENT', 'RESOLVED')], 'nextCursor': null});
      });
      await _app(t, MyReportsListPage(session: makeSession(b)));
      expect(b.requests.any((q) => q.contains('cursor=20')), isTrue);
      expect(find.text('Forum konusu'), findsOneWidget);
      expect(find.text('Gönderi'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('report-status-30')), matching: find.text('Açık')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('report-status-20')), matching: find.text('Sonuçlandı')), findsOneWidget);
      await unmount(t);
    });

    testWidgets('boş ve hata durumları', (t) async {
      await _app(t, MyReportsListPage(session: makeSession(FakeBackend()..on('/reports/mine', {'items': [], 'nextCursor': null}))));
      expect(find.byKey(const ValueKey('reports-empty')), findsOneWidget);
      await unmount(t);
      await _app(t, MyReportsListPage(session: makeSession(FakeBackend()..fail('/reports/mine', status: 500))));
      expect(find.text('Yeniden dene'), findsWidgets);
      await unmount(t);
    });

    for (final loc in [const Locale('tr'), const Locale('ar')]) {
      testWidgets('320dp taşma yok (${loc.languageCode})', (t) async {
        final b = FakeBackend()..on('/reports/mine', {'items': [r(1, 'FORUM_COMMENT', 'PERSONAL_INFO', 'RESOLVED'), r(2, 'COMMUNITY', 'OTHER', 'OPEN')], 'nextCursor': null});
        await _app(t, MyReportsListPage(session: makeSession(b)), size: kPhoneSmall, locale: loc);
        expect(t.takeException(), isNull);
        await unmount(t);
      });
    }
  });
}
