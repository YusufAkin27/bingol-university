import 'package:flutter/painting.dart';

/// Uygulamanın TEK yazı boyutu ölçeği (K-21, T-113). Hem `BuType` hem `BuTextTheme` (M3 TextTheme) boyutlarını
/// buradan alır; iki paralel ölçek yoktur. En küçük metin 11.5 sp'dir (`caption`); bunun altına inen stil tanımlanmaz.
abstract final class BuScale {
  /// Hero (karşılama, büyük sayı/ad): 28-32 aralığı.
  static const double hero = 28;

  /// Büyük sayfa başlığı (giriş ekranı, profil adı): 22-26 aralığı.
  static const double display = 22;

  /// Sayfa/AppBar başlığı.
  static const double title = 18;

  /// Bölüm başlığı, kart başlığı.
  static const double heading = 16;

  /// Büyük gövde (uzun okuma, M3 bodyLarge).
  static const double bodyLarge = 15;

  /// Gövde metni (mesaj, haber özeti, form alanı, liste satırı, düğme).
  static const double body = 14;

  /// Etiket, ikincil satır, çip.
  static const double label = 12.5;

  /// Açıklama, yardımcı metin, saat, rozet: en küçük metin (eski micro + caption birleşti).
  static const double caption = 11.5;
}

/// Uygulamanın tek yazı tipi ve boyut ölçeği. Sayfalarda elle `fontSize` yazılmaz; bu stillerden biri seçilir,
/// renk `copyWith(color: ...)` ile verilir. Satır yüksekliği (height) ölçeğe dahildir.
/// Boyutlar [BuScale]'dendir; yeni kodda `Theme.of(context).textTheme` (aynı ölçek) tercih edilir.
abstract final class BuType {
  /// pubspec.yaml `fonts:` bölümündeki aile adı.
  static const family = 'Inter';

  /// TEK vurgu ağırlığı belirteci. Kullanıcı kararı: kalın yazı YOK (hiyerarşi boyut + renk + boşlukla kurulur),
  /// bu yüzden şimdilik w400. Kodda `FontWeight.w500+` YAZILMAZ; vurgu gereken yerde bu belirteç kullanılır.
  /// Semibold'a dönmek için tek satır: `FontWeight.w600`.
  static const FontWeight emphasisWeight = FontWeight.w400;

  /// Hero başlık (karşılama, büyük sayı).
  static const hero = TextStyle(fontFamily: family, fontSize: BuScale.hero, fontWeight: emphasisWeight, height: 1.2);

  /// Büyük sayfa başlığı (giriş ekranı, profil adı).
  static const display = TextStyle(fontFamily: family, fontSize: BuScale.display, fontWeight: FontWeight.w400, height: 1.25);

  /// Sayfa/AppBar başlığı.
  static const title = TextStyle(fontFamily: family, fontSize: BuScale.title, fontWeight: FontWeight.w400, height: 1.3);

  /// Bölüm başlığı, kart başlığı.
  static const heading = TextStyle(fontFamily: family, fontSize: BuScale.heading, fontWeight: FontWeight.w400, height: 1.3);

  /// Gövde metni (mesaj, haber özeti, form alanı).
  static const body = TextStyle(fontFamily: family, fontSize: BuScale.body, fontWeight: FontWeight.w400, height: 1.4);

  /// Vurgulu gövde (liste satırı başlığı, düğme).
  static const bodyStrong = TextStyle(fontFamily: family, fontSize: BuScale.body, fontWeight: FontWeight.w400, height: 1.4);

  /// Etiket, ikincil satır, çip.
  static const label = TextStyle(fontFamily: family, fontSize: BuScale.label, fontWeight: FontWeight.w400, height: 1.35);

  /// Açıklama, yardımcı metin, saat, rozet; en küçük metin (eski `micro` bununla birleşti;
  /// saat/rozet için `caption.copyWith(fontWeight: FontWeight.w500)`).
  static const caption = TextStyle(fontFamily: family, fontSize: BuScale.caption, fontWeight: FontWeight.w400, height: 1.35);
}
