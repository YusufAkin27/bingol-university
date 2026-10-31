import 'package:bu_kampus/core/theme/bu_sizes.dart';
import 'package:bu_kampus/features/auth/widgets/auth_ref.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'redesign/p00_support.dart';

/// SIZE-FIX: temel öğe boyutları Stitch oranına (48 dp düğme, 52 dp alan, 34 dp çip, 40 dp simge düğmesi, 64 dp gezinme)
/// indirildi; dokunma alanı her yerde >= 48 dp kalır. Redmi 13C eşdeğeri 360x800, Pixel 6 eşdeğeri 411x891.
void main() {
  Future<void> size(WidgetTester t, double w, double h) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = Size(w, h);
    addTearDown(t.view.reset);
  }

  test('BuSize sabitleri tek tabloda ve tutarlı', () {
    expect(BuSize.button, 48);
    expect(BuSize.buttonCompact, lessThan(BuSize.touch));
    expect(BuSize.chip, lessThan(BuSize.touch));
    expect(BuSize.iconBtn, lessThan(BuSize.touch));
    expect(BuSize.field, greaterThanOrEqualTo(BuSize.touch));
    expect(BuSize.nav, 64);
    expect(BuSize.navInset, BuSize.nav + 2 * BuSize.navGap);
    expect(kNavInset, BuSize.navInset);
  });

  for (final w in [360.0, 411.0]) {
    group('boyutlar @${w.toInt()} dp', () {
      testWidgets('BuButton tam genişlik 48 dp, kompakt görünür 34 dp (hit >= 48)', (t) async {
        await size(t, w, 800);
        await t.pumpWidget(p00App(Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            BuButton(label: 'Giriş yap', onPressed: () {}),
            const SizedBox(height: 12),
            Row(children: [BuButton(key: const ValueKey('c'), label: 'Katıl', compact: true, onPressed: () {})]),
          ]),
        )));
        await t.pump(const Duration(milliseconds: 200));
        final full = t.getSize(find.byType(BuButton).first);
        expect(full.height, closeTo(BuSize.button, .6));
        // Kompakt: dış hit alanı >= 48, içindeki Material (görünür hap) 34.
        final hit = t.getSize(find.byKey(const ValueKey('c')));
        expect(hit.height, greaterThanOrEqualTo(48));
        final visible = t.getSize(find.descendant(of: find.byKey(const ValueKey('c')), matching: find.byType(Material)).first);
        expect(visible.height, closeTo(BuSize.buttonCompact, .6));
      });

      testWidgets('RefButton 48 dp, RefTextField 52 dp (iç etiketsiz)', (t) async {
        await size(t, w, 800);
        final c = TextEditingController();
        await t.pumpWidget(p00App(Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            RefTextField(key: const ValueKey('f'), controller: c, label: 'E-posta'),
            const SizedBox(height: 12),
            RefButton(label: 'Devam', onPressed: () {}),
          ]),
        )));
        await t.pump(const Duration(milliseconds: 200));
        expect(t.getSize(find.byType(RefButton)).height, closeTo(BuSize.button, 1.2));
        // Alan kutusu: etiket (üstte) hariç, çerçeveli kapsayıcı 52 dp.
        final all = find.descendant(of: find.byKey(const ValueKey('f')), matching: find.byType(AnimatedContainer));
        final sizes = [for (var i = 0; i < all.evaluate().length; i++) t.getSize(all.at(i)).height];
        expect(sizes.first, closeTo(BuSize.field, 1.5), reason: '$sizes');
      });

      testWidgets('BuChip görünür <= 36 dp, hit 48 dp; BuIconButton görünür 40 dp; BuSegmented 48 dp', (t) async {
        await size(t, w, 800);
        await t.pumpWidget(p00App(Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Row(children: [BuChip(key: const ValueKey('chip'), label: 'Tümü', selected: true, onTap: () {})]),
            Row(children: [BuIconButton(key: const ValueKey('ib'), icon: LucideIcons.heart, onTap: () {}, tooltip: 'Beğen')]),
            BuSegmented(items: const ['Keşfet', 'Kulüplerim'], index: 0, onChanged: (_) {}),
          ]),
        )));
        await t.pump(const Duration(milliseconds: 200));
        expect(t.getSize(find.byKey(const ValueKey('chip'))).height, greaterThanOrEqualTo(48));
        final chipVisible = t.getSize(find.descendant(of: find.byKey(const ValueKey('chip')), matching: find.byType(AnimatedContainer)).first);
        expect(chipVisible.height, lessThanOrEqualTo(36));
        expect(chipVisible.height, greaterThanOrEqualTo(32));
        expect(t.getSize(find.byKey(const ValueKey('ib'))).height, greaterThanOrEqualTo(48));
        final ibVisible = t.getSize(find.descendant(of: find.byKey(const ValueKey('ib')), matching: find.byType(Material)).first);
        expect(ibVisible.height, BuSize.iconBtn);
        expect(t.getSize(find.byType(BuSegmented)).height, closeTo(48, 1));
      });

      testWidgets('dokunma hedefi kılavuzu (>= 48 dp) küçülen öğelerde korunur', (t) async {
        await size(t, w, 800);
        final h = t.ensureSemantics();
        await t.pumpWidget(p00App(Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            BuButton(label: 'Tam genişlik', onPressed: () {}),
            Row(children: [
              BuButton(label: 'Kompakt', compact: true, onPressed: () {}),
              BuIconButton(icon: LucideIcons.heart, onTap: () {}, tooltip: 'Beğen'),
              BuChip(label: 'Haber', onTap: () {}),
            ]),
            BuSegmented(items: const ['Keşfet', 'Kulüplerim'], index: 0, onChanged: (_) {}),
            RefButton(label: 'Devam', onPressed: () {}),
          ]),
        )));
        await t.pump(const Duration(milliseconds: 200));
        await expectLater(t, meetsGuideline(androidTapTargetGuideline));
        await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
        h.dispose();
      });
    });
  }

  testWidgets('küçülen öğeler 1.3x yazı ve 320/360/411 dp, 3 dil, 2 temada taşmaz', (t) async {
    final c = TextEditingController();
    await p00Matrix(
      t,
      () => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          BuButton(label: 'Devam et uzun bir etiket metni burada', icon: LucideIcons.arrowRight, onPressed: () {}),
          const SizedBox(height: 8),
          RefButton(label: 'Devam et uzun bir etiket metni burada', icon: LucideIcons.arrowRight, onPressed: () {}),
          const SizedBox(height: 8),
          RefTextField(controller: c, label: 'E-posta', hint: 'ad.soyad@bingol.edu.tr'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [for (final s in ['Tümü', 'Teknoloji', 'Spor', 'Sanat']) BuChip(label: s, onTap: () {})]),
          const SizedBox(height: 8),
          BuSegmented(items: const ['Keşfet', 'Kulüplerim'], index: 1, onChanged: (_) {}),
          const SizedBox(height: 8),
          const BuSearchField(),
        ]),
      ),
      widths: const [320, 360, 411],
    );
  });
}
