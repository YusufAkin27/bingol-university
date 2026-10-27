import 'package:flutter/painting.dart';

/// Boyutlar önceki ölçeğin %10 küçültülmüş halidir (26/20/17/15/13/12/11 → ×0.9).
/// Uygulamanın tek yazı tipi ve boyut ölçeği. Sayfalarda elle `fontSize` yazılmaz; bu stillerden biri seçilir,
/// renk `copyWith(color: ...)` ile verilir. Satır yüksekliği (height) ölçeğe dahildir.
abstract final class BuType {
  /// pubspec.yaml `fonts:` bölümündeki aile adı.
  static const family = 'Inter';

  /// Büyük sayfa başlığı (giriş ekranı, profil adı).
  static const display = TextStyle(fontFamily: family, fontSize: 23.4, fontWeight: FontWeight.w800, height: 1.2);

  /// Sayfa/AppBar başlığı.
  static const title = TextStyle(fontFamily: family, fontSize: 18, fontWeight: FontWeight.w800, height: 1.25);

  /// Bölüm başlığı, kart başlığı.
  static const heading = TextStyle(fontFamily: family, fontSize: 15.3, fontWeight: FontWeight.w700, height: 1.3);

  /// Gövde metni (mesaj, haber özeti, form alanı).
  static const body = TextStyle(fontFamily: family, fontSize: 13.5, fontWeight: FontWeight.w400, height: 1.4);

  /// Vurgulu gövde (liste satırı başlığı, düğme).
  static const bodyStrong = TextStyle(fontFamily: family, fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.4);

  /// Etiket, ikincil satır, çip.
  static const label = TextStyle(fontFamily: family, fontSize: 11.7, fontWeight: FontWeight.w600, height: 1.35);

  /// Açıklama, yardımcı metin.
  static const caption = TextStyle(fontFamily: family, fontSize: 10.8, fontWeight: FontWeight.w400, height: 1.35);

  /// Saat, rozet, en küçük metin.
  static const micro = TextStyle(fontFamily: family, fontSize: 9.9, fontWeight: FontWeight.w500, height: 1.3);
}
