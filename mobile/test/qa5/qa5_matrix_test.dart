// QA-5 parametrik durum matrisi: forum + destek + kabuk ekranları x (başarı / boş / hata 401,403,404,429,500 / çevrimdışı)
// x (tr/en/ar+RTL) x (320 dp @1.3 yazı, 390 dp @1.0) x (açık/koyu). Her hücre: istisna (taşma dahil) yok, ham hata
// metni (Exception/ApiError/Instance of) kullanıcıya sızmaz, ekran ayakta kalır.
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/forum/data/forum_api.dart';
import 'package:bu_kampus/features/forum/presentation/pages/create_topic_page.dart';
import 'package:bu_kampus/features/forum/presentation/pages/forum_activity_page.dart';
import 'package:bu_kampus/features/forum/presentation/pages/forum_category_picker_page.dart';
import 'package:bu_kampus/features/forum/presentation/pages/forum_home_page.dart';
import 'package:bu_kampus/features/forum/presentation/pages/forum_prefs_page.dart';
import 'package:bu_kampus/features/forum/presentation/pages/forum_saved_page.dart';
import 'package:bu_kampus/features/forum/presentation/pages/forum_search_page.dart';
import 'package:bu_kampus/features/forum/presentation/pages/topic_detail_page.dart';
import 'package:bu_kampus/features/support/support_feedback_page.dart';
import 'package:bu_kampus/features/support/support_new_ticket_page.dart';
import 'package:bu_kampus/features/support/support_page.dart';
import 'package:bu_kampus/features/support/support_suggestions_page.dart';
import 'package:bu_kampus/features/support/support_ticket_page.dart';
import 'package:bu_kampus/features/system/gate_views.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/fake_forum.dart';
import '../support/fake_forum_comments.dart';

class _Env {
  const _Env(this.name, this.locale, this.dark, this.size, this.scale);
  final String name;
  final Locale locale;
  final bool dark;
  final Size size;
  final double scale;
}

const _envs = [
  _Env('tr-acik-390', Locale('tr'), false, kPhoneMedium, 1.0),
  _Env('tr-koyu-320-x1.3', Locale('tr'), true, kPhoneSmall, 1.3),
  _Env('en-acik-320-x1.3', Locale('en'), false, kPhoneSmall, 1.3),
  _Env('ar-acik-390-rtl', Locale('ar'), false, kPhoneMedium, 1.0),
  _Env('ar-koyu-320-x1.3-rtl', Locale('ar'), true, kPhoneSmall, 1.3),
];

Widget _app(Widget home, _Env e) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BuTheme.light(),
      darkTheme: BuTheme.dark(),
      themeMode: e.dark ? ThemeMode.dark : ThemeMode.light,
      locale: e.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(e.scale)),
        child: child!,
      ),
      home: home,
    );

class _Page {
  const _Page(this.name, this.build, {this.seed, this.prefixes = const ['/forum'], this.okFinder});
  final Finder Function()? okFinder; // başarı hücresinde ekranın GERÇEKTEN veriyi çizdiğinin kanıtı
  final String name;
  final Widget Function(Session s) build;
  final void Function(FakeBackend b)? seed;
  final List<String> prefixes; // hata/boş matrisinde bozulacak yol önekleri
}

void _forumSeed(FakeBackend b) {
  final f = fakeForum(b, count: 12);
  fakeForumComments(b, f);
}

