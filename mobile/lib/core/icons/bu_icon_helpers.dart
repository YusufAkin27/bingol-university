import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'bu_icons.dart';

/// Sağdan sola (RTL) düzende yön belirten simgeyi aynalar; diğerlerine dokunmaz.
///
/// `bu_widgets.dart` içindeki `buDirIcon` ile aynı davranış; 2. fazda o işlev bunu çağıracak.
/// Geçiş döneminde hem [BuIcons] hem de eski Lucide sabitlerini tanır.
/// Yazı tipi glifini `matchTextDirection` ile OTOMATİK aynalamak bilinçli olarak kullanılmaz:
/// mevcut kod çiftleri elle değiştirir, ikisi birden çalışırsa ikon yeniden eski yöne döner.
IconData buIconDirection(BuildContext context, IconData icon) {
  if (Directionality.of(context) != TextDirection.rtl) return icon;
  return buMirrorIcon(icon);
}

/// RTL aynalama çiftleri (geri/ileri ok ve chevron). Çift dışı simge aynen döner.
IconData buMirrorIcon(IconData icon) {
  if (icon == BuIcons.arrowLeft) return BuIcons.arrowRight;
  if (icon == BuIcons.arrowRight) return BuIcons.arrowLeft;
  if (icon == BuIcons.chevronLeft) return BuIcons.chevronRight;
  if (icon == BuIcons.chevronRight) return BuIcons.chevronLeft;
  // Geçiş dönemi: henüz taşınmamış Lucide kullanımları.
  if (icon == LucideIcons.arrowLeft) return LucideIcons.arrowRight;
  if (icon == LucideIcons.arrowRight) return LucideIcons.arrowLeft;
  if (icon == LucideIcons.chevronLeft) return LucideIcons.chevronRight;
  if (icon == LucideIcons.chevronRight) return LucideIcons.chevronLeft;
  return icon;
}

/// İkon boyutu önerileri (dp). Glifler 24 dp ızgarada çizilir (1.75 çizgi); çok küçük boyutta
/// ince çizgi silikleşir. Bu değerler zorunlu değil, `bu_icons_test.dart` ölçümüne dayanır.
abstract final class BuIconSize {
  /// Bunun altında çizgi gözle zorlukla seçilir (belge: Hugeicons Lucide'den ince).
  static const double minLegible = 14;
  static const double small = 16;
  static const double regular = 20;
  static const double large = 24;
}
