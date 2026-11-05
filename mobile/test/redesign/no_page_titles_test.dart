import 'package:bu_kampus/features/academic/academic_widgets.dart';
import 'package:bu_kampus/features/profile/profil_widgets.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'p00_support.dart';

/// Tasarım sadeleştirmesi: ekranın genel adı (Ayarlar, Gönderi, Keşfet...) görünmez; geri oku ve eylem düğmeleri
/// yerinde, üst çubuk tek satır kalır; başlık yalnız ekran okuyucu için anlamsal etiket olarak taşınır.
void main() {
  testWidgets('BuHeader: başlık metni çizilmez, geri oku + eylem aynı hizada, anlamsal başlık korunur', (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(p00App(
      Column(children: [
        BuHeader(
          title: 'Ayarlar',
          onBack: () {},
          actions: [BuIconButton(key: const ValueKey('act'), icon: BuIcons.search, tooltip: 'Ara', onTap: () {})],
        ),
      ]),
    ));
    expect(find.text('Ayarlar'), findsNothing);
    expect(find.byTooltip('Geri'), findsOneWidget);
    expect(find.byKey(const ValueKey('act')), findsOneWidget);
    expect(find.bySemanticsLabel('Ayarlar'), findsOneWidget);
    final back = t.getCenter(find.byTooltip('Geri'));
    final act = t.getCenter(find.byKey(const ValueKey('act')));
    expect((back.dy - act.dy).abs(), lessThan(1), reason: 'geri oku ve eylem aynı satırda');
    // Tek satır: durum çubuğu payı + 8 + 48 dp düğme + 4 dp (büyük başlık yüksekliği yok).
    expect(t.getSize(find.byType(BuHeader)).height, lessThanOrEqualTo(8 + 48 + 4));
    h.dispose();
  });

  testWidgets('BuHeader: visibleTitle true belge adı gibi içerik başlıklarını çizer', (t) async {
    await t.pumpWidget(p00App(BuHeader(title: 'Kullanıcı Sözleşmesi', visibleTitle: true, onBack: () {})));
    expect(find.text('Kullanıcı Sözleşmesi'), findsOneWidget);
  });

  testWidgets('BuHeader: geri ve eylem yoksa çubuk boşluk kaplamaz (yalnız güvenli alan payı)', (t) async {
    await t.pumpWidget(p00App(const BuHeader(title: 'Bildirimler')));
    expect(find.text('Bildirimler'), findsNothing);
    expect(t.getSize(find.byType(BuHeader)).height, lessThanOrEqualTo(8));
  });

  testWidgets('ProfilTopBar: başlık yok, geri oku var, ekran okuyucuda başlık etiketi var', (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(p00App(Column(children: [ProfilTopBar(title: 'Engellenenler', onBack: () {})])));
    expect(find.text('Engellenenler'), findsNothing);
    expect(find.byTooltip('Geri'), findsOneWidget);
    expect(find.bySemanticsLabel('Engellenenler'), findsOneWidget);
    h.dispose();
  });

  testWidgets('AcademicScaffold: başlık metni yok, eylemler ve içerik kalır', (t) async {
    await t.pumpWidget(p00App(
      AcademicScaffold(title: 'Ders programı', actions: [BuIconButton(icon: BuIcons.plus, tooltip: 'Ekle', onTap: () {})], child: const Text('içerik')),
      scaffold: false,
    ));
    expect(find.text('Ders programı'), findsNothing);
    expect(find.text('içerik'), findsOneWidget);
    expect(find.byTooltip('Ekle'), findsOneWidget);
    expect(find.byTooltip('Geri'), findsOneWidget);
  });

  testWidgets('BuPageScaffold: büyük başlık yok, 56 dp tek satır çubuk; eylem ve içerik kalır; 3 dil taşmaz', (t) async {
    final h = t.ensureSemantics();
    await p00Matrix(
      t,
      () => BuPageScaffold(
        title: 'Beğendiklerim',
        leading: BackButton(onPressed: () {}),
        actions: [BuIconButton(icon: BuIcons.search, tooltip: 'Ara', onTap: () {})],
        slivers: const [SliverToBoxAdapter(child: Text('içerik'))],
      ),
      scaffold: false,
      widths: const [320],
      check: (t, lang, dark, scale) async {
        expect(find.text('Beğendiklerim'), findsNothing);
        expect(find.text('içerik'), findsOneWidget);
        expect(find.byTooltip('Ara'), findsOneWidget);
        final bar = t.getSize(find.byType(AppBar).first);
        expect(bar.height, lessThanOrEqualTo(kToolbarHeight + 1), reason: 'SliverAppBar.large boş alanı kalmamalı');
      },
    );
    h.dispose();
  });
}
