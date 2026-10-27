import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bu_kampus/core/theme.dart';

import 'package:bu_kampus/features/auth/forgot_password_page.dart';
import 'package:bu_kampus/features/auth/login_page.dart';
import 'package:bu_kampus/features/auth/new_password_page.dart';
import 'package:bu_kampus/features/auth/permissions_page.dart';
import 'package:bu_kampus/features/auth/register_page.dart';
import 'package:bu_kampus/features/auth/reset_code_page.dart';
import 'package:bu_kampus/features/auth/verify_code_page.dart';
import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:bu_kampus/features/news/news_detail_page.dart';
import 'package:bu_kampus/features/news/news_tile.dart';
import 'package:bu_kampus/features/posts/compose_post_page.dart';
import 'package:bu_kampus/features/posts/post_detail_page.dart';
import 'package:bu_kampus/features/posts/post_feed_view.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:bu_kampus/features/posts/user_posts_page.dart';
import 'package:bu_kampus/features/shell/floating_nav.dart';
import 'package:bu_kampus/features/system/gate_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Görsel duman testleri (ajan A sayfaları): kimlik, ana sayfa, Keşfet, haber, gönderiler, sistem, alt bar.
/// Her sayfa x tema x ekran x yazı ölçeği: taşma/istisna yok. `VSHOT=1` ile PNG'ler `build/shots/a/` altına yazılır.
final _boundary = GlobalKey();
final _shots = Platform.environment['VSHOT'] == '1';

class _Case {
  const _Case(this.name, this.build, [this.setup]);
  final String name;
  final Widget Function(FakeBackend b) build;
  final void Function(FakeBackend b)? setup;
}

const _long = 'Bingöl Üniversitesi Bilgisayar Mühendisliği Topluluğu Yapay Zeka ve Veri Bilimi Kariyer Günleri 2026 Büyük Buluşma';

Map<String, dynamic> _ev() => {
      'id': 9,
      'source': 'USER',
      'title': _long,
      'description': 'Açıklama',
      'startsAt': DateTime.now().add(const Duration(days: 2)).toUtc().toIso8601String(),
      'endsAt': DateTime.now().add(const Duration(days: 2, hours: 2)).toUtc().toIso8601String(),
      'location': 'Merkez Kampüs Konferans Salonu',
      'communityName': 'Bilgisayar Mühendisliği Topluluğu',
      'goingCount': 42,
      'interestedCount': 7,
      'myRsvp': null,
      'status': 'ACTIVE',
      'coverUrl': null,
      'attendeesPreview': [
        {'userId': 1, 'displayName': 'Ayşe Yılmaz', 'avatarUrl': null},
      ],
    };

List<Map<String, dynamic>> _news() => [
      newsItem(1, title: 'Çok uzun bir haber başlığı ' * 5),
      newsItem(2, type: 'ETKINLIK', eventDate: '2026-11-03'),
      newsItem(3, type: 'DUYURU', title: 'Uzunkelime' * 12),
    ];

void _homeData(FakeBackend b) {
  b
    ..on('/events/featured', _ev())
    ..on('/events/9/attendees/preview', {'goingCount': 42, 'avatars': []})
    ..on('/news*', newsPage(_news()))
    ..on('/me/summary', {'unreadNotifications': 120, 'unreadMessages': 1234, 'communities': 3, 'upcomingEvents': 2})
    ..on('/menu/today', {
      'date': '2026-10-27',
      'items': [
        'Mercimek çorbası',
        'Orman kebabı ve pirinç pilavı',
      ],
    });
}