void _supportSeed(FakeBackend b) {
  b.on('/faq', [
    {
      'category': 'Hesap',
      'items': [
        {'id': 1, 'question': 'Şifremi nasıl sıfırlarım?', 'answer': 'Giriş ekranından "Şifremi unuttum" ile.'},
      ],
    },
  ]);
  b.on('/support/tickets*', {
    'items': [
      {'id': 5, 'category': 'ACCOUNT', 'subject': 'Giriş sorunu', 'status': 'OPEN', 'createdAt': '2026-11-01T10:00:00Z', 'updatedAt': '2026-11-02T10:00:00Z', 'lastMessageAt': '2026-11-02T10:00:00Z'},
    ],
    'nextCursor': null,
  });
  b.on('/support/tickets/5', {
    'ticket': {'id': 5, 'category': 'ACCOUNT', 'subject': 'Giriş sorunu', 'status': 'OPEN', 'createdAt': '2026-11-01T10:00:00Z', 'updatedAt': '2026-11-02T10:00:00Z'},
    'messages': [
      {'id': 1, 'fromStaff': false, 'text': 'Giriş yapamıyorum', 'createdAt': '2026-11-01T10:00:00Z'},
      {'id': 2, 'fromStaff': true, 'text': 'Yardımcı olalım.', 'createdAt': '2026-11-02T10:00:00Z'},
    ],
  });
  b.on('/feedback/mine*', {'items': [], 'nextCursor': null});
  b.on('/suggestions*', {
    'items': [
      {'id': 1, 'subject': 'Kütüphane saatleri', 'message': 'Uzatılsın', 'status': 'APPROVED', 'adminResponse': null, 'voteCount': 3, 'voted': false, 'createdAt': '2026-11-01T10:00:00Z'},
    ],
    'page': 0,
    'totalPages': 1,
    'totalItems': 1,
  });
}

final _pages = <_Page>[
  _Page('forum ana sayfa', (s) => ForumHomePage(session: s), seed: _forumSeed, okFinder: () => find.byKey(const ValueKey('forum-topic-500'))),
  _Page('konu detayı', (s) => TopicDetailPage(session: s, topicId: 500), seed: _forumSeed, okFinder: () => find.byKey(const ValueKey('commentField'))),
  _Page('yeni konu', (s) => CreateTopicPage(session: s), seed: _forumSeed),
  _Page('forum arama', (s) => ForumSearchPage(session: s), seed: _forumSeed),
  _Page('kaydedilenler', (s) => ForumSavedPage(session: s), seed: _forumSeed),
  _Page('forum faaliyetim', (s) => ForumActivityPage(session: s), seed: _forumSeed),
  _Page('forum bildirim ayarları', (s) => ForumPrefsPage(session: s), seed: _forumSeed),
  _Page('kategori seçici', (s) => ForumCategoryPickerPage(api: ForumApi(s)), seed: _forumSeed),
  _Page('destek', (s) => SupportPage(session: s), seed: _supportSeed, prefixes: ['/faq', '/support']),
  _Page('yeni talep', (s) => NewTicketPage(session: s), seed: _supportSeed, prefixes: ['/support']),
  _Page('talep detayı', (s) => SupportTicketPage(session: s, ticketId: 5), seed: _supportSeed, prefixes: ['/support'], okFinder: () => find.textContaining('Giriş yapamıyorum')),
  _Page('geri bildirim', (s) => FeedbackPage(session: s), seed: _supportSeed, prefixes: ['/feedback']),
  _Page('öneri panosu', (s) => SuggestionsPage(session: s), seed: _supportSeed, prefixes: ['/suggestions'], okFinder: () => find.textContaining('Kütüphane saatleri')),
];

void _expectClean(WidgetTester tester, String where) {
  final e = tester.takeException();
  if (e != null) fail('$where: istisna/taşma: ${e.toString().split('\n').take(12).join('\n')}');
  for (final bad in ['Exception', 'ApiError', 'Instance of', 'Null check', 'type \'']) {
    expect(find.textContaining(bad), findsNothing, reason: '$where: ham hata metni sızdı ($bad)');
  }
}

