import 'package:flutter/widgets.dart';

/// Uygulamanın TEK yazı boyutu ölçeği (K-21, T-113). Hem `BuType` hem `BuTextTheme` (M3 TextTheme) boyutlarını
/// buradan alır; iki paralel ölçek yoktur. En küçük metin 11.5 sp'dir (`caption`); bunun altına inen stil tanımlanmaz.
abstract final class BuScale {
  /// Büyük sayfa başlığı (giriş ekranı, profil adı).
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

  // --- Geçiş jetonları (HIG-P1, karar D-1) -----------------------------------------------------------------------
  // Eskiden elle yazılan `fontSize: 13` vb. değerlerin jeton karşılığıdır; GÖRÜNÜM DEĞİŞMEZ. Yeni tasarımda önce yukarıdaki
  // anlamlı basamaklar (display..caption) seçilir; bunlar yalnız mevcut ekranların boyutunu korumak içindir. Eşleme tablosu:
  // docs/MOBILE_HIG_AUDIT.md "P1 jeton eşleme tablosu". Ölçek 11 sp tabanının altına inen jeton YOKTUR (K-21).

  /// 11 sp (tek kullanım; yeni kodda [caption] 11.5 tercih edin).
  static const double s11 = 11;

  /// 12 sp (etiket altı yardımcı satır).
  static const double s12 = 12;

  /// 13 sp (liste ikincil satırı, çip; en sık kullanılan geçiş değeri).
  static const double s13 = 13;

  /// 13,5 sp.
  static const double s135 = 13.5;

  /// 17 sp (vurgulu satır başlığı).
  static const double s17 = 17;

  /// 19 sp.
  static const double s19 = 19;

  /// 20 sp (büyük sayı/başlık).
  static const double s20 = 20;

  /// 26 sp (sayfa üst başlığı, [BuHeader]).
  static const double s26 = 26;

  /// 28 sp (büyük sayaç).
  static const double s28 = 28;

  /// 88 sp (dev rakam/görsel yer tutucu).
  static const double s88 = 88;
}

/// Kalın yazı erişilebilirliği (`MediaQuery.boldText`: iOS "Kalın Metin", Android "Kalın yazı tipi").
///
/// `Text` ve `TextField` Flutter içinde bu ayarı ZATEN uygular (ağırlığı `bold` yapar); yani ekran metni için ek iş yoktur.
/// Bu yardımcı, çerçevenin dokunmadığı yerler içindir: `TextPainter`/`CustomPainter` ile ölçülen ya da çizilen metin
/// (ölçüm ile gerçek çizim aynı ağırlığı kullansın). Çerçeveyle aynı kural: ağırlık 700'ün altındaysa `bold`'a çıkar.
abstract final class BuBold {
  static bool of(BuildContext context) => MediaQuery.boldTextOf(context);

  /// [w] ağırlığını ayara göre döndürür (kapalıyken değişmez).
  static FontWeight weight(BuildContext context, FontWeight w) => of(context) && w.value < FontWeight.bold.value ? FontWeight.bold : w;

  /// [s] stilini ayara göre döndürür (kapalıyken aynı örnek).
  static TextStyle style(BuildContext context, TextStyle s) {
    if (!of(context)) return s;
    final w = s.fontWeight ?? FontWeight.w400;
    return w.value < FontWeight.bold.value ? s.copyWith(fontWeight: FontWeight.bold) : s;
  }
}

/// Uygulamanın tek yazı tipi ve boyut ölçeği. Sayfalarda elle `fontSize` yazılmaz; bu stillerden biri seçilir,
/// renk `copyWith(color: ...)` ile verilir. Satır yüksekliği (height) ölçeğe dahildir.
/// Boyutlar [BuScale]'dendir; yeni kodda `Theme.of(context).textTheme` (aynı ölçek) tercih edilir.
abstract final class BuType {
  /// pubspec.yaml `fonts:` bölümündeki aile adı.
  static const family = 'Inter';

  /// Büyük sayfa başlığı (giriş ekranı, profil adı).
  static const display = TextStyle(fontFamily: family, fontSize: BuScale.display, fontWeight: FontWeight.w700, height: 1.25);

  /// Sayfa/AppBar başlığı.
  static const title = TextStyle(fontFamily: family, fontSize: BuScale.title, fontWeight: FontWeight.w700, height: 1.3);

  /// Bölüm başlığı, kart başlığı.
  static const heading = TextStyle(fontFamily: family, fontSize: BuScale.heading, fontWeight: FontWeight.w700, height: 1.3);

  /// Gövde metni (mesaj, haber özeti, form alanı).
  static const body = TextStyle(fontFamily: family, fontSize: BuScale.body, fontWeight: FontWeight.w400, height: 1.4);

  /// Vurgulu gövde (liste satırı başlığı, düğme).
  static const bodyStrong = TextStyle(fontFamily: family, fontSize: BuScale.body, fontWeight: FontWeight.w600, height: 1.4);

  /// Etiket, ikincil satır, çip.
  static const label = TextStyle(fontFamily: family, fontSize: BuScale.label, fontWeight: FontWeight.w600, height: 1.35);

  /// Açıklama, yardımcı metin, saat, rozet; en küçük metin (eski `micro` bununla birleşti;
  /// saat/rozet için `caption.copyWith(fontWeight: FontWeight.w500)`).
  static const caption = TextStyle(fontFamily: family, fontSize: BuScale.caption, fontWeight: FontWeight.w400, height: 1.35);
}