final _cases = <_Case>[
  _Case('login', (b) => LoginPage(session: makeSession(b, signedIn: false))),
  _Case('register', (b) => RegisterPage(session: makeSession(b, signedIn: false)), fakeCatalog),
  _Case('forgot', (b) => ForgotPasswordPage(session: makeSession(b, signedIn: false))),
  _Case('verify', (b) => VerifyCodePage(session: makeSession(b, signedIn: false), email: 'ayse.cok.uzun.eposta.adresi@ogr.bingol.edu.tr')),
  _Case('resetCode', (b) => ResetCodePage(session: makeSession(b, signedIn: false), email: 'ayse@bingol.edu.tr')),
  _Case('newPassword',
      (b) => NewPasswordPage(session: makeSession(b, signedIn: false), email: 'ayse@bingol.edu.tr', resetToken: 't')),
  _Case('permissions', (b) => PermissionsPage(onFinished: () {})),
  _Case('home', (b) => Scaffold(body: HomeTab(session: makeSession(b), onOpenTab: (i, {newsType}) {})), _homeData),
  _Case('home_bos', (b) => Scaffold(body: HomeTab(session: makeSession(b), onOpenTab: (i, {newsType}) {}))),
  _Case('home_bakim', (b) => Scaffold(body: HomeTab(session: makeSession(b), onOpenTab: (i, {newsType}) {})), (b) {
    _homeData(b);
    b.on('/status', {
      'NEWS': {'maintenance': true},
      'MENU': {'maintenance': true},
    });
    b.on('/app/info', {
      'maintenance': {'enabled': true, 'message': 'Planlı bakım var. ' * 6},
      'banner': {'text': 'Duyuru bandı ' * 8},
    });
  }),
  _Case('discover_haber',
      (b) => DiscoverTab(session: makeSession(b), typeRequest: ValueNotifier<String?>(null)), (b) {
    fakePosts(b);
    b.on('/news*', newsPage(_news()));
  }),
  _Case('discover_hata', (b) => DiscoverTab(session: makeSession(b), typeRequest: ValueNotifier<String?>(null)), (b) {
    b.fail('/news');
    b.fail('/feed');
  }),
  _Case('news_tiles', (b) {
    final items = _news();
    return Scaffold(
      body: ListView(padding: const EdgeInsets.all(20), children: [
        NewsFeaturedCard(item: items[0], saved: true, onTap: () {}, onToggleSave: () {}),
        for (final n in items) NewsTile(item: n, onTap: () {}, saved: false, onToggleSave: () {}),
      ]),
    );
  }),
  _Case('news_detail', (b) => NewsDetailPage(session: makeSession(b), item: newsItem(2, type: 'ETKINLIK', eventDate: '2026-11-03')),
      (b) => b.on('/news/2', {'id': 2, 'content': 'Birinci paragraf metni burada.\n\nİkinci paragraf çok uzun bir metindir ' * 5, 'url': 'https://www.bingol.edu.tr/x'})),
  _Case('news_detail_hata', (b) => NewsDetailPage(session: makeSession(b), item: newsItem(5, title: 'Uzunkelime' * 12)),
      (b) => b.fail('/news/5')),
  _Case('post_feed', (b) => Scaffold(body: PostFeedView(session: makeSession(b), scope: 'latest')), (b) => fakePosts(b)),
  _Case('post_feed_bos', (b) => Scaffold(body: PostFeedView(session: makeSession(b), scope: 'latest')),
      (b) => fakePosts(b, empty: true)),
  _Case('post_feed_hata', (b) => Scaffold(body: PostFeedView(session: makeSession(b), scope: 'latest')),
      (b) => fakePosts(b).failFeed = true),
  _Case('post_detail', (b) => PostDetailPage(session: makeSession(b), postId: 91, initial: Post.fromJson(samplePost(id: 91, text: 'Çok uzun bir gönderi metni 😀 ' * 12, commentCount: 3))), (b) {
    b.on('/posts/91', samplePost(id: 91, text: 'Çok uzun bir gönderi metni 😀 ' * 12, commentCount: 3));
    b.on('/posts/91/comments', {
      'items': [
        sampleComment(id: 1, text: 'Uzunkelime' * 15, replyCount: 2, authorName: 'Mehmet Kaya ' * 4),
        sampleComment(id: 2, text: 'Kısa yorum', mine: true),
        sampleComment(id: 3, deleted: true),
      ],
      'nextCursor': null,
      'total': 3,
    });
  }),
  _Case('compose', (b) => ComposePostPage(session: makeSession(b))),
  _Case('user_posts', (b) => UserPostsPage(session: makeSession(b), userId: 12, name: 'Ayşe Yılmaz'), (b) => fakePosts(b)),
  _Case('update_required', (b) => const UpdateRequiredScreen(storeUrl: 'https://apps.apple.com/x')),
  _Case(
      'gate_strips',
      (b) => Scaffold(
            body: Column(children: [
              TopStrip(icon: Icons.build, text: 'Sistem bakımda. ' * 8, danger: true),
              const TopStrip(icon: Icons.wifi_off, text: 'Çevrimdışı'),
              const SizedBox(height: 24),
              UpdateNotice(latest: '2.0.0', storeUrl: 'https://x.example/a', onClose: () {}),
            ]),
          )),
  _Case(
      'floating_nav',
      (b) => Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: FloatingNav(index: 1, onChanged: (_) {}, chatBadge: ValueNotifier<int>(120)),
          )),
];