void main() {
  setUpAll(loadTestFonts);

  for (final p in _pages) {
    group('matris: ${p.name}', () {
      for (final e in _envs) {
        testWidgets('başarı ${e.name}', (tester) async {
          useScreen(tester, e.size);
          final b = FakeBackend();
          p.seed?.call(b);
          await tester.pumpWidget(_app(p.build(makeSession(b)), e));
          await settle(tester, const Duration(seconds: 1));
          expect(find.byType(Scaffold), findsWidgets);
          if (p.okFinder != null) expect(p.okFinder!(), findsWidgets, reason: '${p.name}/${e.name}: veri çizilmedi');
          _expectClean(tester, '${p.name}/başarı/${e.name}');
          await unmount(tester);
        });
      }

      // Hata durumları tek ortamda (tr, 320 dp, x1.3, koyu: en zorlu) + ar/RTL bir kez.
      final failEnvs = [_envs[1], _envs[4]];
      for (final status in const [401, 403, 404, 429, 500]) {
        for (final e in failEnvs) {
          testWidgets('hata $status ${e.name}', (tester) async {
            useScreen(tester, e.size);
            final b = FakeBackend();
            p.seed?.call(b);
            b.handlers.insert(
                0,
                (req, path) => p.prefixes.any(path.startsWith)
                    ? FakeResult.json({'code': 'QA_FAIL_$status', 'message': 'Sunucu iletisi'}, status: status)
                    : null);
            await tester.pumpWidget(_app(p.build(makeSession(b)), e));
            await settle(tester, const Duration(seconds: 1));
            expect(find.byType(Scaffold), findsWidgets);
            _expectClean(tester, '${p.name}/hata $status/${e.name}');
            await unmount(tester);
          });
        }
      }

      for (final e in failEnvs) {
        testWidgets('çevrimdışı ${e.name}', (tester) async {
          useScreen(tester, e.size);
          final b = FakeBackend();
          p.seed?.call(b);
          b.offline = true;
          await tester.pumpWidget(_app(p.build(makeSession(b)), e));
          await settle(tester, const Duration(seconds: 1));
          expect(find.byType(Scaffold), findsWidgets);
          _expectClean(tester, '${p.name}/çevrimdışı/${e.name}');
          await unmount(tester);
        });

        testWidgets('boş veri ${e.name}', (tester) async {
          useScreen(tester, e.size);
          final b = FakeBackend();
          // Boş durum: konu/yorum/talep/öneri listeleri boş döner.
          b.handlers.insert(
              0,
              (req, path) => req.method == 'GET' && p.prefixes.any(path.startsWith)
                  ? const FakeResult.json({'items': [], 'nextCursor': null, 'groups': [], 'page': 0, 'totalPages': 0, 'totalItems': 0})
                  : null);
          await tester.pumpWidget(_app(p.build(makeSession(b)), e));
          await settle(tester, const Duration(seconds: 1));
          expect(find.byType(Scaffold), findsWidgets);
          _expectClean(tester, '${p.name}/boş/${e.name}');
          await unmount(tester);
        });
      }
    });
  }

  group('matris: kapı ekranları', () {
    final gates = <String, Widget Function()>{
      'zorunlu güncelleme (uzun metin)': () => UpdateRequiredScreen(
          storeUrl: 'https://play.google.com/store/apps/details?id=tr.com.bukampus.app',
          message: 'Bu sürüm artık desteklenmiyor. ' * 12,
          latest: '9.9.9',
          current: '2.0.0',
          onRetry: () {}),
      'bakım': () => MaintenanceScreen(onRetry: () {}, message: 'Planlı bakım. ' * 10),
      'çevrimdışı': () => OfflineScreen(onRetry: () {}),
      'erişim engeli': () => AccessBlockedScreen(onRetry: () {}),
    };
    for (final g in gates.entries) {
      for (final e in _envs) {
        testWidgets('${g.key} ${e.name}', (tester) async {
          mockSecureStorage();
          useScreen(tester, e.size);
          await tester.pumpWidget(_app(g.value(), e));
          await settle(tester, const Duration(milliseconds: 600));
          _expectClean(tester, '${g.key}/${e.name}');
          await unmount(tester);
        });
      }
    }
  });
}
