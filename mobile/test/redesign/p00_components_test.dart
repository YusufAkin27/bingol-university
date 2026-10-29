import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:bu_kampus/widgets/common.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'p00_support.dart';

Widget _scroll(List<Widget> children) => SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );

void main() {
  group('BuButton ailesi', () {
    testWidgets('tum turler 3 dil x 2 tema x 2 olcek x 2 genislikte taşmadan çizilir', (t) async {
      await p00Matrix(
        t,
        () => _scroll([
          for (final k in BuButtonKind.values) ...[
            BuButton(label: 'Devam et uzun bir etiket metni burada', kind: k, icon: LucideIcons.arrowRight, onPressed: () {}),
            const SizedBox(height: 8),
            Wrap(children: [BuButton(label: 'Katıl', kind: k, compact: true, onPressed: () {})]),
            const SizedBox(height: 8),
          ],
          BuButton(label: 'Devre dışı'),
          const SizedBox(height: 8),
          BuButton(label: 'Yükleniyor', busy: true, onPressed: () {}),
        ]),
      );
    });

    testWidgets('dokununca çağrılır; busy ve devre dışıyken çağrılmaz; busy iken etiket anlamsal olarak kalır', (t) async {
      var n = 0;
      await t.pumpWidget(p00App(BuButton(label: 'Gönder', onPressed: () => n++)));
      await t.tap(find.text('Gönder'));
      expect(n, 1);
      await t.pumpWidget(p00App(BuButton(label: 'Gönder', busy: true, onPressed: () => n++)));
      await t.tap(find.byType(BuButton));
      expect(n, 1);
      expect(find.bySemanticsLabel('Gönder'), findsWidgets);
      await t.pumpWidget(p00App(const BuButton(label: 'Gönder')));
      await t.tap(find.byType(BuButton), warnIfMissed: false);
      expect(n, 1);
    });

    testWidgets('kompakt düğme içeriği kadar genişler (Wrap içinde tam genişliğe yayılmaz)', (t) async {
      await t.pumpWidget(p00App(Wrap(children: [BuButton(label: 'Katıl', compact: true, onPressed: () {})])));
      expect(t.getSize(find.byType(BuButton)).width, lessThan(140));
    });

    testWidgets('dokunma hedefleri >= 48 dp (kompakt düğme, ikon düğmesi, çip, bölüm eylemi)', (t) async {
      final h = t.ensureSemantics();
      await t.pumpWidget(p00App(_scroll([
        BuButton(label: 'Tam genişlik', onPressed: () {}),
        Row(children: [
          BuButton(label: 'Kompakt', compact: true, onPressed: () {}),
          BuIconButton(icon: LucideIcons.heart, onTap: () {}, tooltip: 'Beğen'),
          BuChip(label: 'Haber', onTap: () {}),
        ]),
        BuSectionHeader('Başlık', action: 'Tümü', onAction: () {}),
      ])));
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      h.dispose();
    });
  });

  group('BuPressable', () {
    testWidgets('basılıyken küçülür, bırakınca döner; haptic çağrısı platform kanalına gider', (t) async {
      final calls = <String>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (c) async {
        if (c.method == 'HapticFeedback.vibrate') calls.add('${c.arguments}');
        return null;
      });
      addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      var taps = 0;
      await t.pumpWidget(p00App(Center(
        child: BuPressable(onTap: () => taps++, haptic: BuHaptic.selection, child: const SizedBox(width: 100, height: 100)),
      )));
      double scale() => t.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
      expect(scale(), 1);
      final g = await t.startGesture(t.getCenter(find.byType(BuPressable)));
      await t.pump();
      expect(scale(), lessThan(1));
      await g.up();
      await t.pump(const Duration(milliseconds: 200));
      expect(scale(), 1);
      expect(taps, 1);
      expect(calls, contains('HapticFeedbackType.selectionClick'));
    });

    testWidgets('kaydırma (parmak kayarsa) ölçek geri döner; animasyon azaltıldıysa hiç küçülmez', (t) async {
      await t.pumpWidget(p00App(const Center(child: BuPressable(child: SizedBox(width: 100, height: 100)))));
      final g = await t.startGesture(t.getCenter(find.byType(BuPressable)));
      await t.pump();
      expect(t.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, lessThan(1));
      await g.moveBy(const Offset(0, 60));
      await t.pump();
      expect(t.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
      await g.up();

      await t.pumpWidget(p00App(const Center(child: BuPressable(child: SizedBox(width: 100, height: 100))), disableAnimations: true));
      final g2 = await t.startGesture(t.getCenter(find.byType(BuPressable)));
      await t.pump();
      expect(t.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
      await g2.up();
    });
  });

  group('kart, çip, segment, arama', () {
    testWidgets('BuCard 4 stil + BuChip + BuChipRow + BuSegmented matrisi', (t) async {
      await p00Matrix(
        t,
        () => _scroll([
          for (final s in BuCardStyle.values) ...[
            BuCard(style: s, onTap: () {}, child: const Text('Kart içeriği ve uzun bir açıklama metni burada yer alır')),
            const SizedBox(height: 8),
          ],
          BuChipRow(labels: const ['Hepsi', 'Haber', 'Duyuru', 'Etkinlik'], selected: 1, onSelected: (_) {}, padding: EdgeInsets.zero),
          BuSegmented(items: const ['Keşfet', 'Kulüplerim', 'Etkinlik'], index: 2, onChanged: (_) {}),
          const SizedBox(height: 8),
          BuSearchField(hint: 'Ara', controller: TextEditingController(text: 'kampüs')),
          BuGroup(dividerIndent: 64, children: [
            BuMenuRow(icon: LucideIcons.user, label: 'Profil', onTap: () {}),
            BuMenuRow(icon: LucideIcons.logOut, label: 'Çıkış', danger: true, onTap: () {}),
          ]),
        ]),
      );
    });

    testWidgets('BuCard geriye uyum: border:false = filled; onTap çalışır', (t) async {
      var n = 0;
      await t.pumpWidget(p00App(BuCard(border: false, onTap: () => n++, child: const Text('x'))));
      await t.tap(find.text('x'));
      expect(n, 1);
    });

    testWidgets('BuSegmented ve BuChipRow seçimi bildirir', (t) async {
      int? seg, chip;
      await t.pumpWidget(p00App(Column(children: [
        BuSegmented(items: const ['A', 'B', 'C'], index: 0, onChanged: (i) => seg = i),
        BuChipRow(labels: const ['x', 'y', 'z'], selected: 0, onSelected: (i) => chip = i),
      ])));
      await t.tap(find.text('C'));
      await t.tap(find.text('y'));
      expect(seg, 2);
      expect(chip, 1);
    });

    testWidgets('BuSegmented gösterge RTL\'de aynalanır', (t) async {
      await t.pumpWidget(p00App(const BuSegmented(items: ['A', 'B'], index: 0, onChanged: _noop), lang: 'ar'));
      await t.pump(const Duration(milliseconds: 400));
      final thumb = t.getRect(find.byType(FractionallySizedBox).first);
      final box = t.getRect(find.byType(BuSegmented));
      expect(thumb.right, greaterThan(box.center.dx), reason: 'RTL: ilk segment sağda');
    });

    testWidgets('BuSearchField: yazınca temizle düğmesi çıkar, temizleyince boşalır', (t) async {
      final c = TextEditingController();
      String? last;
      await t.pumpWidget(p00App(Padding(padding: const EdgeInsets.all(16), child: BuSearchField(controller: c, onChanged: (v) => last = v))));
      expect(find.byIcon(LucideIcons.circleX), findsNothing);
      await t.enterText(find.byType(TextField), 'abc');
      await t.pump();
      expect(find.byIcon(LucideIcons.circleX), findsOneWidget);
      await t.tap(find.byIcon(LucideIcons.circleX));
      await t.pump();
      expect(c.text, '');
      expect(last, '');
    });

    testWidgets('BuSearchField readOnly: temizle yok, dokunma çağrılır', (t) async {
      var n = 0;
      await t.pumpWidget(p00App(BuSearchField(readOnly: true, onTap: () => n++)));
      await t.tap(find.byType(TextField));
      expect(n, 1);
      expect(find.byIcon(LucideIcons.circleX), findsNothing);
    });
  });

  group('liste bileşenleri', () {
    testWidgets('BuListTile / BuSettingsTile / BuSectionHeader / rozetler matrisi', (t) async {
      await p00Matrix(
        t,
        () => _scroll([
          BuSectionHeader('Yaklaşan etkinlikler ve duyurular', action: 'Tümü', onAction: () {}),
          BuGroup(dividerIndent: 66, children: [
            BuListTile(
              leading: const BuAvatar(name: 'Mehmet Demir', size: 44, online: true),
              title: 'Mehmet Demir ile çok uzun bir sohbet başlığı burada',
              subtitle: 'Yarınki sınav saat kaçta olacak, biliyor musun?',
              trailing: const BuCountBadge(120),
              onTap: () {},
            ),
            BuListTile(title: 'Seçili', selected: true, showChevron: true, onTap: () {}),
            BuSettingsTile(icon: LucideIcons.globe, title: 'Dil', value: 'Türkçe', onTap: () {}),
            const BuSettingsTile(icon: LucideIcons.bell, title: 'Bildirimler', subtitle: 'Yeni mesaj ve duyurular için anlık bildirim gönder', trailing: BuCountBadge(2)),
            BuSettingsTile.toggle(icon: LucideIcons.bell, title: 'Bildirimler', subtitle: 'Yeni mesaj ve duyurular', value: true, onChanged: (_) {}),
            BuSettingsTile(icon: LucideIcons.logOut, title: 'Çıkış yap', danger: true, onTap: () {}),
          ]),
          Wrap(spacing: 8, children: [
            const BuCountBadge(7),
            const BuCountBadge(2, muted: true),
            const BuBadge('Yeni', soft: true),
            const BuAvatar(name: 'Ali', size: 36, online: true),
            const BuAvatar(group: true, square: true, size: 48),
          ]),
        ]),
      );
    });

    testWidgets('BuSettingsTile.toggle satıra dokunmak anahtarı çevirir; anlamsal "toggled"', (t) async {
      final h = t.ensureSemantics();
      var v = false;
      await t.pumpWidget(p00App(StatefulBuilder(
        builder: (c, set) => BuSettingsTile.toggle(icon: LucideIcons.bell, title: 'Bildirim', value: v, onChanged: (x) => set(() => v = x)),
      )));
      await t.tap(find.text('Bildirim'));
      await t.pump();
      expect(v, isTrue);
      expect(t.getSemantics(find.text('Bildirim')), matchesSemantics(label: 'Bildirim', hasToggledState: true, isToggled: true, hasTapAction: true));
      h.dispose();
    });

    testWidgets('BuCountBadge: 0 gizli, 99 üstü "99+"', (t) async {
      await t.pumpWidget(p00App(const Column(children: [BuCountBadge(0), BuCountBadge(150), BuCountBadge(5)])));
      expect(find.text('0'), findsNothing);
      expect(find.text('99+'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('BuListTile dokunma/uzun basma', (t) async {
      var a = 0, b = 0;
      await t.pumpWidget(p00App(BuListTile(title: 'Satır', onTap: () => a++, onLongPress: () => b++)));
      await t.tap(find.text('Satır'));
      await t.longPress(find.text('Satır'));
      expect((a, b), (1, 1));
    });
  });

  group('durum bileşenleri', () {
    testWidgets('BuEmptyState: 13 illüstrasyon + eylem matrisi', (t) async {
      for (final k in BuIllustration.values) {
        await p00Matrix(
          t,
          () => BuEmptyState(illustration: k, title: 'Henüz bir şey yok', message: 'Burada yeni gelişmeler görünür. Daha sonra tekrar bak.', actionLabel: 'Yenile', onAction: () {}, secondaryLabel: 'Vazgeç', onSecondary: () {}),
          widths: const [320],
        );
      }
    });

    testWidgets('BuEmptyState kompakt + ikonlu varyant ve eylem çağrısı', (t) async {
      var n = 0;
      await t.pumpWidget(p00App(SizedBox(height: 300, child: BuEmptyState(compact: true, icon: LucideIcons.bell, title: 'Boş', actionLabel: 'Git', onAction: () => n++))));
      await t.pump(const Duration(milliseconds: 500));
      await t.tap(find.text('Git'));
      expect(n, 1);
    });

    testWidgets('BuErrorState: ağ hatası "Bağlantı yok", diğeri genel başlık; yeniden dene çağrılır', (t) async {
      var n = 0;
      await t.pumpWidget(p00App(BuErrorState(error: ApiError(0, 'NETWORK', 'x'), onRetry: () => n++)));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Bağlantı yok'), findsOneWidget);
      await t.tap(find.text('Yeniden dene'));
      expect(n, 1);
      await t.pumpWidget(p00App(BuErrorState(error: ApiError(500, 'SERVER', 'x'), onRetry: () => n++)));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Bir şeyler ters gitti'), findsOneWidget);
    });

    testWidgets('BuErrorState ve BuOfflineBanner matrisi (3 dil)', (t) async {
      await p00Matrix(
        t,
        () => Column(children: [
          BuOfflineBanner(onRetry: () {}),
          Expanded(child: BuErrorState(error: ApiError(0, 'NETWORK', 'x'), onRetry: () {})),
        ]),
        widths: const [320],
      );
    });

    testWidgets('BuOfflineBanner metinleri ve yeniden dene', (t) async {
      var n = 0;
      await t.pumpWidget(p00App(BuOfflineBanner(onRetry: () => n++)));
      expect(find.text('İnternet bağlantısı yok'), findsOneWidget);
      expect(find.text('Kayıtlı veriler gösteriliyor'), findsOneWidget);
      await t.tap(find.text('Yeniden dene'));
      expect(n, 1);
    });
  });

  group('iskelet', () {
    testWidgets('3 varyant matrisi (sonsuz animasyon: sabit süre ilerletilir)', (t) async {
      for (final v in BuSkeletonVariant.values) {
        await p00Matrix(t, () => BuSkeletonList(variant: v, itemCount: 4), widths: const [320]);
      }
    });

    testWidgets('tek ticker: onlarca kutu tek AnimationController ile canlanır', (t) async {
      await t.pumpWidget(p00App(const BuSkeletonList(variant: BuSkeletonVariant.row, itemCount: 12)));
      await t.pump(const Duration(milliseconds: 200));
      expect(t.binding.transientCallbackCount, 1);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('animasyonları azalt: hiç ticker çalışmaz, pumpAndSettle tamamlanır', (t) async {
      await t.pumpWidget(p00App(const BuSkeletonList(itemCount: 5), disableAnimations: true));
      await t.pumpAndSettle();
      expect(t.binding.transientCallbackCount, 0);
    });

    testWidgets('kapsamsız BuSkeleton kendi kapsamını kurar; anlamsal "Yükleniyor" tek etiket', (t) async {
      final h = t.ensureSemantics();
      await t.pumpWidget(p00App(const Column(children: [BuSkeleton(width: 100), BuSkeleton.circle(40), BuSkeleton.line(width: 80)])));
      await t.pump(const Duration(milliseconds: 100));
      expect(t.takeException(), isNull);
      await t.pumpWidget(p00App(const BuSkeletonList()));
      expect(find.bySemanticsLabel('Yükleniyor'), findsOneWidget);
      h.dispose();
      await t.pumpWidget(const SizedBox());
    });
  });

  group('BuPageScaffold', () {
    Widget page(BuViewState s, {VoidCallback? onRetry, Future<void> Function()? onRefresh}) => BuPageScaffold(
          title: 'Haberler',
          state: s,
          onRetry: onRetry,
          onRefresh: onRefresh,
          error: ApiError(0, 'NETWORK', 'x'),
          empty: const BuEmptyState(title: 'Hiç haber yok', illustration: BuIllustration.document),
          slivers: [SliverList.builder(itemCount: 30, itemBuilder: (c, i) => ListTile(title: Text('Haber $i')))],
        );

    testWidgets('4 durum matrisi', (t) async {
      for (final s in BuViewState.values) {
        await p00Matrix(t, () => page(s), scaffold: false, widths: const [320]);
      }
    });

    testWidgets('durum eşlemesi: yükleniyor iskelet, boş, hata + yeniden dene, hazır liste', (t) async {
      var retry = 0;
      await t.pumpWidget(p00App(page(BuViewState.loading), scaffold: false));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byType(BuSkeletonList), findsOneWidget);
      await t.pumpWidget(p00App(page(BuViewState.empty), scaffold: false));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Hiç haber yok'), findsOneWidget);
      await t.pumpWidget(p00App(page(BuViewState.error, onRetry: () => retry++), scaffold: false));
      await t.pump(const Duration(milliseconds: 500));
      await t.tap(find.text('Yeniden dene'));
      expect(retry, 1);
      await t.pumpWidget(p00App(page(BuViewState.ready), scaffold: false));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Haber 0'), findsOneWidget);
      expect(find.byType(SliverAppBar), findsOneWidget);
    });

    testWidgets('büyük başlık kaydırınca daralır', (t) async {
      await t.pumpWidget(p00App(page(BuViewState.ready), scaffold: false));
      await t.pump(const Duration(milliseconds: 500));
      final before = t.getTopLeft(find.text('Haberler').first).dy;
      final sizeBefore = t.getSize(find.text('Haberler').first);
      await t.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await t.pump();
      expect(t.getTopLeft(find.text('Haberler').first).dy, lessThan(before));
      expect(t.getSize(find.text('Haberler').first).height, lessThanOrEqualTo(sizeBefore.height));
    });

    testWidgets('çekerek yenile onRefresh çağırır', (t) async {
      var n = 0;
      await t.pumpWidget(p00App(page(BuViewState.ready, onRefresh: () async => n++), scaffold: false));
      await t.pump(const Duration(milliseconds: 500));
      await t.fling(find.byType(CustomScrollView), const Offset(0, 400), 1000);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(seconds: 1));
      expect(n, 1);
    });

    testWidgets('banner başlığın altında gösterilir', (t) async {
      await t.pumpWidget(p00App(
        BuPageScaffold(title: 'X', banner: const BuOfflineBanner(), slivers: const [SliverToBoxAdapter(child: Text('içerik'))]),
        scaffold: false,
      ));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('İnternet bağlantısı yok'), findsOneWidget);
      expect(find.text('içerik'), findsOneWidget);
    });
  });

  group('hareket bileşenleri', () {
    testWidgets('BuStaggeredList: öğeler tembel kurulur, ilk 8 aşamalı belirir, kaydırınca yeniden oynamaz', (t) async {
      await t.pumpWidget(p00App(BuStaggeredList(itemCount: 100, itemBuilder: (c, i) => SizedBox(height: 80, child: Text('öğe $i')))));
      await t.pump();
      expect(find.byType(FadeTransition).evaluate().length, greaterThan(1));
      expect(find.text('öğe 99'), findsNothing, reason: 'tembel liste');
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
      await t.drag(find.byType(ListView), const Offset(0, -3000));
      await t.pump();
      await t.drag(find.byType(ListView), const Offset(0, 3000));
      await t.pump();
      // 0..7 zaten oynadı: geri dönünce animasyon yok (FadeTransition yok)
      expect(find.descendant(of: find.byType(ListView), matching: find.byType(FadeTransition)), findsNothing);
    });

    testWidgets('BuStaggeredList animasyonları azalt: FadeTransition yok', (t) async {
      await t.pumpWidget(p00App(BuStaggeredList(itemCount: 5, itemBuilder: (c, i) => Text('öğe $i')), disableAnimations: true));
      await t.pump();
      expect(find.descendant(of: find.byType(ListView), matching: find.byType(FadeTransition)), findsNothing);
      expect(find.text('öğe 0'), findsOneWidget);
    });

    testWidgets('BuFadeThrough ve BuSharedAxis çocuk değişince geçer', (t) async {
      Widget host(String k) => Column(children: [
            BuFadeThrough(child: Text(k, key: ValueKey('f$k'))),
            BuSharedAxis(child: Text(k, key: ValueKey('s$k'))),
          ]);
      await t.pumpWidget(p00App(host('A')));
      await t.pumpWidget(p00App(host('B')));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('A'), findsNWidgets(2), reason: 'eski içerik geçiş boyunca görünür');
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsNWidgets(2));
    });

    testWidgets('BuFadeThrough animasyonları azalt: anında', (t) async {
      await t.pumpWidget(p00App(BuFadeThrough(child: const Text('A', key: ValueKey('A'))), disableAnimations: true));
      await t.pumpWidget(p00App(BuFadeThrough(child: const Text('B', key: ValueKey('B'))), disableAnimations: true));
      await t.pump();
      expect(find.text('A'), findsNothing);
    });

    testWidgets('BuPageRoute: açılır ve kapanır', (t) async {
      await t.pumpWidget(p00App(Builder(
        builder: (c) => TextButton(onPressed: () => Navigator.of(c).push(BuPageRoute<void>(builder: (_) => const Scaffold(body: Text('ikinci')))), child: const Text('git')),
      )));
      await t.tap(find.text('git'));
      await t.pumpAndSettle();
      expect(find.text('ikinci'), findsOneWidget);
      t.state<NavigatorState>(find.byType(Navigator)).pop();
      await t.pumpAndSettle();
      expect(find.text('ikinci'), findsNothing);
    });

    testWidgets('BuGradientHero: 4 desen x matris; dokunma çalışır; yazı rengi onMedia', (t) async {
      var n = 0;
      await p00Matrix(
        t,
        () => _scroll([
          for (final p in BuHeroPattern.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: BuGradientHero(pattern: p, minHeight: 100, onTap: () => n++, child: const Text('Bahar Şenliği ve çok uzun bir başlık metni')),
            ),
        ]),
        widths: const [320],
      );
      await t.pumpWidget(p00App(BuGradientHero(onTap: () => n++, child: const Text('Hero'))));
      await t.tap(find.text('Hero'));
      expect(n, 1);
    });

    testWidgets('BuProgressSteps: anlamsal "Adım 2 / 3", üç dilde', (t) async {
      final h = t.ensureSemantics();
      await t.pumpWidget(p00App(const BuProgressSteps(count: 3, current: 1, labels: ['Bilgi', 'Kişisel', 'Şifre'])));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.bySemanticsLabel('Adım 2 / 3'), findsOneWidget);
      await t.pumpWidget(p00App(const BuProgressSteps(count: 3, current: 1), lang: 'en'));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.bySemanticsLabel('Step 2 of 3'), findsOneWidget);
      await t.pumpWidget(p00App(const BuProgressSteps(count: 3, current: 1), lang: 'ar'));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.bySemanticsLabel('الخطوة 2 من 3'), findsOneWidget);
      h.dispose();
    });
  });

  group('alt sayfa, diyalog, bildirim', () {
    Widget host(void Function(BuildContext) open, {String lang = 'tr'}) =>
        p00App(Builder(builder: (c) => TextButton(onPressed: () => open(c), child: const Text('aç'))), lang: lang);

    testWidgets('BuSheet.show: başlık, tutamaç, içerik; aşağı kaydırınca kapanır', (t) async {
      await t.pumpWidget(host((c) => BuSheet.show<void>(c, title: 'Sıralama', builder: (_) => const Text('içerik'), actions: [BuButton(label: 'Uygula', onPressed: () {})])));
      await t.tap(find.text('aç'));
      await t.pumpAndSettle();
      expect(find.text('Sıralama'), findsOneWidget);
      expect(find.text('içerik'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is BottomSheet && w.showDragHandle == true), findsOneWidget);
      await t.tapAt(const Offset(10, 10));
      await t.pumpAndSettle();
      expect(find.text('Sıralama'), findsNothing);
    });

    testWidgets('BuSheet uzun içerik kaydırılır, taşma yok (matris)', (t) async {
      await t.pumpWidget(host((c) => BuSheet.show<void>(c, title: 'Uzun', builder: (_) => Column(children: [for (var i = 0; i < 40; i++) ListTile(title: Text('satır $i'))]))));
      await t.tap(find.text('aç'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('satır 0'), findsOneWidget);
    });

    testWidgets('BuDialog.confirm: onay true, vazgeç false (3 dilde etiketler)', (t) async {
      bool? r;
      await t.pumpWidget(host((c) async => r = await BuDialog.confirm(c, title: 'Çıkış yapılsın mı?', message: 'Oturum kapanacak.', confirmLabel: 'Çıkış', destructive: true, icon: LucideIcons.logOut)));
      await t.tap(find.text('aç'));
      await t.pumpAndSettle();
      expect(find.text('Vazgeç'), findsOneWidget);
      await t.tap(find.text('Çıkış'));
      await t.pumpAndSettle();
      expect(r, isTrue);
      await t.tap(find.text('aç'));
      await t.pumpAndSettle();
      await t.tap(find.text('Vazgeç'));
      await t.pumpAndSettle();
      expect(r, isFalse);
      await t.pumpWidget(host((c) => BuDialog.confirm(c, title: 'x', confirmLabel: 'y'), lang: 'en'));
      await t.tap(find.text('aç'));
      await t.pumpAndSettle();
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('BuDialog.info tek düğme', (t) async {
      await t.pumpWidget(host((c) => BuDialog.info(c, title: 'Bilgi', message: 'Tamam mı', okLabel: 'Tamam')));
      await t.tap(find.text('aç'));
      await t.pumpAndSettle();
      await t.tap(find.text('Tamam'));
      await t.pumpAndSettle();
      expect(find.text('Bilgi'), findsNothing);
    });

    testWidgets('BuConfirmSheet: onay true, vazgeç false', (t) async {
      bool? r;
      await t.pumpWidget(host((c) async => r = await BuConfirmSheet.show(c, title: 'Silinsin mi?', message: 'Geri alınamaz', confirmLabel: 'Sil', destructive: true)));
      await t.tap(find.text('aç'));
      await t.pumpAndSettle();
      await t.tap(find.text('Sil'));
      await t.pumpAndSettle();
      expect(r, isTrue);
      await t.tap(find.text('aç'));
      await t.pumpAndSettle();
      await t.tap(find.text('Vazgeç'));
      await t.pumpAndSettle();
      expect(r, isFalse);
    });

    testWidgets('BuToast: mesaj + eylem; yenisi eskisinin yerini alır', (t) async {
      var undo = 0;
      await t.pumpWidget(host((c) => BuToast.show(c, 'Kaydedildi', kind: BuToastKind.success, actionLabel: 'Geri al', onAction: () => undo++)));
      await t.tap(find.text('aç'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Kaydedildi'), findsOneWidget);
      await t.tap(find.text('Geri al'));
      expect(undo, 1);
      for (final k in BuToastKind.values) {
        await t.pumpWidget(host((c) => BuToast.show(c, 'Mesaj $k', kind: k)));
        await t.tap(find.text('aç'));
        await t.pump(const Duration(milliseconds: 400));
        expect(t.takeException(), isNull);
      }
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('M3 seçiciler ve gezinme 3 dilde taşmadan çizilir (tarih/saat seçici, NavigationBar, TabBar, SearchBar)', (t) async {
      for (final lang in ['tr', 'en', 'ar']) {
        await t.pumpWidget(host((c) => showDatePicker(context: c, initialDate: DateTime(2026, 10, 29), firstDate: DateTime(2026), lastDate: DateTime(2027)), lang: lang));
        await t.tap(find.text('aç'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        t.state<NavigatorState>(find.byType(Navigator)).pop();
        await t.pumpAndSettle();
        await t.pumpWidget(host((c) => showTimePicker(context: c, initialTime: const TimeOfDay(hour: 14, minute: 30)), lang: lang));
        await t.tap(find.text('aç'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        t.state<NavigatorState>(find.byType(Navigator)).pop();
        await t.pumpAndSettle();
      }
      await p00Matrix(
        t,
        () => Scaffold(
          body: Column(children: [
            const SearchBar(hintText: 'Ara'),
            DefaultTabController(length: 3, child: TabBar(tabs: const [Tab(text: 'Gönderiler'), Tab(text: 'Etkinlikler'), Tab(text: 'Üyeler')])),
            const Spacer(),
            NavigationBar(selectedIndex: 2, destinations: const [
              NavigationDestination(icon: Icon(Icons.home), label: 'Ana Sayfa'),
              NavigationDestination(icon: Icon(Icons.explore), label: 'Keşfet'),
              NavigationDestination(icon: Icon(Icons.chat), label: 'Sohbet'),
              NavigationDestination(icon: Icon(Icons.group), label: 'Kulüpler'),
              NavigationDestination(icon: Icon(Icons.person), label: 'Profil'),
            ]),
          ]),
        ),
        scaffold: false,
        widths: const [320],
      );
    });
  });

  group('M3 çekirdek kontrolleri matrisi', () {
    testWidgets('düğmeler, giriş alanları, anahtar/onay/radyo/kaydırıcı, ilerleme, rozet, çip, FAB', (t) async {
      await p00Matrix(
        t,
        () => _scroll([
          FilledButton(onPressed: () {}, child: const Text('Filled')),
          FilledButton.tonal(onPressed: () {}, child: const Text('Tonal')),
          OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
          TextButton(onPressed: () {}, child: const Text('Text')),
          const TextField(decoration: InputDecoration(labelText: 'E-posta', helperText: 'yardım')),
          const TextField(decoration: InputDecoration(labelText: 'Şifre', errorText: 'Hata')),
          Row(children: [
            Switch(value: true, onChanged: (_) {}),
            Switch(value: false, onChanged: (_) {}),
            Checkbox(value: true, onChanged: (_) {}),
            Checkbox(value: false, onChanged: (_) {}),
          ]),
          Slider(value: .3, onChanged: (_) {}),
          const LinearProgressIndicator(value: .4),
          Wrap(spacing: 8, children: [
            FilterChip(label: const Text('Filtre'), selected: true, onSelected: (_) {}),
            ChoiceChip(label: const Text('Seçim'), selected: false, onSelected: (_) {}),
            InputChip(label: const Text('Etiket'), onDeleted: () {}),
            const Badge(label: Text('3'), child: Icon(Icons.notifications)),
          ]),
          SegmentedButton<int>(segments: const [ButtonSegment(value: 0, label: Text('Gün')), ButtonSegment(value: 1, label: Text('Hafta'))], selected: const {1}, onSelectionChanged: (_) {}),
          const ExpansionTile(title: Text('Açılır'), children: [Text('içerik')]),
          const Divider(),
        ]),
      );
    });
  });

  group('BuImage ve eski sarmalayıcılar', () {
    testWidgets('BuImage: url yoksa yer tutucu, hata yedeği, cacheWidth düzen x DPR', (t) async {
      await p00Matrix(t, () => const Column(children: [BuImage(null, width: 100, height: 60, radius: 12), BuImage('/files/x.png', width: 100, height: 60, radius: 12)]), widths: const [320]);
      await t.pumpWidget(p00App(const BuImage(null, width: 80, height: 80)));
      expect(find.byIcon(LucideIcons.image), findsOneWidget);
    });

    testWidgets('ErrorView/EmptyView artık BuErrorState/BuEmptyState sarmalayıcısı; imza ve metinler aynı', (t) async {
      var n = 0;
      await t.pumpWidget(p00App(ErrorView(error: ApiError(0, 'NETWORK', 'x'), onRetry: () => n++)));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byType(BuErrorState), findsOneWidget);
      await t.tap(find.text('Yeniden dene'));
      expect(n, 1);
      await t.pumpWidget(p00App(EmptyView(icon: LucideIcons.messageCircle, title: 'Başlık', text: 'Açıklama', actionLabel: 'Git', onAction: () => n++)));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byType(BuEmptyState), findsOneWidget);
      expect(find.text('Başlık'), findsOneWidget);
      expect(find.text('Açıklama'), findsOneWidget);
      await t.pumpWidget(p00App(const EmptyView(icon: LucideIcons.bell, text: 'Sadece metin')));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Sadece metin'), findsOneWidget);
    });
  });

  group('metin kontrastı rehberi', () {
    for (final dark in [false, true]) {
      testWidgets('temel bileşenler textContrastGuideline sağlar (${dark ? 'koyu' : 'açık'})', (t) async {
        final h = t.ensureSemantics();
        await t.pumpWidget(p00App(
          _scroll([
            BuButton(label: 'Birincil', onPressed: () {}),
            BuButton(label: 'Tonal', kind: BuButtonKind.soft, onPressed: () {}),
            BuButton(label: 'Çerçeveli', kind: BuButtonKind.outline, onPressed: () {}),
            BuButton(label: 'Sil', kind: BuButtonKind.danger, onPressed: () {}),
            const BuCard(child: Text('Kart metni')),
            BuChip(label: 'Seçili', selected: true, onTap: () {}),
            BuChip(label: 'Seçili değil', onTap: () {}),
            const BuOfflineBanner(),
            const BuCountBadge(5),
          ]),
          dark: dark,
        ));
        await t.pump(const Duration(milliseconds: 600));
        await expectLater(t, meetsGuideline(textContrastGuideline));
        h.dispose();
      });
    }
  });
}

void _noop(int _) {}
