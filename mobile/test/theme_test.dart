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
    expect(l.pr, const Color(0xFFC62A20));
    expect(d.pr, const Color(0xFFFF6A5F));
    expect(BuTheme.light().colorScheme.primary, l.pr);
    expect(BuTheme.dark().colorScheme.primary, d.pr);
  });

  test('onPr, pr üstünde en az 4.5:1 kontrast verir', () {
    expect(contrast(BuTokens.light.onPr, BuTokens.light.pr), greaterThanOrEqualTo(4.5));
    expect(contrast(BuTokens.dark.onPr, BuTokens.dark.pr), greaterThanOrEqualTo(4.5));
  });

  test('ana yazı zemin üstünde okunur', () {
    expect(contrast(BuTokens.light.ink, BuTokens.light.bg), greaterThanOrEqualTo(4.5));
    expect(contrast(BuTokens.dark.ink, BuTokens.dark.bg), greaterThanOrEqualTo(4.5));
  });
}
