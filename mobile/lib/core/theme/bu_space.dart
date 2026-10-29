import 'package:flutter/widgets.dart';

/// Boşluk ölçeği (dp). Sayfalarda elle `SizedBox(height: 13)` yazılmaz; bu ölçekten biri seçilir.
/// 2 / 4 / 8 / 12 / 16 / 20 / 24 / 32 / 48.
abstract final class BuSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  /// Sayfa yan boşluğu (içerik kenarı).
  static const double page = 20;

  /// Sayfa kenar boşluğu (yatay), RTL'de otomatik aynalanır.
  static const EdgeInsetsDirectional pageH = EdgeInsetsDirectional.symmetric(horizontal: page);

  /// Kart iç boşluğu.
  static const EdgeInsetsDirectional card = EdgeInsetsDirectional.all(lg);

  /// Liste satırı iç boşluğu.
  static const EdgeInsetsDirectional row = EdgeInsetsDirectional.symmetric(horizontal: lg, vertical: sm);
}

/// Hazır sabit boşluk parçaları: `BuGap.h8` (dikey 8), `BuGap.w12` (yatay 12). `const` olduklarından ücretsizdir.
abstract final class BuGap {
  static const h2 = SizedBox(height: 2);
  static const h4 = SizedBox(height: 4);
  static const h6 = SizedBox(height: 6);
  static const h8 = SizedBox(height: 8);
  static const h12 = SizedBox(height: 12);
  static const h16 = SizedBox(height: 16);
  static const h20 = SizedBox(height: 20);
  static const h24 = SizedBox(height: 24);
  static const h32 = SizedBox(height: 32);
  static const h48 = SizedBox(height: 48);

  static const w4 = SizedBox(width: 4);
  static const w6 = SizedBox(width: 6);
  static const w8 = SizedBox(width: 8);
  static const w12 = SizedBox(width: 12);
  static const w16 = SizedBox(width: 16);
  static const w20 = SizedBox(width: 20);
  static const w24 = SizedBox(width: 24);
}
