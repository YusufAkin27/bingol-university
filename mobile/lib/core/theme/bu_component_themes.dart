import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../theme.dart';
import 'bu_shape.dart';
import 'bu_sizes.dart';

/// Material 3 bileşen temaları (marka belirteçleriyle). Yalnız `BuThemeBuilder` kullanır.
///
/// İlke: düğme renkleri ColorScheme'den gelir (`FilledButton` = primary, `.tonal` = secondaryContainer);
/// temada yalnız şekil, boyut ve yazı stili verilir. Böylece tonal/outlined/text varyantları birbirini ezmez.
class BuComponentThemes {
  const BuComponentThemes(this.t, this.cs, this.tx);

  final BuTokens t;
  final ColorScheme cs;
  final TextTheme tx;

  TextStyle get _label => tx.labelLarge!.copyWith(fontWeight: FontWeight.w600);
  TextStyle get _body => tx.bodyMedium!;
  RoundedRectangleBorder get _md => BuRadius.rect(BuRadius.md);
  RoundedRectangleBorder get _ctl => BuRadius.rect(BuRadius.control);

  // --- Düğmeler -----------------------------------------------------------------------------------------

  /// Tam genişlik [BuSize.button] (48 dp, Stitch oranı); satır içi düğmede `minimumSize: Size(0, 48)` verin.
  FilledButtonThemeData get filledButton => FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(BuSize.button),
          shape: _ctl,
          textStyle: _label,
          elevation: 0,
        ),
      );

  OutlinedButtonThemeData get outlinedButton => OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.ink,
          minimumSize: const Size.fromHeight(BuSize.button),
          shape: _ctl,
          side: BorderSide(color: t.bdStrong, width: 1.2),
          textStyle: _label,
        ),
      );

  TextButtonThemeData get textButton => TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.pr,
          minimumSize: const Size(48, 48),
          shape: _md,
          textStyle: _label,
        ),
      );

  ElevatedButtonThemeData get elevatedButton => ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(BuSize.button),
          shape: _ctl,
          textStyle: _label,
          elevation: 1,
          shadowColor: t.shadow,
          backgroundColor: t.sf,
          foregroundColor: t.pr,
        ),
      );

  IconButtonThemeData get iconButton => IconButtonThemeData(
        style: IconButton.styleFrom(iconSize: 20, minimumSize: const Size(BuSize.touch, BuSize.touch)),
      );

  SegmentedButtonThemeData get segmented => SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          side: WidgetStatePropertyAll(BorderSide(color: t.bd, width: 1.2)),
          textStyle: WidgetStatePropertyAll(tx.labelLarge),
          backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.soft : t.sf),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.onSoft : t.ink),
        ),
        selectedIcon: const Icon(Icons.check_rounded, size: 18),
      );

  FloatingActionButtonThemeData get fab => FloatingActionButtonThemeData(
        backgroundColor: t.pr,
        foregroundColor: t.onPr,
        elevation: 2,
        highlightElevation: 3,
        focusElevation: 3,
        hoverElevation: 3,
        shape: BuRadius.rect(BuRadius.md),
        extendedTextStyle: _label,
        sizeConstraints: const BoxConstraints.tightFor(width: BuSize.fab, height: BuSize.fab),
      );

  // --- Gezinme ------------------------------------------------------------------------------------------

  /// M3 NavigationBar: hap gösterge (marka tonu), etiket her zaman görünür.
  NavigationBarThemeData get navigationBar => NavigationBarThemeData(
        height: BuSize.nav,
        backgroundColor: t.sf3,
        surfaceTintColor: Colors.transparent,
        shadowColor: t.shadow,
        elevation: 0,
        indicatorColor: t.soft,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(size: 22, color: s.contains(WidgetState.selected) ? t.onSoft : t.mut),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => tx.labelMedium!.copyWith(
            color: s.contains(WidgetState.selected) ? t.ink : t.mut,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      );

  NavigationRailThemeData get navigationRail => NavigationRailThemeData(
        backgroundColor: t.sf3,
        indicatorColor: t.soft,
        selectedIconTheme: IconThemeData(color: t.onSoft),
        unselectedIconTheme: IconThemeData(color: t.mut),
      );

  /// Küçük başlıkta (collapsed) `titleLarge`; büyük başlıkta `SliverAppBar.large` `headlineMedium` kullanır.
  AppBarTheme get appBar => AppBarTheme(
        toolbarHeight: BuSize.appBar,
        iconTheme: IconThemeData(size: 20, color: t.ink),
        actionsIconTheme: IconThemeData(size: 20, color: t.ink),
        backgroundColor: t.bg,
        foregroundColor: t.ink,
        surfaceTintColor: Colors.transparent,
        shadowColor: t.shadow,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        titleTextStyle: tx.titleLarge!.copyWith(color: t.ink),
        // Durum çubuğu: zemin temaya göre açık/koyu; ikon kontrastı Android (statusBarIconBrightness) ve iOS
        // (statusBarBrightness = zeminin parlaklığı) için ayrı ayrı verilir, iki platformda aynı görünür.
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: cs.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: cs.brightness,
        ),
      );

  TabBarThemeData get tabBar => TabBarThemeData(
        labelColor: t.ink,
        unselectedLabelColor: t.mut,
        labelStyle: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: tx.titleSmall!.copyWith(fontWeight: FontWeight.w500),
        indicatorColor: t.pr,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: t.bd,
        dividerHeight: 1,
        overlayColor: WidgetStatePropertyAll(t.pr.withValues(alpha: .08)),
        splashBorderRadius: BuRadius.bMd,
      );

  // --- Yüzeyler -----------------------------------------------------------------------------------------

  /// Kart: beyaz yüzey + ince çizgi (outlined). Dolgulu/gölgeli varyant için `BuCard(style:)`.
  CardThemeData get card => CardThemeData(
        color: t.sf,
        elevation: 0,
        shadowColor: t.shadow,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: BuRadius.rect(BuRadius.lg, side: BorderSide(color: t.bd)),
      );

  DividerThemeData get divider => DividerThemeData(color: t.bd, space: 1, thickness: 1);

  BottomSheetThemeData get bottomSheet => BottomSheetThemeData(
        backgroundColor: t.sf3,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: t.sf3,
        modalBarrierColor: t.scrim.withValues(alpha: .45),
        shadowColor: t.shadow,
        elevation: 0,
        modalElevation: 0,
        // Tutamaç `BuSheet.show` ile açılır (`showDragHandle: true`); eski elle çizilen tutamaçlı sayfalarda çift çıkmasın.
        showDragHandle: false,
        dragHandleColor: t.mut.withValues(alpha: .45),
        dragHandleSize: const Size(40, 4),
        shape: const RoundedRectangleBorder(borderRadius: BuRadius.topXl),
        clipBehavior: Clip.antiAlias,
        constraints: const BoxConstraints(maxWidth: 640),
      );

  DialogThemeData get dialog => DialogThemeData(
        backgroundColor: t.sf3,
        surfaceTintColor: Colors.transparent,
        shadowColor: t.shadow,
        elevation: 3,
        titleTextStyle: tx.titleLarge!.copyWith(color: t.ink),
        contentTextStyle: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5),
        iconColor: t.pr,
        actionsPadding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: BuRadius.rect(BuRadius.xl),
      );

  SnackBarThemeData get snackBar {
    final inv = cs.brightness == Brightness.light ? BuTokens.dark : BuTokens.light;
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: t.ink,
      contentTextStyle: _body.copyWith(color: t.bg),
      actionTextColor: inv.pr,
      disabledActionTextColor: t.mut,
      elevation: 3,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: _md,
    );
  }

  PopupMenuThemeData get popupMenu => PopupMenuThemeData(
        color: t.sf3,
        surfaceTintColor: Colors.transparent,
        shadowColor: t.shadow,
        elevation: 4,
        textStyle: tx.bodyLarge!.copyWith(color: t.ink),
        shape: BuRadius.rect(BuRadius.md, side: BorderSide(color: t.bd)),
        menuPadding: const EdgeInsets.symmetric(vertical: 6),
      );

  MenuThemeData get menu => MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(t.sf3),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shadowColor: WidgetStatePropertyAll(t.shadow),
          elevation: const WidgetStatePropertyAll(4),
          shape: WidgetStatePropertyAll(BuRadius.rect(BuRadius.md, side: BorderSide(color: t.bd))),
        ),
      );

  DropdownMenuThemeData get dropdownMenu => DropdownMenuThemeData(
        textStyle: tx.bodyLarge!.copyWith(color: t.ink),
        menuStyle: menu.style,
      );

  TooltipThemeData get tooltip => TooltipThemeData(
        decoration: BoxDecoration(color: t.ink, borderRadius: BuRadius.bXs),
        textStyle: tx.labelMedium!.copyWith(color: t.bg),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.all(8),
        waitDuration: const Duration(milliseconds: 500),
        showDuration: const Duration(seconds: 2),
      );

  // --- Girdiler -----------------------------------------------------------------------------------------

  /// Dolgulu + çerçeveli alan; odakta 2 dp marka halkası. Kapsayıcı yarıçap 16.
  InputDecorationTheme get input {
    OutlineInputBorder border(Color c, [double w = 1.2]) =>
        OutlineInputBorder(borderRadius: BuRadius.bControl, borderSide: BorderSide(color: c, width: w));
    return InputDecorationTheme(
      filled: true,
      fillColor: t.sf,
      // Min yükseklik temada VERİLMEZ (isCollapsed/özel yükseklikli alanlar bozulmasın); 15 + bodyLarge satırı ≈ 52 dp.
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: border(t.bdStrong),
      enabledBorder: border(t.bdStrong),
      disabledBorder: border(t.bd),
      focusedBorder: border(t.pr, 2),
      errorBorder: border(t.danger),
      focusedErrorBorder: border(t.danger, 2),
      hintStyle: _body.copyWith(color: t.mut),
      labelStyle: _body.copyWith(color: t.mut),
      floatingLabelStyle: tx.bodySmall!.copyWith(color: t.pr, fontWeight: FontWeight.w600),
      helperStyle: tx.bodySmall!.copyWith(color: t.mut),
      errorStyle: tx.bodySmall!.copyWith(color: t.danger),
      prefixIconColor: t.mut,
      suffixIconColor: t.mut,
    );
  }

  TextSelectionThemeData get textSelection => TextSelectionThemeData(
        cursorColor: t.pr,
        selectionColor: t.pr.withValues(alpha: .28),
        selectionHandleColor: t.pr,
      );

  SearchBarThemeData get searchBar => SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(t.sf),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: WidgetStatePropertyAll(t.shadow),
        constraints: const BoxConstraints(minHeight: BuSize.search),
        padding: const WidgetStatePropertyAll(EdgeInsetsDirectional.symmetric(horizontal: 16)),
        shape: WidgetStatePropertyAll(StadiumBorder(side: BorderSide(color: t.bdStrong, width: 1.2))),
        textStyle: WidgetStatePropertyAll(tx.bodyLarge!.copyWith(color: t.ink)),
        hintStyle: WidgetStatePropertyAll(tx.bodyLarge!.copyWith(color: t.mut)),
      );

  SearchViewThemeData get searchView => SearchViewThemeData(
        backgroundColor: t.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        headerHeight: 60,
        dividerColor: t.bd,
        shape: const RoundedRectangleBorder(),
        headerTextStyle: tx.bodyLarge!.copyWith(color: t.ink),
        headerHintStyle: tx.bodyLarge!.copyWith(color: t.mut),
      );

  // --- Seçim kontrolleri --------------------------------------------------------------------------------

  /// M3 anahtar: seçili = marka dolgu + büyük başparmak; seçili değil = 2 dp çerçeveli iz (3:1 kontrast, WCAG 1.4.11).
  SwitchThemeData get switcher => SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return t.mut.withValues(alpha: .5);
          return s.contains(WidgetState.selected) ? t.onPr : t.mut;
        }),
        trackColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return t.sf2;
          return s.contains(WidgetState.selected) ? t.pr : t.sf2;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.transparent : t.mut,
        ),
        trackOutlineWidth: const WidgetStatePropertyAll(1.6),
        overlayColor: WidgetStatePropertyAll(t.pr.withValues(alpha: .10)),
        materialTapTargetSize: MaterialTapTargetSize.padded,
      );

  CheckboxThemeData get checkbox => CheckboxThemeData(
        shape: BuRadius.rect(7),
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.pr : Colors.transparent),
        checkColor: WidgetStatePropertyAll(t.onPr),
        // İşaretsiz kutu zeminde kaybolmasın (WCAG 1.4.11): çerçeve soluk yazı renginde.
        side: WidgetStateBorderSide.resolveWith(
          (s) => BorderSide(color: s.contains(WidgetState.selected) ? t.pr : t.mut, width: 2),
        ),
        overlayColor: WidgetStatePropertyAll(t.pr.withValues(alpha: .10)),
      );

  RadioThemeData get radio => RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.pr : t.mut),
        overlayColor: WidgetStatePropertyAll(t.pr.withValues(alpha: .10)),
      );

  SliderThemeData get slider => SliderThemeData(
        activeTrackColor: t.pr,
        inactiveTrackColor: t.sf2,
        thumbColor: t.pr,
        overlayColor: t.pr.withValues(alpha: .12),
        valueIndicatorColor: t.ink,
        valueIndicatorTextStyle: tx.labelMedium!.copyWith(color: t.bg),
        trackHeight: 4,
      );

  ProgressIndicatorThemeData get progress => ProgressIndicatorThemeData(
        color: t.pr,
        linearTrackColor: t.sf2,
        circularTrackColor: Colors.transparent,
        refreshBackgroundColor: t.sf3,
      );

  BadgeThemeData get badge => BadgeThemeData(
        backgroundColor: t.pr,
        textColor: t.onPr,
        smallSize: 8,
        largeSize: 18,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        textStyle: tx.labelSmall!.copyWith(fontWeight: FontWeight.w700),
      );

  // --- Çip ve liste -------------------------------------------------------------------------------------

  /// Filtre/seçim/giriş/yardım çipi: hap şekli, seçili = marka tonu (onay işareti yok; renk + ağırlık ayırır).
  ChipThemeData get chip => ChipThemeData(
        backgroundColor: t.sf,
        selectedColor: t.soft,
        disabledColor: t.sf2,
        surfaceTintColor: Colors.transparent,
        side: BorderSide(color: t.bd),
        shape: const StadiumBorder(),
        labelStyle: tx.labelLarge!.copyWith(color: t.mut),
        secondaryLabelStyle: tx.labelLarge!.copyWith(color: t.onSoft),
        iconTheme: IconThemeData(size: 18, color: t.mut),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        elevation: 0,
        pressElevation: 0,
      );

  ListTileThemeData get listTile => ListTileThemeData(
        contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
        minVerticalPadding: 8,
        minTileHeight: BuSize.row,
        horizontalTitleGap: 14,
        minLeadingWidth: 24,
        iconColor: t.mut,
        textColor: t.ink,
        titleTextStyle: tx.bodyLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w600),
        subtitleTextStyle: tx.bodyMedium!.copyWith(color: t.mut),
        leadingAndTrailingTextStyle: tx.labelMedium!.copyWith(color: t.mut),
        selectedColor: t.onSoft,
        selectedTileColor: t.soft,
        shape: BuRadius.rect(BuRadius.md),
      );

  ExpansionTileThemeData get expansionTile => ExpansionTileThemeData(
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        iconColor: t.pr,
        collapsedIconColor: t.mut,
        textColor: t.ink,
        collapsedTextColor: t.ink,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
      );

  // --- Seçiciler ----------------------------------------------------------------------------------------

  DatePickerThemeData get datePicker => DatePickerThemeData(
        backgroundColor: t.sf3,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shadowColor: t.shadow,
        shape: BuRadius.rect(BuRadius.xl),
        headerBackgroundColor: Colors.transparent,
        headerForegroundColor: t.ink,
        dividerColor: t.bd,
        todayForegroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.onPr : t.pr),
        todayBorder: BorderSide(color: t.pr),
        dayForegroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return t.onPr;
          if (s.contains(WidgetState.disabled)) return t.mut.withValues(alpha: .5);
          return t.ink;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.pr : Colors.transparent,
        ),
        yearForegroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.onPr : t.ink,
        ),
        yearBackgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.pr : Colors.transparent,
        ),
        rangePickerBackgroundColor: t.sf3,
        rangeSelectionBackgroundColor: t.soft,
        rangePickerHeaderForegroundColor: t.ink,
        confirmButtonStyle: TextButton.styleFrom(foregroundColor: t.pr, minimumSize: const Size(64, 48)),
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: t.mut, minimumSize: const Size(64, 48)),
      );

  TimePickerThemeData get timePicker => TimePickerThemeData(
        backgroundColor: t.sf3,
        shape: BuRadius.rect(BuRadius.xl),
        hourMinuteShape: BuRadius.rect(BuRadius.md),
        dayPeriodShape: BuRadius.rect(BuRadius.md),
        hourMinuteColor: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.selected) ? t.soft : t.sf2),
        hourMinuteTextColor: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.selected) ? t.onSoft : t.ink),
        dayPeriodColor: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.selected) ? t.soft : t.sf3),
        dayPeriodTextColor: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.selected) ? t.onSoft : t.mut),
        dayPeriodBorderSide: BorderSide(color: t.bd),
        dialBackgroundColor: t.sf2,
        dialHandColor: t.pr,
        dialTextColor: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.selected) ? t.onPr : t.ink),
        entryModeIconColor: t.mut,
        confirmButtonStyle: TextButton.styleFrom(foregroundColor: t.pr, minimumSize: const Size(64, 48)),
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: t.mut, minimumSize: const Size(64, 48)),
      );
}
