import 'dart:convert';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/device_identity.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:bu_kampus/main.dart' show installErrorHandling;
import 'package:bu_kampus/features/clubs/club_detail_page.dart';
import 'package:bu_kampus/features/clubs/clubs_tab.dart';
import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/features/events/event_detail_page.dart';
import 'package:bu_kampus/features/events/events_page.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:bu_kampus/features/menu/menu_page.dart';
import 'package:bu_kampus/features/news/news_detail_page.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:bu_kampus/features/posts/post_detail_page.dart';
import 'package:bu_kampus/features/profile/blocked_users_page.dart';
import 'package:bu_kampus/features/profile/legal_pages.dart';
import 'package:bu_kampus/features/profile/my_clubs_page.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/features/profile/saved_news_page.dart';
import 'package:bu_kampus/features/search/search_page.dart';
import 'package:bu_kampus/features/support/support_page.dart';
import 'package:bu_kampus/features/support/support_suggestions_page.dart';
import 'package:bu_kampus/features/system/gate_views.dart';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_app.dart';

/// Sunucu şeması beklenmedik biçimde değiştiğinde (ya da araya giren bir vekil HTML/boş gövde döndüğünde)
/// ana sayfalar çökmemeli: hata ekranına ya da boş duruma düşmeli (`takeException` null).
final Map<String, Object?> _shapes = {
  'bos-nesne': <String, dynamic>{},
  'bos-liste': <Object>[],
  'metin': 'merhaba',
  'sayi': 42,
  'null': null,
  'items-metin': {'items': 'x', 'nextCursor': 'y', 'ids': 'z', 'groups': 5},
  'items-null-ogeler': {
    'items': [null, 5, 'a', <Object>[]],
    'ids': [null, 'a'],
    'groups': [null, 7],
    'nextCursor': null,
  },
  // Alan düzeyinde tür kayması (id yerine metin vb.): yapı doğru, yalnız eksik/null alanlar.
  'eksik-alanli-ogeler': {
    'items': [
      {'id': 1},
      {'id': 2, 'title': null, 'type': null, 'createdAt': null, 'imageUrl': null},
      <String, dynamic>{},
    ],
    'groups': [
      {'type': 'NEWS', 'items': <Object>[]},
    ],
    'id': 1,
  },
};

typedef _Build = Widget Function(Session s);

