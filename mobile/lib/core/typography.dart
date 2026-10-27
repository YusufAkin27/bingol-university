import 'package:flutter/painting.dart';

/// Uygulamanın tek yazı tipi ve boyut ölçeği. Sayfalarda elle `fontSize` yazılmaz; bu stillerden biri seçilir,
/// renk `copyWith(color: ...)` ile verilir. Satır yüksekliği (height) ölçeğe dahildir.
abstract final class BuType {
  /// pubspec.yaml `fonts:` bölümündeki aile adı.
  static const family = 'Inter';

  /// Büyük sayfa başlığı (giriş ekranı, profil adı).
  static const display = TextStyle(fontFamily: family, fontSize: 26, fontWeight: FontWeight.w800, height: 1.2);

  /// Sayfa/AppBar başlığı.
  static const title = TextStyle(fontFamily: family, fontSize: 20, fontWeight: FontWeight.w800, height: 1.25);

  /// Bölüm başlığı, kart başlığı.
  static const heading = TextStyle(fontFamily: family, fontSize: 17, fontWeight: FontWeight.w700, height: 1.3);

  /// Gövde metni (mesaj, haber özeti, form alanı).
  static const body = TextStyle(fontFamily: family, fontSize: 15, fontWeight: FontWeight.w400, height: 1.4);

  /// Vurgulu gövde (liste satırı başlığı, düğme).
  static const bodyStrong = TextStyle(fontFamily: family, fontSize: 15, fontWeight: FontWeight.w600, height: 1.4);

  /// Etiket, ikincil satır, çip.
  static const label = TextStyle(fontFamily: family, fontSize: 13, fontWeight: FontWeight.w600, height: 1.35);

  /// Açıklama, yardımcı metin.
  static const caption = TextStyle(fontFamily: family, fontSize: 12, fontWeight: FontWeight.w400, height: 1.35);

  /// Saat, rozet, en küçük metin.
  static const micro = TextStyle(fontFamily: family, fontSize: 11, fontWeight: FontWeight.w500, height: 1.3);
}
