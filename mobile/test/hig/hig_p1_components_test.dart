// HIG-P1: ortak bilesenlerin (lib/widgets) yazi olcegi 2.0 tasmasi, dokunma hedefi (>= 48 dp), etiket ve metin
// kontrasti (acik + koyu) denetimi. Gorunumun degismedigini bilesen boyutlariyla da dogrular.
import 'package:bu_kampus/widgets/bu.dart';
import 'package:bu_kampus/widgets/common.dart';
import 'package:bu_kampus/widgets/sistem_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../redesign/p00_support.dart';

/// Denetlenecek ortak bilesenler (ad -> uretici).
Map<String, Widget Function()> _components() => {
      'BuErrorState': () => SizedBox(height: 520, child: BuErrorState(onRetry: () {})),
      'BuErrorState(mesaj)': () => SizedBox(
            height: 520,
            child: BuErrorState(title: 'Bulunamadı', message: 'Aradığın içerik kaldırılmış olabilir.', onRetry: () {}),
          ),
      'BuEmptyState': () => SizedBox(
            height: 520,
            child: BuEmptyState(
              title: 'Henüz bir şey yok',
              message: 'Yeni bir sohbet başlatarak arkadaşlarına yazabilirsin.',
              actionLabel: 'Sohbet başlat',
              onAction: () {},
              secondaryLabel: 'Daha sonra',
              onSecondary: () {},
            ),
          ),
      'BuEmptyState(compact)': () => const SizedBox(height: 260, child: BuEmptyState(title: 'Sonuç yok', message: 'Başka bir şey ara.', compact: true)),
      'BuChipRow': () => BuChipRow(labels: const ['Tümü', 'Haberler', 'Duyurular', 'Etkinlikler'], selected: 1, onSelected: (_) {}),
      'BuChip': () => BuChip(label: 'Tümü', selected: true, onTap: () {}),
      'BuSectionHeader': () => BuSectionHeader('Yaklaşan etkinlikler ve duyurular', action: 'Tümü', onAction: () {}),
      'BuSectionTitle': () => BuSectionTitle('Yaklaşan etkinlikler ve duyurular', action: 'Tümü', onAction: () {}),
      'BuListTile': () => BuListTile(title: 'Uzun bir satır başlığı örneği', subtitle: 'İkinci satır açıklaması', leading: const Icon(Icons.person), onTap: () {}, showChevron: true),
      'BuSettingsTile': () => BuSettingsTile(icon: BuIcons.bell, title: 'Bildirim tercihleri', subtitle: 'Hangi bildirimleri alacağını seç', value: 'Açık', onTap: () {}),
      'BuSettingsTile.toggle': () => BuSettingsTile.toggle(icon: BuIcons.bell, title: 'Bildirimler', value: true, onChanged: (_) {}),
      'BuMenuRow': () => BuMenuRow(icon: BuIcons.settings, label: 'Hesap ve güvenlik ayarları', onTap: () {}),
      'BuHeader': () => BuHeader(title: 'Çok uzun bir sayfa başlığı örneği', subtitle: 'Alt başlık', onBack: () {}, actions: [BuIconButton(icon: BuIcons.search, tooltip: 'Ara', onTap: () {})]),
      'BuButton': () => Column(children: [
            BuButton(label: 'Devam et', onPressed: () {}),
            BuButton(label: 'Vazgeç', kind: BuButtonKind.soft, onPressed: () {}),
            BuButton(label: 'Sil', kind: BuButtonKind.danger, onPressed: () {}),
            BuButton(label: 'Daha fazla', kind: BuButtonKind.text, compact: true, onPressed: () {}),
          ]),
      'BuSearchField': () => BuSearchField(controller: TextEditingController(text: 'arama'), onChanged: (_) {}),
      'BuCard': () => BuCard(onTap: () {}, child: const Text('Kart içeriği uzun bir metin olabilir ve birden fazla satıra sarabilir')),
      'BuBadge+BuCountBadge': () => const Row(children: [BuBadge('Yeni', soft: true), SizedBox(width: 8), BuCountBadge(120)]),
      'BuSegmented': () => BuSegmented(items: const ['Gelen', 'Giden', 'Tümü'], index: 0, onChanged: (_) {}),
      'MaintenanceBand': () => const MaintenanceBand(text: 'Haberler şu an güncellenemiyor, kayıtlı içerik gösteriliyor.'),
      'SistemStatusView': () => SizedBox(
            height: 560,
            child: SistemStatusView(icon: BuIcons.wifiOff, title: 'Bağlantı yok', body: 'İnternet bağlantını kontrol edip yeniden dene.', footer: [SistemButton(label: 'Yeniden dene', onPressed: () {})]),
          ),
      'SectionHeader': () => SectionHeader('Son haberler', action: 'Tümü', onAction: () {}),
      'TypeBadge': () => const TypeBadge('ETKINLIK'),
    };

void main() {
  final comps = _components();

  group('yazi olcegi 2.0: ortak bilesenler tasmaz (320/390 dp, tr/en/ar, acik/koyu)', () {
    for (final e in comps.entries) {
      testWidgets(e.key, (tester) async {
        addTearDown(tester.view.reset);
        for (final w in [320.0, 390.0]) {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(w, 900);
          for (final lang in kP00Langs) {
            for (final dark in [false, true]) {
              await tester.pumpWidget(p00App(SingleChildScrollView(child: e.value()), lang: lang, dark: dark, scale: 2.0));
              await tester.pump(const Duration(milliseconds: 700));
              final err = tester.takeException();
              if (err != null) fail('[${e.key} $lang dark=$dark w=$w x2.0] $err');
            }
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 300));
      });
    }
  });

  group('dokunma hedefi >= 48 dp + etiket (androidTapTargetGuideline, labeledTapTargetGuideline)', () {
    const tappable = [
      'BuErrorState',
      'BuEmptyState',
      'BuChipRow',
      'BuChip',
      'BuSectionHeader',
      'BuSectionTitle',
      'BuListTile',
      'BuSettingsTile',
      'BuSettingsTile.toggle',
      'BuMenuRow',
      'BuHeader',
      'BuButton',
      'BuSearchField',
      'BuSegmented',
      'SistemStatusView',
      'SectionHeader',
    ];
    for (final name in tappable) {
      testWidgets(name, (tester) async {
        final h = tester.ensureSemantics();
        addTearDown(tester.view.reset);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 900);
        await tester.pumpWidget(p00App(SingleChildScrollView(child: comps[name]!())));
        await tester.pump(const Duration(milliseconds: 700));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 300));
        h.dispose();
      });
    }
  });

  group('metin kontrasti (textContrastGuideline) YERLESTIKTEN SONRA: hata/bos durum', () {
    for (final name in ['BuErrorState', 'BuErrorState(mesaj)', 'BuEmptyState', 'BuEmptyState(compact)', 'SistemStatusView']) {
      for (final dark in [false, true]) {
        testWidgets('$name ${dark ? 'koyu' : 'acik'}', (tester) async {
          final h = tester.ensureSemantics();
          addTearDown(tester.view.reset);
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(390, 900);
          await tester.pumpWidget(p00App(comps[name]!(), dark: dark));
          // Giris animasyonu (solma + yukselme) bitmeden olcmek yanlis dusuk kontrast verir: yerlestir.
          await tester.pump(const Duration(milliseconds: 1200));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 300));
          h.dispose();
        });
      }
    }
  });
}
