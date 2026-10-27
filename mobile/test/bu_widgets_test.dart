import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/theme.dart';
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
    expect(find.text('Gönder'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(BuButton));
    expect(n, 1);
  });

  testWidgets('BuAvatar görselsiz varsayılan görseli gösterir', (tester) async {
    await tester.pumpWidget(host(const BuAvatar(name: 'Ayşe Yılmaz')));
    expect(find.text('AY'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    final img = tester.widget<Image>(find.byType(Image));
    expect((img.image as AssetImage).assetName, 'assets/branding/default_avatar.png');
  });

  testWidgets('BuAvatar group: varsayılan grup görseli', (tester) async {
    await tester.pumpWidget(host(const BuAvatar(name: 'Grup', group: true)));
    final img = tester.widget<Image>(find.byType(Image));
    expect((img.image as AssetImage).assetName, 'assets/branding/default_group.png');
  });
}
