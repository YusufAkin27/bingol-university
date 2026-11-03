import 'package:flutter/widgets.dart';

/// Hareket sabitleri. Süre 150 / 250 / 400 ms; eğriler Material 3 "emphasized" ve "standard".
/// Yalnız `transform`/`opacity` canlandırılır; "animasyonları azalt" açıksa [of] sıfır döner.
abstract final class BuMotion {
  /// Mikro etkileşim (basma, anahtar, çip seçimi).
  static const Duration short = Duration(milliseconds: 150);

  /// Bileşen geçişi (sayfa içi durum, alt sayfa içeriği, kayan gösterge).
  static const Duration medium = Duration(milliseconds: 250);

  /// Sayfa/ekran giriş geçişi, asamali giris sonu.
  static const Duration long = Duration(milliseconds: 400);

  /// Asamali (staggered) girişte öğeler arası gecikme.
  static const Duration stagger = Duration(milliseconds: 40);

  /// Standart: çoğu geçiş için (M3 standard).
  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Girişte yavaşlayan vurgulu eğri (öğe belirir).
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Çıkışta hızlanan vurgulu eğri (öğe kaybolur).
  static const Curve emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);

  /// İki yönlü vurgulu eğri (konum/boyut değişimi).
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  /// Geriye uyum: eski kodun `Curves.easeOutCubic` karşılığı.
  static const Curve decelerate = Curves.easeOutCubic;

  /// "Animasyonları azalt" (erişilebilirlik) açık mı?
  static bool reduced(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// [d] süresi; hareket azaltılmışsa sıfır.
  static Duration of(BuildContext context, [Duration d = medium]) => reduced(context) ? Duration.zero : d;
}

/// Merkezi hareket tokenları (sade, akıcı, amaca yönelik). Değerleri bileşenin davranışına göre seçin;
/// "animasyonları azalt" açıksa [of] sıfır süre döner. Eski [BuMotion] geriye uyum için durur.
abstract final class AppMotion {
  static const Duration instant = Duration(milliseconds: 80);
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration emphasized = Duration(milliseconds: 300);
  static const Duration sheet = Duration(milliseconds: 340);

  static const Curve standard = Curves.easeInOutCubic;
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve interactive = Curves.easeOutQuart;

  /// [d] süresi; hareket azaltılmışsa sıfır.
  static Duration of(BuildContext context, [Duration d = normal]) => BuMotion.of(context, d);
}
