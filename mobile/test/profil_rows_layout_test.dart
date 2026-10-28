import 'package:bu_kampus/features/profile/profil_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'support/fake_app.dart';

/// Profil satırları: sabit yükseklik, tek satır, ok aynı konumda (320 dp, büyük yazı, RTL).
void main() {
  setUpAll(loadTestFonts);

  const labels = [
    'Gönderilerim ve çok uzun bir başlık metni burada',
    'Önerilen kişiler',
    'مقالاتي المحفوظة وأشخاص مقترحون لك للمتابعة',
    'Kaydedilenler',
  ];

  for (final rtl in [false, true]) {
    for (final br in Brightness.values) {
      testWidgets('ProfilRow ${br.name} ${rtl ? 'rtl' : 'ltr'} 320 x1.6: tek satır, eşit ok', (tester) async {
        const size = Size(320, 800);
        useScreen(tester, size);
        Widget page = Scaffold(
          body: SingleChildScrollView(
            child: ProfilCard(children: [
              for (final l in labels) ProfilRow(icon: LucideIcons.bookmark, label: l, onTap: () {}),
              const ProfilRow(icon: LucideIcons.globe, label: 'Dil', value: 'Türkçe çok uzun değer', chevron: false),
              ProfilRow(icon: LucideIcons.user, label: 'Alt yazılı satır', sub: 'Uzun bir alt yazı metni '
                  'burada ikinci satıra düşmemeli', onTap: () {}),
            ]),
          ),
        );
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        page = Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr, child: buildApp(page, brightness: br, size: size));
        await tester.pumpWidget(page);
        await tester.pump();
        expect(tester.takeException(), isNull);

        final rows = find.byType(ProfilRow);
        final heights = [for (var i = 0; i < 6; i++) tester.getSize(rows.at(i)).height];
        // Tek satırlık başlıklı satırlar (alt yazısızlar) aynı yükseklikte.
        expect({heights[0], heights[1], heights[2], heights[3], heights[4]}.length, 1, reason: '$heights');
        // Başlıklar tek satır: yükseklik iki satırdan küçük.
        final xs = <double>{};
        for (var i = 0; i < 4; i++) {
          final r = tester.getRect(find.descendant(of: rows.at(i), matching: find.byType(Icon)).last);
          xs.add(rtl ? r.left : r.right);
        }
        expect(xs.length, 1, reason: '$xs');
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