void main() {
  group('bozuk sunucu gövdesi', () {
    final pages = <String, _Build>{
      'Ana sayfa': (s) => Scaffold(body: HomeTab(session: s, onOpenTab: (i, {newsType}) {})),
      'Kesfet': (s) => DiscoverTab(session: s, typeRequest: ValueNotifier<String?>(null)),
      'Kulupler': (s) => ClubsTab(session: s),
      'Etkinlikler': (s) => EventsPage(session: s),
      'Sohbet': (s) => ChatTab(session: s, connectRealtime: false),
      'Bildirimler': (s) => NotificationsPage(session: s),
      'Arama': (s) => SearchPage(session: s),
      'Destek': (s) => SupportPage(session: s),
      'Oneriler': (s) => SuggestionsPage(session: s),
      'Yemek': (s) => MenuPage(session: s),
      'Kayitli haberler': (s) => SavedNewsPage(session: s),
      'Kuluplerim': (s) => MyClubsPage(session: s),
      'Engelliler': (s) => BlockedUsersPage(session: s),
      'Sozlesmeler': (s) => LegalListPage(session: s),
      'Sozlesme': (s) => LegalDocPage(session: s, type: 'TERMS'),
      'Profil': (s) => ProfileTab(session: s, themeController: ThemeController()),
      'Haber detay': (s) => NewsDetailPage(session: s, item: newsItem(1)),
      'Etkinlik detay': (s) => EventDetailPage(session: s, eventId: 1),
      'Kulup detay': (s) => ClubDetailPage(session: s, communityId: 1),
      'Gonderi detay': (s) => PostDetailPage(session: s, postId: 1),
    };

    for (final shape in _shapes.entries) {
      for (final page in pages.entries) {
        testWidgets('${page.key} / ${shape.key}', (tester) async {
          useScreen(tester, kPhoneMedium);
          final b = FakeBackend();
          b.handlers.add((req, path) => FakeResult.json(shape.value));
          await tester.pumpWidget(buildApp(page.value(makeSession(b))));
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 300));
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('ApiClient dayaniklilik', () {
    ApiClient make(http.Client c) => ApiClient(client: c, retryDelay: Duration.zero);

    test('gecersiz UTF-8 gövde istisna sızdırmaz', () async {
      final api = make(MockClient((r) async => http.Response.bytes([0xff, 0xfe, 0x7b], 200)));
      expect(await api.get('/x'), isNull);
    });

    test('bozuk JSON hata gövdesi ApiError olur', () async {
      final api = make(MockClient((r) async => http.Response('<html>502</html>', 500)));
      await expectLater(api.get('/x'), throwsA(isA<ApiError>().having((e) => e.status, 'status', 500)));
    });

    test('hata gövdesinde message tipi yanlışsa ApiError yine de olusur', () async {
      final api = make(MockClient((r) async => http.Response(jsonEncode({'code': 'X', 'message': 5}), 400)));
      await expectLater(api.get('/x'), throwsA(isA<ApiError>().having((e) => e.code, 'code', 'X')));
    });

    test('429 Retry-After okunur', () async {
      final api = make(MockClient((r) async =>
          http.Response(jsonEncode({'code': 'RATE_LIMITED', 'message': 'm'}), 429, headers: {'retry-after': '7'})));
      await expectLater(api.post('/x'), throwsA(isA<ApiError>().having((e) => e.retryAfter, 'retryAfter', 7)));
    });

    test('Retry-After sayi degilse null', () async {
      final api = make(MockClient((r) async => http.Response('', 429, headers: {'retry-after': 'abc'})));
      await expectLater(api.post('/x'), throwsA(isA<ApiError>().having((e) => e.retryAfter, 'retryAfter', isNull)));
    });

    test('bos gövde 200 null döner', () async {
      final api = make(MockClient((r) async => http.Response('', 200)));
      expect(await api.get('/x'), isNull);
    });

    test('cok buyuk yanit reddedilir', () async {
      final api = make(MockClient.streaming((r, _) async => http.StreamedResponse(
            Stream<List<int>>.value([1, 2, 3]),
            200,
            contentLength: ApiClient.maxResponseBytes + 1,
          )));
      await expectLater(api.get('/x'), throwsA(isA<ApiError>().having((e) => e.code, 'code', 'RESPONSE_TOO_LARGE')));
    });

    test('zaman asimi (ag yok) ApiError(0)', () async {
      final api = make(MockClient((r) async => throw http.ClientException('off')));
      await expectLater(api.get('/x'), throwsA(isA<ApiError>().having((e) => e.isNetwork, 'isNetwork', true)));
    });

    test('refresh yaniti bozuksa oturum sonlandirilmaz (BAD_RESPONSE, ag hatasi gibi)', () async {
      var expired = 0;
      final api = make(MockClient((r) async {
        if (r.url.path.endsWith('/auth/refresh')) return http.Response(jsonEncode({'accessToken': 5}), 200);
        return http.Response('', 401);
      }))
        ..tokens = Tokens('a', 'r')
        ..onSessionExpired = () => expired++;
      await expectLater(api.get('/x'), throwsA(isA<ApiError>().having((e) => e.code, 'code', 'BAD_RESPONSE')));
      expect(expired, 0);
    });

    test('Tokens.fromJson bozuk gövdede ApiError', () {
      for (final j in <Object?>[null, 'x', 3, <String, dynamic>{}, {'accessToken': 1, 'refreshToken': 2}]) {
        expect(() => Tokens.fromJson(j), throwsA(isA<ApiError>()));
      }
    });
  });

  group('cihaz kimligi basliklari', () {
    tearDown(() => DeviceIdentity.instance.debugSet(null));

    test('her istekte X-Device-Id / X-Device-Platform / X-App-Version gider', () async {
      DeviceIdentity.instance.debugSet('11111111-2222-4333-8444-555555555555');
      late http.BaseRequest seen;
      final api = ApiClient(client: MockClient((r) async {
        seen = r;
        return http.Response('{}', 200);
      }));
      await api.get('/x');
      expect(seen.headers['X-Device-Id'], '11111111-2222-4333-8444-555555555555');
      expect(seen.headers['X-Device-Platform'], isNotEmpty);
      expect(seen.headers['X-App-Version'], isNotEmpty);
      await api.post('/y', {'a': 1});
      expect(seen.headers['X-Device-Id'], isNotNull);
    });

    test('kimlik hazir degilken yalniz platform/surum gider', () async {
      DeviceIdentity.instance.debugSet(null);
      late http.BaseRequest seen;
      final api = ApiClient(client: MockClient((r) async {
        seen = r;
        return http.Response('{}', 200);
      }));
      await api.get('/x');
      expect(seen.headers.containsKey('X-Device-Id'), false);
      expect(seen.headers['X-App-Version'], isNotEmpty);
    });

    test('STOMP basliklari', () {
      DeviceIdentity.instance.debugSet('abc-123-abc-123-abc-123');
      final h = DeviceIdentity.instance.stompHeaders;
      expect(h['device-id'], 'abc-123-abc-123-abc-123');
      expect(h.containsKey('device-platform'), true);
      expect(h.containsKey('app-version'), true);
    });

    test('UUID v4 bicimi ve benzersizlik', () {
      final a = generateUuid();
      expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(a), true);
      expect(generateUuid(), isNot(a));
    });

    test('load() kimligi uretir ve guvenli depodan tekrar okur', () async {
      mockSecureStorage();
      final d = DeviceIdentity.instance..debugSet(null);
      await d.load();
      final first = d.id;
      expect(first, isNotNull);
      d.debugSet(null);
      await d.load();
      expect(d.id, first);
    });
  });

  group('ACCESS_BLOCKED', () {
    http.Response blocked() =>
        http.Response(jsonEncode({'code': 'ACCESS_BLOCKED', 'message': 'engel'}), 403);

    test('403 ACCESS_BLOCKED: oturum silinir, refresh denenmez, engel bayragi acilir', () async {
      mockSecureStorage();
      final paths = <String>[];
      final api = ApiClient(
        client: MockClient((r) async {
          paths.add(r.url.path);
          return blocked();
        }),
        retryDelay: Duration.zero,
      );
      final s = Session(api)..state = SessionState.signedIn;
      api.tokens = Tokens('a', 'r');
      await expectLater(api.get('/news'), throwsA(isA<ApiError>().having((e) => e.code, 'code', 'ACCESS_BLOCKED')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(s.accessBlocked.value, true);
      expect(s.state, SessionState.signedOut);
      expect(api.tokens, isNull);
      expect(paths.where((p) => p.endsWith('/auth/refresh')), isEmpty);
      s.dismissAccessBlocked();
      expect(s.accessBlocked.value, false);
    });

    test('giristen once (oturumsuz) de bayrak acilir', () async {
      mockSecureStorage();
      final api = ApiClient(client: MockClient((r) async => blocked()), retryDelay: Duration.zero);
      final s = Session(api)..state = SessionState.signedOut;
      await expectLater(s.login('a@bingol.edu.tr', 'x'), throwsA(isA<ApiError>()));
      expect(s.accessBlocked.value, true);
    });

    testWidgets('AccessBlockedScreen metni ve tekrar dene', (tester) async {
      var retried = 0;
      await tester.pumpWidget(buildApp(AccessBlockedScreen(onRetry: () => retried++)));
      expect(find.textContaining('Bu cihaza veya ağa erişim kapatıldı'), findsOneWidget);
      await tester.tap(find.text('Tekrar dene'));
      expect(retried, 1);
    });
  });

  group('global hata yakalama (release)', () {
    testWidgets('FlutterError.onError / PlatformDispatcher.onError / ErrorWidget.builder', (tester) async {
      final prevFlutter = FlutterError.onError;
      final prevPlatform = PlatformDispatcher.instance.onError;
      final prevBuilder = ErrorWidget.builder;
      addTearDown(() {
        FlutterError.onError = prevFlutter;
        PlatformDispatcher.instance.onError = prevPlatform;
        ErrorWidget.builder = prevBuilder;
      });
      installErrorHandling(release: true);

      // Çerçeve hatası süreci düşürmez (release'te yalnız raporlanır).
      FlutterError.onError!(FlutterErrorDetails(exception: StateError('x')));
      // Yakalanmayan asenkron hata "işlendi" sayılır.
      final handled = PlatformDispatcher.instance.onError!(StateError('y'), StackTrace.current);
      // Çizim hatası kırmızı ekran yerine sade görünüm.
      final fallback = ErrorWidget.builder(FlutterErrorDetails(exception: StateError('z')));
      FlutterError.onError = prevFlutter; // expect'ten önce geri al
      PlatformDispatcher.instance.onError = prevPlatform;
      ErrorWidget.builder = prevBuilder;
      expect(handled, isTrue);
      expect(fallback.runtimeType.toString(), '_ErrorView');
      await tester.pumpWidget(MaterialApp(home: fallback));
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });
  });
}