const _scales = [1.0, 1.5, 2.0];

Future<void> _render(WidgetTester tester, _Case c, Brightness br, Size size, double scale,
    {bool rtl = false, String? shot}) async {
  useScreen(tester, size);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final b = FakeBackend();
  c.setup?.call(b);
  Widget page = c.build(b);
  if (rtl) page = Directionality(textDirection: TextDirection.rtl, child: page);
  final errors = <String>[];
  final prev = FlutterError.onError;
  FlutterError.onError = (d) {
    final msg = d.exceptionAsString().split(String.fromCharCode(10)).take(3).join(' | ');
    final w = d.toString().split(String.fromCharCode(10)).where((l) => l.contains('package:bu_kampus') || l.contains('creator:')).take(2).join(' ');
    errors.add('$msg $w');
  };
  try {
    await tester.pumpWidget(buildApp(RepaintBoundary(key: _boundary, child: page), brightness: br, size: size));
    await settle(tester, const Duration(milliseconds: 900));
    if (shot != null) {
      final boundary = _boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final img = await boundary.toImage(pixelRatio: 1.5);
        final png = (await img.toByteData(format: ui.ImageByteFormat.png))!;
        final dir = Directory('build/shots/a')..createSync(recursive: true);
        File('${dir.path}/$shot.png').writeAsBytesSync(png.buffer.asUint8List());
      });
    }
    await unmount(tester);
  } finally {
    FlutterError.onError = prev;
  }
  if (errors.isNotEmpty) {
    tester.takeException();
    fail('${c.name} ${br.name} ${size.width.toInt()} x$scale${rtl ? ' rtl' : ''}: ${errors.first}');
  }
}

