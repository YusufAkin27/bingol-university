import 'package:flutter/material.dart';

import '../theme.dart';
import 'bu_color_scheme.dart';
import 'bu_component_themes.dart';
import 'bu_page_transitions.dart';
import 'bu_text_theme.dart';

/// `ThemeData(useMaterial3: true)` kurucusu: renk şeması + yazı ölçeği + tüm bileşen temaları.
/// Doğrudan çağrılmaz; `BuTheme.light()/dark()` kullanın (önbellekli).
abstract final class BuThemeBuilder {
  static ThemeData build(BuTokens t, Brightness b, {bool arabic = false}) {
    final cs = BuColorScheme.build(t, b);
    final tx = BuTextTheme.build(t, arabic: arabic);
    final c = BuComponentThemes(t, cs, tx);
    return ThemeData(
      useMaterial3: true,
      fontFamily: BuTheme.fontFamily,
      brightness: b,
      colorScheme: cs,
      textTheme: tx,
      extensions: [t],
      scaffoldBackgroundColor: t.bg,
      dividerColor: t.bd,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: BuPageTransitions.theme,
      // Simgeler varsayılan 24 yerine 21.6 (%10 küçük); dokunma alanı Material varsayılanında kalır.
      iconTheme: IconThemeData(size: 21.6, color: t.ink),
      iconButtonTheme: c.iconButton,
      appBarTheme: c.appBar,
      cardTheme: c.card,
      dividerTheme: c.divider,
      inputDecorationTheme: c.input,
      filledButtonTheme: c.filledButton,
      outlinedButtonTheme: c.outlinedButton,
      textButtonTheme: c.textButton,
      elevatedButtonTheme: c.elevatedButton,
      segmentedButtonTheme: c.segmented,
      floatingActionButtonTheme: c.fab,
      navigationBarTheme: c.navigationBar,
      navigationRailTheme: c.navigationRail,
      tabBarTheme: c.tabBar,
      chipTheme: c.chip,
      searchBarTheme: c.searchBar,
      searchViewTheme: c.searchView,
      bottomSheetTheme: c.bottomSheet,
      dialogTheme: c.dialog,
      snackBarTheme: c.snackBar,
      listTileTheme: c.listTile,
      expansionTileTheme: c.expansionTile,
      switchTheme: c.switcher,
      checkboxTheme: c.checkbox,
      radioTheme: c.radio,
      sliderTheme: c.slider,
      progressIndicatorTheme: c.progress,
      badgeTheme: c.badge,
      tooltipTheme: c.tooltip,
      popupMenuTheme: c.popupMenu,
      menuTheme: c.menu,
      dropdownMenuTheme: c.dropdownMenu,
      datePickerTheme: c.datePicker,
      timePickerTheme: c.timePicker,
      textSelectionTheme: c.textSelection,
      // InkSparkle (shader) yerine InkRipple: düşük sınıf cihazda ilk dokunuş takılması olmaz.
      splashFactory: InkRipple.splashFactory,
      applyElevationOverlayColor: false,
      bannerTheme: MaterialBannerThemeData(
        backgroundColor: t.warnSoft,
        contentTextStyle: tx.bodyMedium?.copyWith(color: t.onWarnSoft),
        dividerColor: Colors.transparent,
      ),
    );
  }
}
