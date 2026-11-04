import 'package:bu_kampus/widgets/bu_widgets.dart';
import 'package:bu_kampus/widgets/profile_photo_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'support/fake_media.dart';

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split('\n').take(20).join('\n')}');
}

const _vBlur = ValueKey('profilePhotoViewerBlur');
const _vBackdrop = ValueKey('profilePhotoViewerBackdrop');
const _vClose = ValueKey('profilePhotoViewerClose');
const _vImage = ValueKey('profilePhotoViewerImage');

/// Bir düğme + bir avatar içeren deneme ekranı.
Widget host({
  String? url = '/files/avatars/a.jpg',
  VoidCallback? onTap,
  String? title,
  String? heroTag,
}) =>
    Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Builder(
            builder: (context) => TextButton(
              key: const ValueKey('open'),
              onPressed: () => ProfilePhotoViewer.show(context, imageUrl: url, title: title, heroTag: heroTag),
              child: const Text('ac'),
            ),
          ),
          AvatarLongPress(
            key: const ValueKey('avatar'),
            imageUrl: url,
            title: title,
            heroTag: heroTag,
            onTap: onTap,
            child: const BuAvatar(name: 'Ayşe Yılmaz', size: 48),
          ),
        ]),
      ),
    );

void main() {
  setUpAll(loadTestFonts);

  setUp(() {
    ProfilePhotoViewer.providerOverride = (_, __, ___) => MemoryImage(fakePng);
  });
  tearDown(() => ProfilePhotoViewer.providerOverride = null);

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('fotograf yoksa (null/bos) hicbir sey acilmaz', (tester) async {
    useScreen(tester, const Size(390, 844));
    await tester.pumpWidget(buildApp(host(url: null)));
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(_vBlur), findsNothing);
    await tester.pumpWidget(buildApp(host(url: '')));
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(_vBlur), findsNothing);
    noErr(tester);
  });

  testWidgets('aciliyor: blur + gorsel + X; X kapatir', (tester) async {
    useScreen(tester, const Size(390, 844));
    await tester.pumpWidget(buildApp(host(title: 'Ayşe Yılmaz')));
    await open(tester);
    expect(find.byKey(_vBlur), findsOneWidget);
    expect(find.byKey(_vImage), findsOneWidget);
    expect(find.text('Ayşe Yılmaz'), findsWidgets);
    // Gorsel kutusu ekran icinde, 1:1 oran.
    final box = tester.getSize(find.byKey(const ValueKey('profilePhotoViewerBox')));
    expect(box.width, lessThanOrEqualTo(390 - 32 + .01));
    expect((box.width / box.height - 1).abs(), lessThan(.02));
    await tester.tap(find.byKey(_vClose));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(_vBlur), findsNothing);
    noErr(tester);
  });

  testWidgets('disina dokunma kapatir; fotografa dokunma kapatmaz', (tester) async {
    useScreen(tester, const Size(390, 844));
    await tester.pumpWidget(buildApp(host()));
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('profilePhotoViewerBox')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(_vBlur), findsOneWidget);
    await tester.tapAt(const Offset(8, 500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(_vBlur), findsNothing);
    noErr(tester);
  });

  testWidgets('geri tusu (maybePop) kapatir', (tester) async {
    useScreen(tester, const Size(390, 844));
    await tester.pumpWidget(buildApp(host()));
    await open(tester);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    await nav.maybePop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(_vBlur), findsNothing);
    noErr(tester);
  });

  testWidgets('asagi surukleme kapatir', (tester) async {
    useScreen(tester, const Size(390, 844));
    await tester.pumpWidget(buildApp(host()));
    await open(tester);
    await tester.drag(find.byKey(const ValueKey('profilePhotoViewerBox')), const Offset(0, 260));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(_vBlur), findsNothing);
    noErr(tester);
  });

  testWidgets('AvatarLongPress: dokunma onTap, uzun basma onizleme', (tester) async {
    useScreen(tester, const Size(390, 844));
    var taps = 0;
    await tester.pumpWidget(buildApp(host(onTap: () => taps++)));
    await tester.tap(find.byKey(const ValueKey('avatar')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(taps, 1);
    expect(find.byKey(_vBlur), findsNothing);
    await tester.longPress(find.byKey(const ValueKey('avatar')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(taps, 1);
    expect(find.byKey(_vBlur), findsOneWidget);
    noErr(tester);
  });

  testWidgets('AvatarLongPress: fotograf yoksa uzun basma bir sey acmaz, onTap calisir', (tester) async {
    useScreen(tester, const Size(390, 844));
    var taps = 0;
    await tester.pumpWidget(buildApp(host(url: null, onTap: () => taps++)));
    await tester.longPress(find.byKey(const ValueKey('avatar')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(_vBlur), findsNothing);
    // Uzun tutma da (Flutter'da sure siniri yok) dokunma sayilir; onemli olan onizlemenin acilmamasi.
    final before = taps;
    await tester.tap(find.byKey(const ValueKey('avatar')));
    expect(taps, before + 1);
    noErr(tester);
  });

  testWidgets('onTap verilmezse dokunma ustteki satira duser', (tester) async {
    useScreen(tester, const Size(390, 844));
    var rowTaps = 0;
    await tester.pumpWidget(buildApp(Scaffold(
      body: InkWell(
        key: const ValueKey('row'),
        onTap: () => rowTaps++,
        child: const SizedBox(
          height: 80,
          child: AvatarLongPress(
              key: ValueKey('avatar'), imageUrl: '/files/a.jpg', child: BuAvatar(name: 'A', size: 48)),
        ),
      ),
    )));
    await tester.tap(find.byKey(const ValueKey('avatar')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(rowTaps, 1);
    await tester.longPress(find.byKey(const ValueKey('avatar')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(_vBlur), findsOneWidget);
    expect(rowTaps, 1);
    noErr(tester);
  });

  for (final size in [const Size(320, 640), const Size(390, 844)]) {
    for (final dark in [false, true]) {
      testWidgets('tasma yok ${size.width.toInt()} dp ${dark ? 'koyu' : 'acik'} + RTL', (tester) async {
        useScreen(tester, size);
        await tester.pumpWidget(buildApp(
          Directionality(textDirection: TextDirection.rtl, child: host(title: 'عائشة يلماز ' * 6)),
          brightness: dark ? Brightness.dark : Brightness.light,
        ));
        await open(tester);
        expect(find.byKey(_vBlur), findsOneWidget);
        expect(find.byKey(_vBackdrop), findsOneWidget);
        noErr(tester);
      });
    }
  }

  testWidgets('animasyonlari azalt: aninda acilir', (tester) async {
    useScreen(tester, const Size(390, 844));
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(size: Size(390, 844), disableAnimations: true),
      child: buildApp(host()),
    ));
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byKey(_vBlur), findsOneWidget);
    noErr(tester);
  });
}
