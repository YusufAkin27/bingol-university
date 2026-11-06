import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/features/posts/post_card.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:bu_kampus/features/posts/like_button.dart';
import 'package:bu_kampus/features/posts/post_photo_viewer.dart';
import 'package:bu_kampus/widgets/pinch_zoomable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split(String.fromCharCode(10)).take(30).join(String.fromCharCode(10))}');
}

const _layer = ValueKey('zoom-layer-content');

/// Kopyanin (kok katman) o anki olcegi: icerigin en yakin Transform atasi.
double _layerScale(WidgetTester tester) {
  final t = find.ancestor(of: find.byKey(_layer), matching: find.byType(Transform)).first;
  return tester.widget<Transform>(t).transform.getMaxScaleOnAxis();
}

/// Iki parmak: merkezden [from] uzakta basar, [to] uzakliga acar.
Future<(TestGesture, TestGesture)> _pinch(WidgetTester tester, Offset c, {double from = 30, double to = 75}) async {
  final a = await tester.startGesture(c - Offset(from, 0));
  final b = await tester.startGesture(c + Offset(from, 0));
  await tester.pump(const Duration(milliseconds: 16));
  await a.moveTo(c - Offset((from + to) / 2, 0));
  await b.moveTo(c + Offset((from + to) / 2, 0));
  await tester.pump(const Duration(milliseconds: 16));
  await a.moveTo(c - Offset(to, 0));
  await b.moveTo(c + Offset(to, 0));
  await tester.pump(const Duration(milliseconds: 16));
  return (a, b);
}

Future<void> _release(WidgetTester tester, (TestGesture, TestGesture) g) async {
  await g.$1.up();
  await g.$2.up();
  await tester.pump(const Duration(milliseconds: 16)); // yay ilk karede baslar
}

