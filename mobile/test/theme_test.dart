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
    expect(l.pr, const Color(0xFFDC4C46)); // premium palet: marka vurgusu
    expect(l.prPressed, const Color(0xFFB93833)); // beyaz yazılı dolu düğme/bağlantı (AA)
    expect(d.pr, const Color(0xFFF0726C));
    // Material bileşenleri (dolu düğme, odak) AA için prPressed kullanır.
    expect(BuTheme.light().colorScheme.primary, l.prPressed);
    expect(BuTheme.dark().colorScheme.primary, d.prPressed);
  });

  test('onPr, prPressed üstünde en az 4.5:1 kontrast verir (pr üstünde küçük yazı AA vermez)', () {
    expect(contrast(BuTokens.light.onPr, BuTokens.light.prPressed), greaterThanOrEqualTo(4.5));
    expect(contrast(BuTokens.dark.onPr, BuTokens.dark.prPressed), greaterThanOrEqualTo(4.5));
    expect(contrast(BuTokens.light.onPr, BuTokens.light.pr), greaterThanOrEqualTo(3)); // büyük/kalın metin
  });

  test('ana yazı zemin üstünde okunur', () {
    expect(contrast(BuTokens.light.ink, BuTokens.light.bg), greaterThanOrEqualTo(4.5));
    expect(contrast(BuTokens.dark.ink, BuTokens.dark.bg), greaterThanOrEqualTo(4.5));
  });
}
