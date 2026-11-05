import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/cache/image_disk_cache.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/widgets/bu_default_avatar.dart';
import 'package:bu_kampus/widgets/bu_widgets.dart';

Widget host(Widget child) =>
    MaterialApp(theme: BuTheme.light(), home: Scaffold(body: Center(child: child)));

void main() {
  test('initialsOf', () {
    expect(initialsOf('Ayşe Yılmaz'), 'AY');
    expect(initialsOf('  ali  '), 'A');
    expect(initialsOf('a b c'), 'AB');
    expect(initialsOf(''), '?');
    expect(initialsOf(null), '?');
  });

  test('fileUrl', () {
    expect(fileUrl(null), isNull);
    expect(fileUrl(''), isNull);
    expect(fileUrl('/files/a.png'), '$apiOrigin/files/a.png');
    expect(fileUrl('https://x.com/a.png'), 'https://x.com/a.png');
  });

  testWidgets('BuSegmented seçim değişince callback çağrılır', (tester) async {
    int? picked;
    await tester.pumpWidget(
        host(BuSegmented(items: const ['Bir', 'İki', 'Üç'], index: 0, onChanged: (i) => picked = i)));
    await tester.tap(find.text('İki'));
    expect(picked, 1);
    await tester.tap(find.text('Üç'));
    expect(picked, 2);
  });

  testWidgets('BuChip etiketi gösterir ve dokunulabilir', (tester) async {
    var n = 0;
    await tester.pumpWidget(host(BuChip(label: 'Haber', selected: true, onTap: () => n++)));
    expect(find.text('Haber'), findsOneWidget);
    await tester.tap(find.text('Haber'));
    expect(n, 1);
  });

  testWidgets('BuBadge metni gösterir', (tester) async {
    await tester.pumpWidget(host(const BuBadge('Yeni', soft: true)));
    expect(find.text('Yeni'), findsOneWidget);
  });

  testWidgets('BuButton tıklanınca çağrılır; busy iken çağrılmaz', (tester) async {
    var n = 0;
    await tester.pumpWidget(host(BuButton(label: 'Gönder', onPressed: () => n++)));
    await tester.tap(find.text('Gönder'));
    expect(n, 1);

    await tester.pumpWidget(host(BuButton(label: 'Gönder', busy: true, onPressed: () => n++)));
    // M0: etiket -> çember geçişi 150 ms yumuşak (giden etiket solarak çıkar).
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Gönder'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(BuButton));
    expect(n, 1);
  });

  /// Ağaçtaki varlık görsellerinin adları ([Image.asset] `cacheWidth` ile `ResizeImage` sarar).
  List<String> assetNames(WidgetTester tester) => [
        for (final img in tester.widgetList<Image>(find.byType(Image)))
          if (_assetOf(img.image) case final a?) a
      ];

  testWidgets('BuAvatar url yoksa varsayılan görseli gösterir (baş harf yok, ağ görseli yok)', (tester) async {
    await tester.pumpWidget(host(const BuAvatar(name: 'Ayşe Yılmaz')));
    expect(find.text('AY'), findsNothing);
    expect(find.byType(Text), findsNothing);
    expect(find.byType(BuDefaultAvatar), findsOneWidget);
    expect(tester.widget<BuDefaultAvatar>(find.byType(BuDefaultAvatar)).group, isFalse);
    expect(assetNames(tester), [BuDefaultAvatar.personAsset]);
  });

  testWidgets('BuAvatar boş url de varsayılan görsel', (tester) async {
    await tester.pumpWidget(host(const BuAvatar(name: 'Ayşe', url: '')));
    expect(assetNames(tester), [BuDefaultAvatar.personAsset]);
  });

  testWidgets('BuAvatar group: varsayılan grup görseli', (tester) async {
    await tester.pumpWidget(host(const BuAvatar(name: 'Grup', group: true)));
    expect(tester.widget<BuDefaultAvatar>(find.byType(BuDefaultAvatar)).group, isTrue);
    expect(assetNames(tester), [BuDefaultAvatar.groupAsset]);
  });

  testWidgets('BuAvatar geçerli url: ağ görseli çizilir, varsayılan görsel yüklenirken altta durur', (tester) async {
    await tester.pumpWidget(host(const BuAvatar(name: 'Ayşe', url: 'https://example.com/a.jpg', size: 40)));
    final nets = tester.widgetList<Image>(find.byType(Image)).where((i) => _assetOf(i.image) == null).toList();
    expect(nets, hasLength(1));
    var p = nets.single.image;
    if (p is ResizeImage) p = p.imageProvider;
    expect(p, isA<DiskNetworkImage>().having((d) => d.url, 'url', 'https://example.com/a.jpg'));
    // Yüklenirken (ve hata verirse) altta varsayılan görsel var.
    expect(assetNames(tester), [BuDefaultAvatar.personAsset]);
  });

  testWidgets('BuAvatar fotoğraf yüklenemezse varsayılan görsel kalır', (tester) async {
    await tester.pumpWidget(host(const BuAvatar(name: 'Ayşe', url: '/files/yok.jpg', size: 40)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(BuDefaultAvatar), findsOneWidget);
    expect(find.byType(Text), findsNothing);
    expect(assetNames(tester), contains(BuDefaultAvatar.personAsset));
  });

  testWidgets('BuAvatar şekil: yuvarlak, yuvarlatılmış kare ve sabit köşe korunur', (tester) async {
    double r(WidgetTester t) => t.widget<ClipRRect>(find.byType(ClipRRect).first).borderRadius.resolve(TextDirection.ltr).topLeft.x;
    await tester.pumpWidget(host(const BuAvatar(size: 40)));
    expect(r(tester), 40);
    await tester.pumpWidget(host(const BuAvatar(size: 40, square: true)));
    expect(r(tester), closeTo(13.6, .01));
    await tester.pumpWidget(host(const BuAvatar(size: 52, radius: 20)));
    expect(r(tester), 20);
  });

  testWidgets('BuDefaultAvatar çözümleme boyutu size x dpr ile sınırlı, anlamsal düğüm yok, 24-96 dp taşmaz', (tester) async {
    final h = tester.ensureSemantics();
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host(Row(children: [
      for (final s in [24.0, 36.0, 44.0, 96.0]) BuDefaultAvatar(size: s),
    ])));
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel(RegExp('.')), findsNothing);
    final widths = [
      for (final img in tester.widgetList<Image>(find.byType(Image))) (img.image as ResizeImage).width,
    ];
    expect(widths, [48, 72, 88, 192]);
    h.dispose();
  });
}

String? _assetOf(ImageProvider p) {
  if (p is ResizeImage) p = p.imageProvider;
  return p is AssetImage ? p.assetName : null;
}