void main() {
  setUpAll(loadTestFonts);

  group('PinchZoomable (genel)', () {
    final boxKey = GlobalKey();
    late ScrollController sc;
    var likes = 0;
    var taps = 0;

    Widget list({Widget? wrap, bool reduce = false, bool snapshot = false}) {
      sc = ScrollController();
      Widget zoom = PinchZoomable(
        overlayBuilder: snapshot ? null : (_) => const ColoredBox(key: _layer, color: Colors.red),
        child: SizedBox(key: boxKey, width: double.infinity, height: 300, child: const ColoredBox(color: Colors.blue)),
      );
      zoom = DoubleTapLike(onLike: () => likes++, onTap: () => taps++, child: zoom);
      return buildApp(Builder(builder: (context) {
        Widget body = Scaffold(
          body: ListView(controller: sc, children: [const SizedBox(height: 50), zoom, const SizedBox(height: 1500)]),
        );
        if (reduce) body = MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: body);
        return body;
      }));
    }

    setUp(() {
      likes = 0;
      taps = 0;
    });

    testWidgets('iki parmak acma: kopya buyur, parmak kalkinca 1x e doner, liste kaymaz, beğeni/dokunma tetiklenmez', (tester) async {
      useScreen(tester, const Size(390, 844));
      await tester.pumpWidget(list());
      final c = tester.getCenter(find.byKey(boxKey));
      expect(find.byKey(_layer), findsNothing);
      final g = await _pinch(tester, c);
      expect(find.byKey(_layer), findsOneWidget);
      expect(_layerScale(tester), closeTo(2.5, .01));
      expect(sc.offset, 0);
      // Kopya orijinalin ustunde, kok katmanda: baslangicta ayni dikdortgen degil buyutulmus.
      final r = tester.getRect(find.byKey(_layer));
      expect(r.width, closeTo(390 * 2.5, 1));
      // Parmaklari kaydirinca (pan) kopya odak noktasini izler.
      await g.$1.moveBy(const Offset(0, 40));
      await g.$2.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getRect(find.byKey(_layer)).top, closeTo(r.top + 40, 1));
      await _release(tester, g);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(_layer), findsOneWidget); // yay hala suruyor
      expect(_layerScale(tester), lessThan(2.5));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(); // kaldirilan katman bir sonraki karede ciziminden duser
      expect(find.byKey(_layer), findsNothing);
      await tester.pump(const Duration(milliseconds: 400));
      expect(likes, 0);
      expect(taps, 0);
      expect(sc.offset, 0);
      noErr(tester);
    });

    testWidgets('olcek 4x ile sinirli, 1x altina inmez', (tester) async {
      useScreen(tester, const Size(390, 844));
      await tester.pumpWidget(list());
      final c = tester.getCenter(find.byKey(boxKey));
      final g = await _pinch(tester, c, from: 20, to: 190);
      expect(_layerScale(tester), closeTo(4, .001));
      await _release(tester, g);
      await tester.pump(const Duration(seconds: 1));
      final g2 = await _pinch(tester, c, from: 80, to: 30);
      expect(_layerScale(tester), closeTo(1, .001));
      await _release(tester, g2);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(); // kaldirilan katman bir sonraki karede ciziminden duser
      expect(find.byKey(_layer), findsNothing);
      noErr(tester);
    });

    testWidgets('tek parmak kaydirma listeyi kaydirir, zoom tetiklemez', (tester) async {
      useScreen(tester, const Size(390, 844));
      await tester.pumpWidget(list());
      final c = tester.getCenter(find.byKey(boxKey));
      final g = await tester.startGesture(c);
      await g.moveBy(const Offset(0, -80));
      await tester.pump(const Duration(milliseconds: 16));
      await g.moveBy(const Offset(0, -80));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byKey(_layer), findsNothing);
      await g.up();
      await tester.pumpAndSettle();
      expect(sc.offset, greaterThan(50));
      expect(find.byKey(_layer), findsNothing);
      noErr(tester);
    });

    testWidgets('cift dokunus hala begeni (kalp patlamasi), tek dokunus yalniz onTap', (tester) async {
      useScreen(tester, const Size(390, 844));
      await tester.pumpWidget(list());
      final c = tester.getCenter(find.byKey(boxKey));
      await tester.tapAt(c);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(c);
      await tester.pump(const Duration(milliseconds: 100));
      expect(likes, 1);
      expect(find.byKey(const ValueKey('double-tap-heart')), findsOneWidget);
      expect(find.byKey(_layer), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      await tester.tapAt(c);
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps, 1);
      expect(likes, 1);
      noErr(tester);
    });

    testWidgets('bir parmak basili, ikincisi sonradan inince de pinch calisir; biri kalkinca biter', (tester) async {
      useScreen(tester, const Size(390, 844));
      await tester.pumpWidget(list());
      final c = tester.getCenter(find.byKey(boxKey));
      final a = await tester.startGesture(c - const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byKey(_layer), findsNothing);
      final b = await tester.startGesture(c + const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await b.moveTo(c + const Offset(90, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byKey(_layer), findsOneWidget);
      expect(_layerScale(tester), greaterThan(1.5));
      await b.up();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(); // kaldirilan katman bir sonraki karede ciziminden duser
      expect(find.byKey(_layer), findsNothing);
      await a.up();
      await tester.pump(const Duration(seconds: 1));
      expect(likes, 0);
      noErr(tester);
    });

    testWidgets('hareket azaltilmis: parmak kalkinca kopya aninda kalkar', (tester) async {
      useScreen(tester, const Size(390, 844));
      await tester.pumpWidget(list(reduce: true));
      final c = tester.getCenter(find.byKey(boxKey));
      final g = await _pinch(tester, c);
      expect(find.byKey(_layer), findsOneWidget);
      await _release(tester, g);
      await tester.pump();
      expect(find.byKey(_layer), findsNothing);
      noErr(tester);
    });

    testWidgets('video yolu: kopya cocugun anlik goruntusudur (RawImage)', (tester) async {
      useScreen(tester, const Size(390, 844));
      await tester.pumpWidget(list(snapshot: true));
      final c = tester.getCenter(find.byKey(boxKey));
      final g = await _pinch(tester, c);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(RawImage), findsOneWidget);
      await _release(tester, g);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(); // kaldirilan katman bir sonraki karede ciziminden duser
      expect(find.byType(RawImage), findsNothing);
      noErr(tester);
    });

    testWidgets('carousel: tek parmak yatay kaydirma sayfa degistirir; iki parmak degistirmez', (tester) async {
      useScreen(tester, const Size(390, 844));
      final pc = PageController();
      await tester.pumpWidget(buildApp(Scaffold(
        body: SizedBox(
          height: 400,
          child: PageView(controller: pc, children: [
            for (var i = 0; i < 3; i++)
              PinchZoomable(
                overlayBuilder: (_) => const ColoredBox(key: _layer, color: Colors.red),
                child: ColoredBox(key: ValueKey('page$i'), color: Colors.primaries[i]),
              ),
          ]),
        ),
      )));
      final c = tester.getCenter(find.byKey(const ValueKey('page0')));
      final g = await _pinch(tester, c, from: 40, to: 100);
      expect(find.byKey(_layer), findsOneWidget);
      await g.$1.moveBy(const Offset(-120, 0));
      await g.$2.moveBy(const Offset(-120, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await _release(tester, g);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(); // kaldirilan katman bir sonraki karede ciziminden duser
      expect(pc.page, 0);
      await tester.fling(find.byKey(const ValueKey('page0')), const Offset(-300, 0), 1200);
      await tester.pumpAndSettle();
      expect(pc.page, 1);
      expect(find.byKey(_layer), findsNothing);
      noErr(tester);
    });
  });

  group('PostCard (gonderi detayi)', () {
    Post photoPost() => Post.fromJson(samplePost(id: 1000, media: [samplePostMedia(id: 7)], text: 'Bahar geldi', likeCount: 3));

    Future<FakeBackend> open(WidgetTester tester, Size size, {Brightness brightness = Brightness.light, double textScale = 1}) async {
      useScreen(tester, size);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(
        Scaffold(
          body: ListView(children: [
            PostCard(session: makeSession(b), post: photoPost(), detail: true, onChanged: (_) {}, onDeleted: (_) {}),
          ]),
        ),
        brightness: brightness,
      ));
      await settle(tester, const Duration(milliseconds: 400));
      return b;
    }

    for (final v in <(String, Size, Brightness, double)>[
      ('390 acik', const Size(390, 844), Brightness.light, 1.0),
      ('320 koyu x1.3', const Size(320, 640), Brightness.dark, 1.3),
    ]) {
      testWidgets('gonderi fotografi iki parmakla yakinlasir (${v.$1}); tek dokunus tam ekran acmaz; cift dokunus begenir', (tester) async {
        final b = await open(tester, v.$2, brightness: v.$3, textScale: v.$4);
        final photo = find.byKey(const ValueKey('post-photo-1000'));
        expect(photo, findsOneWidget);
        final c = tester.getCenter(photo);
        final sem = tester.ensureSemantics();
        final label = tester.element(find.byType(PostCard)).l10n.postComposePhoto;

        // Tek dokunus: tam ekran yok, kopya yok.
        await tester.tapAt(c);
        await settle(tester, const Duration(milliseconds: 500));
        expect(find.byType(PostPhotoViewer), findsNothing);
        expect(find.byKey(const ValueKey('zoom-post-photo-1000')), findsNothing);

        // Iki parmak: kopya kok katmanda, kart ve kopya anahtarlari ayri, ekran okuyucu etiketi tek.
        final g = await _pinch(tester, c, from: 25, to: 70);
        expect(find.byKey(const ValueKey('zoom-post-photo-1000')), findsOneWidget);
        expect(find.byKey(const ValueKey('zoom-hires-1000')), findsOneWidget);
        expect(photo, findsOneWidget);
        expect(tester.getSemantics(photo).label, contains(label));
        expect(find.byKey(const ValueKey('double-tap-heart')), findsNothing);
        await _release(tester, g);
        await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(); // kaldirilan katman bir sonraki karede ciziminden duser
        expect(find.byKey(const ValueKey('zoom-post-photo-1000')), findsNothing);
        expect(b.requests.where((r) => r.contains('/like')), isEmpty);

        // Cift dokunus: kirmizi kalp + begeni istegi.
        await tester.tapAt(c);
        await tester.pump(const Duration(milliseconds: 60));
        await tester.tapAt(c);
        await tester.pump(const Duration(milliseconds: 120));
        expect(find.byKey(const ValueKey('double-tap-heart')), findsOneWidget);
        await settle(tester, const Duration(milliseconds: 900));
        expect(b.requests.where((r) => r.contains('/like')).length, 1, reason: b.requests.join('|'));
        sem.dispose();
        noErr(tester);
      });
    }
  });
}
