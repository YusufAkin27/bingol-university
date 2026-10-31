@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/features/auth/widgets/auth_ref.dart';
import 'package:bu_kampus/features/shell/floating_nav.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'p00_support.dart';

/// SIZE-FIX ekran goruntuleri: Redmi 13C esdegeri (360x800 dp, dpr 2 => 720x1600 px, emulator onceki goruntulerle ayni
/// olcek) ve Pixel 6 esdegeri (411x891). Uretim: STORE_SHOTS_OUT='C:/bu_qa/shots/tasarim/boyut/sonra' flutter test <bu dosya>
void main() {
  final out = Platform.environment['STORE_SHOTS_OUT'];
  final skip = out == null ? 'STORE_SHOTS_OUT tanimli degil' : null;
  setUpAll(loadTestFonts);

  Widget kesfet(ValueNotifier<int> badge) => Scaffold(
        extendBody: true,
        bottomNavigationBar: FloatingNav(index: 3, onChanged: (_) {}, chatBadge: badge),
        body: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            BuHeader(title: 'Kulüpler', actions: [
              BuIconButton(icon: LucideIcons.search, onTap: () {}, tooltip: 'Ara'),
              BuIconButton(icon: LucideIcons.plus, onTap: () {}, filled: true, tooltip: 'Yeni'),
            ]),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: BuSegmented(items: const ['Keşfet', 'Kulüplerim'], index: 0, onChanged: (_) {}),
            ),
            const SizedBox(height: 4),
            BuChipRow(labels: const ['Tümü', 'Teknoloji', 'Spor', 'Sanat'], selected: 0, onSelected: (_) {}),
            const Padding(padding: EdgeInsets.fromLTRB(20, 4, 20, 8), child: BuSearchField()),
            const BuSectionTitle('Hesap'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: BuGroup(dividerIndent: 64, children: [
                BuMenuRow(icon: LucideIcons.key, label: 'Hesap ve güvenlik', onTap: () {}),
                BuMenuRow(icon: LucideIcons.lock, label: 'Gizlilik ve engellenenler', onTap: () {}),
                BuMenuRow(icon: LucideIcons.download, label: 'Verilerim', onTap: () {}),
              ]),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(children: [
                BuButton(label: 'Kulübe katıl', onPressed: () {}),
                const SizedBox(height: 12),
                Row(children: [
                  BuButton(label: 'Katıl', compact: true, onPressed: () {}),
                  const SizedBox(width: 8),
                  BuButton(label: 'Ayrıl', compact: true, kind: BuButtonKind.outline, onPressed: () {}),
                ]),
              ]),
            ),
          ],
        ),
      );

  Widget kimlik() {
    final mail = TextEditingController(), pass = TextEditingController();
    return RefPage(children: [
      const RefHeading(title: 'Tekrar hoş geldin', subtitle: 'Okul e-postanla giriş yap.'),
      const SizedBox(height: 24),
      RefTextField(controller: mail, label: 'E-posta', hint: 'ad.soyad@bingol.edu.tr', icon: LucideIcons.mail),
      const SizedBox(height: 16),
      RefTextField(controller: pass, label: 'Şifre', hint: '••••••••', icon: LucideIcons.lock),
      const SizedBox(height: 24),
      RefButton(label: 'Giriş yap', onPressed: () {}),
      const SizedBox(height: 8),
      RefLink(label: 'Şifremi unuttum', onPressed: () {}),
    ]);
  }

  for (final (w, h, tag) in [(360.0, 800.0, 'redmi360'), (411.0, 891.0, 'pixel411')]) {
    for (final scr in ['kesfet', 'kimlik']) {
      testWidgets('boyut $scr $tag', skip: skip != null, (tester) async {
        tester.view.devicePixelRatio = 2;
        tester.view.physicalSize = Size(w * 2, h * 2);
        tester.view.padding = const FakeViewPadding(top: 24 * 2, bottom: 16 * 2);
        tester.view.viewPadding = const FakeViewPadding(top: 24 * 2, bottom: 16 * 2);
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        final badge = ValueNotifier<int>(0);
        addTearDown(badge.dispose);
        await tester.pumpWidget(RepaintBoundary(key: key, child: p00App(scr == 'kesfet' ? kesfet(badge) : kimlik(), scaffold: false)));
        await settle(tester, const Duration(milliseconds: 900));
        final err = tester.takeException();
        if (err != null) fail('Istisna: $err');
        await tester.runAsync(() async {
          final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await ro.toImage(pixelRatio: 2);
          final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          final dir = Directory(out!)..createSync(recursive: true);
          File('${dir.path}/${scr}_$tag.png').writeAsBytesSync(data.buffer.asUint8List());
        });
        await unmount(tester);
      });
    }
  }
}
