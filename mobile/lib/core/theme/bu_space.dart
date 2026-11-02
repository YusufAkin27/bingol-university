import 'package:flutter/widgets.dart';

/// Boşluk ölçeği (dp). Sayfalarda elle `SizedBox(height: 13)` yazılmaz; bu ölçekten biri seçilir.
/// 2 / 4 / 8 / 12 / 16 / 20 / 24 / 32 / 48 (+ geçiş jetonları 10 ve 14, karar D-2).
abstract final class BuSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;

  /// 10 dp: geçiş jetonu (D-2). Mevcut ekranların 10'luk boşluğunu GÖRÜNÜM DEĞİŞTİRMEDEN jetona bağlar; yeni tasarımda
  /// önce [sm]/[md] düşünün.
  static const double s10 = 10;

  /// 14 dp: geçiş jetonu (D-2); yeni tasarımda önce [md]/[lg].
  static const double s14 = 14;
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
  static const h10 = SizedBox(height: 10);
  static const h12 = SizedBox(height: 12);
  static const h14 = SizedBox(height: 14);
  static const h16 = SizedBox(height: 16);
  static const h20 = SizedBox(height: 20);
  static const h24 = SizedBox(height: 24);
  static const h32 = SizedBox(height: 32);
  static const h48 = SizedBox(height: 48);

  static const w4 = SizedBox(width: 4);
  static const w6 = SizedBox(width: 6);
  static const w8 = SizedBox(width: 8);
  static const w10 = SizedBox(width: 10);
  static const w12 = SizedBox(width: 12);
  static const w14 = SizedBox(width: 14);
  static const w16 = SizedBox(width: 16);
  static const w20 = SizedBox(width: 20);
  static const w24 = SizedBox(width: 24);
}

/// Optik ince ayar değerleri (dp): 4'ün katı olmayan, tek tek gözle ayarlanmış eski boşluklar (satır içi 1-3 dp
/// hizalama, 5/7/9 dp çip içi dolgu, 13-26 dp özel kenar). GÖRÜNÜMÜ KORUMAK için vardır; YENİ tasarımda [BuSpace]
/// ölçeği kullanılır. Kullanımı `const SizedBox(height: BuOptical.n3)` ya da `EdgeInsets.symmetric(vertical: BuOptical.n7)`.
abstract final class BuOptical {
  static const double n1 = 1;
  static const double n3 = 3;
  static const double n5 = 5;
  static const double n7 = 7;
  static const double n9 = 9;
  static const double n13 = 13;
  static const double n15 = 15;
  static const double n17 = 17;
  static const double n18 = 18;
  static const double n22 = 22;
  static const double n25 = 25;
  static const double n26 = 26;
}

/// Yön duyarlı kenar boşluğu kısayolları (HIG-P1). `EdgeInsets.fromLTRB/only(left,right)` Arapçada (RTL) yanlış tarafa
/// düşer; bunlar `EdgeInsetsDirectional` döndürür (LTR'de görünüm AYNI, RTL'de aynalanır).
///
/// | Eski | Yeni |
/// |---|---|
/// | `EdgeInsets.fromLTRB(a, t, b, bt)` | `BuInsets.steb(a, t, b, bt)` |
/// | `EdgeInsets.only(left: x)` / `(right: x)` | `BuInsets.start(x)` / `BuInsets.end(x)` |
/// | `EdgeInsets.symmetric(horizontal: h, vertical: v)` | zaten yönsüz; aynen kalır (ya da `BuInsets.hv(h, v)`) |
/// | `Positioned(left:/right:)` | `PositionedDirectional(start:/end:)` |
/// | `Alignment.centerLeft/Right` | `AlignmentDirectional.centerStart/centerEnd` |
abstract final class BuInsets {
  /// start, top, end, bottom (LTR: sol, üst, sağ, alt).
  static EdgeInsetsDirectional steb(double start, double top, double end, double bottom) =>
      EdgeInsetsDirectional.fromSTEB(start, top, end, bottom);

  static EdgeInsetsDirectional start(double v) => EdgeInsetsDirectional.only(start: v);
  static EdgeInsetsDirectional end(double v) => EdgeInsetsDirectional.only(end: v);

  /// Yatay [h], dikey [v].
  static EdgeInsetsDirectional hv(double h, double v) => EdgeInsetsDirectional.symmetric(horizontal: h, vertical: v);

  /// Yalnız yatay.
  static EdgeInsetsDirectional h(double h) => EdgeInsetsDirectional.symmetric(horizontal: h);

  /// Yalnız dikey.
  static EdgeInsetsDirectional v(double v) => EdgeInsetsDirectional.symmetric(vertical: v);
}
