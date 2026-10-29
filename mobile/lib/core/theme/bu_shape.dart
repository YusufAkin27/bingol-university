import 'package:flutter/material.dart';

/// Köşe yarıçapı sistemi (dp): küçük 12, orta 16, büyük 20, çok büyük 28, hap.
/// Kural: iç içe şekillerde iç yarıçap = dış yarıçap - boşluk.
abstract final class BuRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;

  static const BorderRadius bXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius bSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius bMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius bLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius bXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius bPill = BorderRadius.all(Radius.circular(pill));

  /// Yalnız üst köşeler yuvarlak (alt sayfa).
  static const BorderRadius topXl = BorderRadius.vertical(top: Radius.circular(xl));

  /// Yuvarlatılmış dikdörtgen şekil; [side] verilirse çerçeveli.
  static RoundedRectangleBorder rect(double radius, {BorderSide side = BorderSide.none}) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: side);
}