void main() {
  setUpAll(loadTestFonts);

  group('gorsel duman matrisi', () {
    for (final c in _cases) {
      for (final br in Brightness.values) {
        for (final size in kPhoneSizes) {
          for (final sc in _scales) {
            testWidgets('${c.name} | ${br.name} ${size.width.toInt()} x$sc', (tester) async {
              await _render(tester, c, br, size, sc);
            });
          }
        }
      }
    }
  });

  group('RTL (Arapca)', () {
    for (final c in _cases.where((c) => const {
          'login', 'register', 'forgot', 'verify', 'home', 'discover_haber', 'news_tiles', 'post_feed', 'post_detail', 'compose', 'floating_nav'
        }.contains(c.name))) {
      for (final br in Brightness.values) {
        testWidgets('${c.name} rtl ${br.name}', (tester) async {
          await _render(tester, c, br, kPhoneSmall, 1.3, rtl: true);
        });
      }
    }
  });

  if (_shots) {
    group('PNG uretimi', () {
      for (final c in _cases) {
        for (final br in Brightness.values) {
          for (final (size, sc) in [(kPhoneSmall, 1.0), (kPhoneSmall, 2.0), (kPhoneMedium, 1.0), (kPhoneLarge, 1.3)]) {
            testWidgets('shot ${c.name} ${br.name} ${size.width.toInt()} x$sc', (tester) async {
              await _render(tester, c, br, size, sc,
                  shot: '${c.name}__${br.name}_${size.width.toInt()}_x${sc.toString().replaceAll('.', '')}');
            });
          }
        }
      }
    });
  }

  group('kontrast (WCAG AA) - tema renk ciftleri', () {
    // textContrastGuideline ince küçük yazıda yanlış alarm veriyor; gerçek renk çiftleri doğrudan ölçülür.
    double lum(Color c) {
      double ch(double v) => v <= .03928 ? v / 12.92 : math.pow((v + .055) / 1.055, 2.4).toDouble();
      return .2126 * ch(c.r) + .7152 * ch(c.g) + .0722 * ch(c.b);
    }

    double ratio(Color a, Color b) {
      final x = lum(a), y = lum(b);
      return (math.max(x, y) + .05) / (math.min(x, y) + .05);
    }

    for (final (name, t) in [('acik', BuTokens.light), ('koyu', BuTokens.dark)]) {
      final pairs = <String, (Color, Color)>{
        'ink/bg': (t.ink, t.bg),
        'ink/sf': (t.ink, t.sf),
        'mut/bg': (t.mut, t.bg),
        'mut/sf': (t.mut, t.sf),
        'mut/sf2': (t.mut, t.sf2),
        'pr/bg (baglanti)': (t.pr, t.bg),
        'pr/sf (baglanti)': (t.pr, t.sf),
        'onPr/pr (dugme)': (t.onPr, t.pr),
        'onSoft/soft': (t.onSoft, t.soft),
        'danger/bg': (t.danger, t.bg),
        'danger/sf': (t.danger, t.sf),
        'ok/okSoft': (t.ok, t.okSoft),
        'onNav/nav': (t.onNav, t.nav),
        'bg/danger (bakim seridi)': (t.bg, t.danger),
      };
      pairs.forEach((k, v) {
        test('$name $k >= 4.5', () => expect(ratio(v.$1, v.$2), greaterThanOrEqualTo(4.5), reason: '$name $k'));
      });
    }

    test('hero gradyan uclarinda beyaz yazi >= 4.5', () {
      for (final t in [BuTokens.light, BuTokens.dark]) {
        expect(ratio(Colors.white, t.h1), greaterThanOrEqualTo(4.5), reason: 'h1 ${t.h1}');
        expect(ratio(Colors.white, t.h2), greaterThanOrEqualTo(4.5), reason: 'h2 ${t.h2}');
      }
    });
  });

  if (_shots) {
    group('PNG uretimi (RTL)', () {
      for (final c in _cases.where((c) => const {'login', 'home', 'discover_haber', 'post_detail', 'floating_nav'}.contains(c.name))) {
        testWidgets('shot rtl ${c.name}', (tester) async {
          await _render(tester, c, Brightness.light, kPhoneMedium, 1.0, rtl: true, shot: '${c.name}__rtl_light_390');
        });
      }
    });
  }

  group('erisilebilirlik', () {
    for (final c in _cases) {
      testWidgets('${c.name} dokunma hedefi + etiket', (tester) async {
        final h = tester.ensureSemantics();
        useScreen(tester, kPhoneMedium);
        final b = FakeBackend();
        c.setup?.call(b);
        await tester.pumpWidget(buildApp(c.build(b), size: kPhoneMedium));
        await settle(tester, const Duration(milliseconds: 900));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await unmount(tester);
        h.dispose();
      });
    }
  });
}
