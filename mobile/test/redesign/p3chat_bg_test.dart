import 'dart:math' as math;

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/chat/chat_background_settings_page.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/chat_wallpaper.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'p00_support.dart';

/// Sohbet arka planı (konuşma ekranı duvar kağıdı): çizim, performans yapısı, kontrast, kalıcılık, hareket.
double _lum(Color c) {
  double ch(double v) => v <= .03928 ? v / 12.92 : math.pow((v + .055) / 1.055, 2.4).toDouble();
  return .2126 * ch(c.r) + .7152 * ch(c.g) + .0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + .05) / (math.min(la, lb) + .05);
}

Color _over(Color top, Color bottom) => Color.alphaBlend(top, bottom);

String _iso(DateTime d) => d.toUtc().toIso8601String();

void main() {
  setUpAll(loadTestFonts);
  setUp(() {
    mockSecureStorage();
    ChatWallpaper.debugResetCache();
    ChatBackgroundPrefs.debugReset();
  });

  Finder wall() => find.byKey(const ValueKey('chatWallpaper'));

  Future<void> pumpWall(WidgetTester tester, {bool dark = false, bool reduced = false, double scale = 1.0, ChatBgStyle? style, ChatBgDensity? density}) async {
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(p00App(
      ChatWallpaper(style: style, density: density, child: const SizedBox.expand()),
      dark: dark,
      disableAnimations: reduced,
      scale: scale,
      scaffold: false,
    ));
  }

  group('çizim', () {
    for (final dark in [false, true]) {
      testWidgets('desen ${dark ? 'koyu' : 'açık'} temada çizilir ve doku TEK sefer üretilir', (tester) async {
        await pumpWall(tester, dark: dark, style: ChatBgStyle.study, density: ChatBgDensity.strong);
        await tester.pump(const Duration(milliseconds: 400));
        expect(wall(), findsOneWidget);
        expect(ChatWallpaper.debugTileBuilds, 1);
        // Yeniden kurma/kaydırma/ek kare: doku yeniden üretilmez.
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await pumpWall(tester, dark: dark, style: ChatBgStyle.study, density: ChatBgDensity.strong);
        await tester.pump(const Duration(milliseconds: 400));
        expect(ChatWallpaper.debugTileBuilds, 1, reason: 'aynı tema/stil/yoğunluk önbellekten gelir');
        // Ayrı RepaintBoundary + blur yok.
        expect(find.ancestor(of: wall(), matching: find.byType(RepaintBoundary)), findsWidgets);
        expect(find.byType(BackdropFilter), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('tema değişince yeniden üretilir (koyu -> açık)', (tester) async {
      await pumpWall(tester, style: ChatBgStyle.study, density: ChatBgDensity.strong);
      await tester.pump(const Duration(milliseconds: 400));
      await pumpWall(tester, dark: true, style: ChatBgStyle.study, density: ChatBgDensity.strong);
      await tester.pump(const Duration(milliseconds: 400));
      expect(ChatWallpaper.debugTileBuilds, 2);
    });

    testWidgets('Düz seçenek yok: her desen çizilir (yordamsal doku)', (tester) async {
      expect(ChatBgStyle.values.map((e) => e.name), ['study', 'social', 'science', 'geometry']);
      for (final s in ChatBgStyle.values) {
        ChatWallpaper.debugResetCache();
        await pumpWall(tester, style: s);
        await tester.pump(const Duration(milliseconds: 400));
        expect(wall(), findsOneWidget, reason: s.name);
        expect(ChatWallpaper.debugTileBuilds, 1, reason: s.name);
      }
    });

    testWidgets('her yordamsal desen ayrı doku üretir (önbellek anahtarı desen içerir)', (tester) async {
      for (final s in [ChatBgStyle.study, ChatBgStyle.social, ChatBgStyle.science, ChatBgStyle.geometry]) {
        await pumpWall(tester, style: s);
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(ChatWallpaper.debugTileBuilds, 4);
      expect(ChatWallpaper.debugCacheSize, 4);
    });

    testWidgets('Hafif < Orta opaklık (açık ve koyu)', (tester) async {
      for (final dark in [false, true]) {
        final soft = ChatWallpaper.alphaOf(ChatBgStyle.study, ChatBgDensity.soft, dark);
        final strong = ChatWallpaper.alphaOf(ChatBgStyle.study, ChatBgDensity.strong, dark);
        expect(soft, lessThan(strong));
        // Açık %6-8 civarı (varsayılan), koyu %5-7 civarı.
        expect(soft, inInclusiveRange(dark ? .05 : .06, dark ? .07 : .08));
      }
    });
  });

  group('hareket', () {
    testWidgets('yeni doku 150 ms solarak gelir', (tester) async {
      await pumpWall(tester, style: ChatBgStyle.study, density: ChatBgDensity.strong);
      await tester.pump();
      // Hedef opaklık 1; animasyon 0 -> 1 arasında sürüyor (ara kare).
      final o = tester.widget<AnimatedOpacity>(wall());
      expect(o.duration, const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 60));
      final mid = tester.widget<FadeTransition>(find.descendant(of: wall(), matching: find.byType(FadeTransition))).opacity.value;
      expect(mid, inExclusiveRange(0.0, 1.0));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<FadeTransition>(find.descendant(of: wall(), matching: find.byType(FadeTransition))).opacity.value, 1.0);
    });

    testWidgets('"animasyonları azalt": anında, süre sıfır', (tester) async {
      await pumpWall(tester, reduced: true, style: ChatBgStyle.study, density: ChatBgDensity.strong);
      await tester.pump();
      final o = tester.widget<AnimatedOpacity>(wall());
      expect(o.opacity, 1.0);
      expect(o.duration, Duration.zero);
    });

    testWidgets('önbellekteki doku ikinci açılışta solmadan, anında görünür', (tester) async {
      await pumpWall(tester, style: ChatBgStyle.study, density: ChatBgDensity.strong);
      await tester.pump(const Duration(milliseconds: 300));
      await pumpWall(tester, style: ChatBgStyle.study, density: ChatBgDensity.strong, dark: false);
      await tester.pump();
      expect(tester.widget<AnimatedOpacity>(wall()).opacity, 1.0);
    });
  });

  group('okunabilirlik', () {
    for (final dark in [false, true]) {
      test('${dark ? 'koyu' : 'açık'}: balon yazısı >= 4.5 ve desen zemini yazıyı bozmaz', () {
        final t = dark ? BuTokens.dark : BuTokens.light;
        // Gelen balon: yüzey üstünde ink; giden: marka rengi üstünde onPr (dolgulu balonlar desenden bağımsız).
        expect(_contrast(t.ink, t.sf), greaterThanOrEqualTo(4.5));
        expect(_contrast(t.onPr, t.prPressed), greaterThanOrEqualTo(4.5));
        // En yoğun desen noktasında bile (zemin + ink alfa) metin/ikincil metin okunur kalır.
        final worst = _over(t.ink.withValues(alpha: ChatWallpaper.alphaOf(ChatBgStyle.study, ChatBgDensity.strong, dark)), t.bg);
        expect(_contrast(t.ink, worst), greaterThanOrEqualTo(7));
        expect(_contrast(t.mut, worst), greaterThanOrEqualTo(3));
        // Tarih hapı (sf + çizgi) desenden bağımsız dolgulu.
        expect(_contrast(t.mut, t.sf), greaterThanOrEqualTo(3));
      });
    }
  });

  group('kalıcılık', () {
    testWidgets('seçim kaydedilir, yeniden açılışta okunur; varsayılan anahtar tutmaz; çıkışta silinir', (tester) async {
      const st = FlutterSecureStorage();
      await tester.runAsync(() async {
        await ChatBackgroundPrefs.instance.set(ChatBgStyle.geometry, density: ChatBgDensity.strong);
        expect(await st.read(key: ChatBackgroundPrefs.key), 'geometry');
        expect(await st.read(key: ChatBackgroundPrefs.densityKey), 'strong');

        ChatBackgroundPrefs.debugReset();
        expect(ChatBackgroundPrefs.instance.style, ChatBgStyle.study);
        await ChatBackgroundPrefs.instance.ensureLoaded();
        expect(ChatBackgroundPrefs.instance.style, ChatBgStyle.geometry);
        expect(ChatBackgroundPrefs.instance.density, ChatBgDensity.strong);
        expect(ChatBackgroundPrefs.instance.loaded, isTrue);

        await ChatBackgroundPrefs.instance.set(ChatBgStyle.study, density: ChatBgDensity.soft);
        expect(await st.read(key: ChatBackgroundPrefs.key), isNull, reason: 'varsayılan kayıt tutmaz');
        expect(await st.read(key: ChatBackgroundPrefs.densityKey), isNull);

        await ChatBackgroundPrefs.instance.set(ChatBgStyle.social);
        await ChatBackgroundPrefs.clear();
        expect(await st.read(key: ChatBackgroundPrefs.key), isNull, reason: 'çıkışta temizlenir');
        expect(ChatBackgroundPrefs.instance.style, ChatBgStyle.study);
      });
    });

    testWidgets('eski kayıtlar: campus/plain/soft/pattern -> Ders (düz ve Kampüs YOK), strong -> Ders Orta', (tester) async {
      const st = FlutterSecureStorage();
      await tester.runAsync(() async {
        for (final old in ['campus', 'plain', 'soft', 'pattern']) {
          await st.write(key: ChatBackgroundPrefs.key, value: old);
          ChatBackgroundPrefs.debugReset();
          await ChatBackgroundPrefs.instance.ensureLoaded();
          expect(ChatBackgroundPrefs.instance.style, ChatBgStyle.study, reason: old);
          expect(ChatBackgroundPrefs.instance.density, ChatBgDensity.soft, reason: old);
        }
        await st.write(key: ChatBackgroundPrefs.key, value: 'strong');
        ChatBackgroundPrefs.debugReset();
        await ChatBackgroundPrefs.instance.ensureLoaded();
        expect(ChatBackgroundPrefs.instance.style, ChatBgStyle.study);
        expect(ChatBackgroundPrefs.instance.density, ChatBgDensity.strong);
        await ChatBackgroundPrefs.clear();
      });
    });

    testWidgets('tercih okunana dek desen çizilmez (zıplama yok); okununca belirir', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(p00App(const ChatWallpaper(child: SizedBox.expand()), scaffold: false));
      expect(wall(), findsNothing, reason: 'tercih henüz yüklenmedi');
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(ChatBackgroundPrefs.instance.loaded, isTrue);
      expect(wall(), findsOneWidget);
    });
  });

  group('ayarlar sayfası', () {
    for (final scale in [1.0, 1.3]) {
      testWidgets('320 dp x$scale taşma yok, düz seçenek yok, 5 desen + yoğunluk, Uygula kaydeder', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = kPhoneSmall;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(p00App(const ChatBackgroundSettingsPage(), scale: scale, scaffold: false));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Düz'), findsNothing, reason: 'düz zemin seçeneği kaldırıldı');
        expect(find.byKey(const ValueKey('chatBgStyles')), findsOneWidget);
        expect(find.byKey(const ValueKey('chatBgStyle-study')), findsOneWidget);
        expect(find.byKey(const ValueKey('chatBgDensity')), findsOneWidget);
        expect(find.text('Yoğunluk'), findsOneWidget);
        expect(find.text('Uygula'), findsOneWidget);
        expect(find.text('Varsayılana dön'), findsOneWidget);
        expect(tester.getSize(find.byKey(const ValueKey('chatBgApply'))).height, greaterThanOrEqualTo(48));
        // Önizleme her zaman desenli.
        Finder previewWall() => find.descendant(of: find.byKey(const ValueKey('chatBgPreview')), matching: find.byKey(const ValueKey('chatWallpaper')));
        expect(previewWall(), findsOneWidget);
        // Geometri + Orta seç: önizleme yine desenli; Uygula'ya basmadan kayıt değişmez.
        await tester.drag(find.byKey(const ValueKey('chatBgStyles')), const Offset(-600, 0));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.byKey(const ValueKey('chatBgStyle-geometry')));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('Orta'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(ChatBackgroundPrefs.instance.style, ChatBgStyle.study);
        expect(previewWall(), findsOneWidget);
        await tester.runAsync(() async {
          await tester.tap(find.byKey(const ValueKey('chatBgApply')));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump(const Duration(milliseconds: 300));
        expect(ChatBackgroundPrefs.instance.style, ChatBgStyle.geometry);
        expect(ChatBackgroundPrefs.instance.density, ChatBgDensity.strong);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() => ChatBackgroundPrefs.clear());
      });
    }
  });

  group('konuşma ekranı', () {
    testWidgets('duvar kağıdı mesajların arkasında; balonlar ve tarih hapı durur; desen değişince yenilenir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final msgs = [
        for (var i = 1; i <= 3; i++)
          {
            'id': i,
            'conversationId': 1,
            'senderId': i.isEven ? 1 : 11,
            'text': 'Mesaj $i',
            'createdAt': _iso(DateTime.now().subtract(Duration(minutes: 30 - i))),
          }
      ];
      final be = FakeBackend()
        ..on('/conversations/1/messages?size=30', {'items': msgs, 'nextCursor': null})
        ..on('/conversations/1', {
          'conversation': {'id': 1},
          'members': [
            {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
            {'userId': 11, 'displayName': 'Ali Veli'},
          ],
        })
        ..on('/users/11/presence', {'online': false})
        ..on('/messages/reactions', {'emojis': <String>[]});
      final page = ChatDetailPage(
        session: makeSession(be),
        connectRealtime: false,
        conversation: const {
          'id': 1,
          'type': 'DIRECT',
          'title': 'Ali Veli',
          'peer': {'id': 11, 'displayName': 'Ali Veli'},
        },
      );
      await tester.pumpWidget(p00App(page, scaffold: false));
      await settle(tester, const Duration(seconds: 1));
      expect(find.byType(ChatWallpaper), findsOneWidget);
      expect(wall(), findsOneWidget);
      expect(find.text('Mesaj 1'), findsOneWidget);
      expect(find.text('Mesaj 2'), findsOneWidget);
      expect(find.text('Bugün'), findsOneWidget);
      // Kaydırma: duvar kağıdı listeyle birlikte yeniden oluşturulmaz (doku sayısı değişmez).
      final builds = ChatWallpaper.debugTileBuilds;
      await tester.drag(find.byType(ListView).first, const Offset(0, 80));
      await tester.pump(const Duration(milliseconds: 200));
      expect(ChatWallpaper.debugTileBuilds, builds);
      await tester.runAsync(() => ChatBackgroundPrefs.instance.set(ChatBgStyle.geometry));
      await tester.pump(const Duration(milliseconds: 300));
      expect(wall(), findsOneWidget, reason: 'düz zemin yok: desen değişir ama kalkmaz');
      expect(find.text('Mesaj 1'), findsOneWidget);
      await tester.runAsync(() => ChatBackgroundPrefs.clear());
      expect(tester.takeException(), isNull);
    });

    for (final type in ['CLUB', 'EVENT']) {
      testWidgets('$type odası da duvar kağıdını kullanır (widget ağacında bağlı)', (tester) async {
        useScreen(tester, kPhoneMedium);
        final be = FakeBackend()
          ..on('/conversations/1/messages?size=30', {
            'items': [
              {'id': 1, 'conversationId': 1, 'senderId': 11, 'text': 'Merhaba oda', 'createdAt': _iso(DateTime.now())}
            ],
            'nextCursor': null,
          })
          ..on('/conversations/1', {
            'conversation': {'id': 1},
            'members': [
              {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
              {'userId': 11, 'displayName': 'Ali Veli'},
            ],
          })
          ..on('/messages/reactions', {'emojis': <String>[]});
        final page = ChatDetailPage(
          session: makeSession(be),
          connectRealtime: false,
          conversation: {'id': 1, 'type': type, 'title': 'Oda', 'communityId': 5, 'eventId': 7, 'memberCount': 12},
        );
        await tester.pumpWidget(p00App(page, scaffold: false));
        await settle(tester, const Duration(seconds: 1));
        expect(find.byType(ChatWallpaper), findsOneWidget);
        expect(wall(), findsOneWidget);
        expect(find.text('Merhaba oda'), findsOneWidget);
        // Duvar kağıdı mesaj listesinin ARKASINDA (Stack'te listeden önce).
        final stack = find.ancestor(of: find.byType(ListView), matching: find.byType(Stack)).first;
        final kids = tester.widget<Stack>(stack).children;
        expect(kids.length, greaterThanOrEqualTo(2));
        await tester.runAsync(() => ChatBackgroundPrefs.clear());
        expect(tester.takeException(), isNull);
      });
    }
  });
}
