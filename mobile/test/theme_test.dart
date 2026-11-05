import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bu_kampus/core/theme.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + .05) / (lo + .05);
}

void main() {
  test('light ve dark temada BuTokens uzantısı var', () {
    expect(BuTheme.light().extension<BuTokens>(), isNotNull);
    expect(BuTheme.dark().extension<BuTokens>(), isNotNull);
    expect(BuTheme.light().brightness, Brightness.light);
    expect(BuTheme.dark().brightness, Brightness.dark);
  });

  test('kritik token değerleri', () {
    final l = BuTheme.light().extension<BuTokens>()!;
    final d = BuTheme.dark().extension<BuTokens>()!;
    // Premium White: siyah birincil + beyaz yazı; Premium Black: beyaz birincil + siyah yazı.
    expect(l.pr, const Color(0xFF09090B));
    expect(l.onPr, const Color(0xFFFFFFFF));
    expect(d.pr, const Color(0xFFFAFAFA));
    expect(d.onPr, const Color(0xFF09090B));
    expect(l.prText, l.ink); // vurgu metni nötr (kırmızı değil)
    expect(d.prText, d.ink);
    expect(BuTheme.light().colorScheme.primary, l.pr);
    expect(BuTheme.dark().colorScheme.primary, d.pr);
  });

  test('onPr, prPressed üstünde en az 4.5:1 kontrast verir (pr üstünde küçük yazı AA vermez)', () {
    expect(contrast(BuTokens.light.onPr, BuTokens.light.prPressed), greaterThanOrEqualTo(4.5));
    expect(contrast(BuTokens.dark.onPr, BuTokens.dark.prPressed), greaterThanOrEqualTo(4.5));
    expect(contrast(BuTokens.light.onPr, BuTokens.light.pr), greaterThanOrEqualTo(7));
    expect(contrast(BuTokens.dark.onPr, BuTokens.dark.pr), greaterThanOrEqualTo(7));
  });

  test('ana yazı zemin üstünde okunur', () {
    expect(contrast(BuTokens.light.ink, BuTokens.light.bg), greaterThanOrEqualTo(4.5));
    expect(contrast(BuTokens.dark.ink, BuTokens.dark.bg), greaterThanOrEqualTo(4.5));
  });
}
