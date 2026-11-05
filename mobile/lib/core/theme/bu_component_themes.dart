import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../theme.dart';
import 'bu_shape.dart';
import 'bu_sizes.dart';
import '../icons/bu_icons.dart';
import '../typography.dart';

/// Material 3 bileşen temaları (marka belirteçleriyle). Yalnız `BuThemeBuilder` kullanır.
///
/// İlke: düğme renkleri ColorScheme'den gelir (`FilledButton` = primary, `.tonal` = secondaryContainer);
/// temada yalnız şekil, boyut ve yazı stili verilir. Böylece tonal/outlined/text varyantları birbirini ezmez.
class BuComponentThemes {
  const BuComponentThemes(this.t, this.cs, this.tx);

  final BuTokens t;
  final ColorScheme cs;
  final TextTheme tx;

  TextStyle get _label => tx.labelLarge!.copyWith(fontWeight: BuType.emphasisWeight);
  TextStyle get _body => tx.bodyMedium!;
  RoundedRectangleBorder get _md => BuRadius.rect(BuRadius.md);
  RoundedRectangleBorder get _ctl => BuRadius.rect(BuRadius.control);

  // --- Düğmeler -----------------------------------------------------------------------------------------

  /// Tam genişlik [BuSize.button] (48 dp, Stitch oranı); satır içi düğmede `minimumSize: Size(0, 48)` verin.
  /// Birincil düğme: koyuda beyaz zemin + siyah yazı, açıkta siyah zemin + beyaz yazı; devre dışı = `bd` zemin.
  FilledButtonThemeData get filledButton => FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(BuSize.button),
          shape: _ctl,
          textStyle: _label,
          elevation: 0,
        ),
      );

  /// İkincil düğme: şeffaf zemin + ince kenarlık.
  OutlinedButtonThemeData get outlinedButton => OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.ink,
          minimumSize: const Size.fromHeight(BuSize.button),
          shape: _ctl,
          side: BorderSide(color: t.bd),
          textStyle: _label,
        ),
      );

  TextButtonThemeData get textButton => TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.ink,
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
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: t.pr,
          foregroundColor: t.onPr,
          disabledBackgroundColor: t.bd,
          disabledForegroundColor: t.mutSoft,
        ),
      );

  IconButtonThemeData get iconButton => IconButtonThemeData(
        style: IconButton.styleFrom(iconSize: 20, minimumSize: const Size(BuSize.touch, BuSize.touch)),
      );

  SegmentedButtonThemeData get segmented => SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          shape: WidgetStatePropertyAll(_ctl),
          side: WidgetStatePropertyAll(BorderSide(color: t.bd)),
          textStyle: WidgetStatePropertyAll(tx.labelLarge),
          backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.pr : t.sf),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.onPr : t.ink),
        ),
        selectedIcon: const Icon(BuIcons.check, size: 18),
      );

  FloatingActionButtonThemeData get fab => FloatingActionButtonThemeData(
        backgroundColor: t.pr,
        foregroundColor: t.onPr,
        elevation: 0,
        highlightElevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        shape: BuRadius.rect(BuRadius.md),
        extendedTextStyle: _label,
        sizeConstraints: const BoxConstraints.tightFor(width: BuSize.fab, height: BuSize.fab),
      );

  // --- Gezinme ------------------------------------------------------------------------------------------

  /// M3 NavigationBar: gösterge/hap yok; aktif simge `ink`, pasif `mut`.
  NavigationBarThemeData get navigationBar => NavigationBarThemeData(
        height: BuSize.nav,
        backgroundColor: t.sf,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        indicatorColor: Colors.transparent,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(size: 22, color: s.contains(WidgetState.selected) ? t.ink : t.mut),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => tx.labelMedium!.copyWith(color: s.contains(WidgetState.selected) ? t.ink : t.mut),
        ),
      );

  NavigationRailThemeData get navigationRail => NavigationRailThemeData(
        backgroundColor: t.sf,
        indicatorColor: Colors.transparent,
        selectedIconTheme: IconThemeData(color: t.ink),
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
        labelStyle: tx.titleSmall!.copyWith(fontWeight: BuType.emphasisWeight),
        unselectedLabelStyle: tx.titleSmall!.copyWith(fontWeight: BuType.emphasisWeight),
        indicatorColor: t.ink,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: t.bd,
        dividerHeight: 1,
        overlayColor: WidgetStatePropertyAll(t.ink.withValues(alpha: .06)),
        splashBorderRadius: BuRadius.bMd,
      );

  // --- Yüzeyler -----------------------------------------------------------------------------------------

  /// Kart: `sf` yüzey + ince çizgi (outlined), radius 16, gölge yok. Gölgeli varyant için `BuCard(style:)`.
  CardThemeData get card => CardThemeData(
        color: t.sf,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: BuRadius.rect(BuRadius.md, side: BorderSide(color: t.bd)),
      );

  DividerThemeData get divider => DividerThemeData(color: t.bd, space: 1, thickness: 1);

  BottomSheetThemeData get bottomSheet => BottomSheetThemeData(
        backgroundColor: t.sf3,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: t.sf3,
        modalBarrierColor: t.scrim.withValues(alpha: .5),
        shadowColor: Colors.transparent,
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
        shadowColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: tx.titleLarge!.copyWith(color: t.ink),
        contentTextStyle: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5),
        iconColor: t.ink,
        actionsPadding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: BuRadius.rect(BuRadius.lg, side: BorderSide(color: t.bd)),
      );

  /// Bildirim şeridi: yükseltilmiş yüzey (`sf3`) + ince kenarlık + `ink` yazı (iki temada da okunur).
  SnackBarThemeData get snackBar => SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.sf3,
        contentTextStyle: _body.copyWith(color: t.ink),
        actionTextColor: t.ink,
        disabledActionTextColor: t.mut,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: BuRadius.rect(BuRadius.control, side: BorderSide(color: t.bd)),
      );

  PopupMenuThemeData get popupMenu => PopupMenuThemeData(
        color: t.sf3,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        textStyle: tx.bodyLarge!.copyWith(color: t.ink),
        shape: BuRadius.rect(BuRadius.control, side: BorderSide(color: t.bd)),
        menuPadding: const EdgeInsets.symmetric(vertical: 6),
      );

  MenuThemeData get menu => MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(t.sf3),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
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
      focusedBorder: border(t.ink, 1.6),
      errorBorder: border(t.danger),
      focusedErrorBorder: border(t.danger, 2),
      hintStyle: _body.copyWith(color: t.mut),
      labelStyle: _body.copyWith(color: t.mut),
      floatingLabelStyle: tx.bodySmall!.copyWith(color: t.ink, fontWeight: BuType.emphasisWeight),
      helperStyle: tx.bodySmall!.copyWith(color: t.mut),
      errorStyle: tx.bodySmall!.copyWith(color: t.danger),
      prefixIconColor: t.mut,
      suffixIconColor: t.mut,
    );
  }

  TextSelectionThemeData get textSelection => TextSelectionThemeData(
        cursorColor: t.ink,
        selectionColor: t.ink.withValues(alpha: .22),
        selectionHandleColor: t.ink,
      );

  SearchBarThemeData get searchBar => SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(t.sf),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        constraints: const BoxConstraints(minHeight: BuSize.search),
        padding: const WidgetStatePropertyAll(EdgeInsetsDirectional.symmetric(horizontal: 16)),
        shape: WidgetStatePropertyAll(BuRadius.rect(BuRadius.control, side: BorderSide(color: t.bdStrong))),
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
        overlayColor: WidgetStatePropertyAll(t.ink.withValues(alpha: .08)),
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
        overlayColor: WidgetStatePropertyAll(t.ink.withValues(alpha: .08)),
      );

  RadioThemeData get radio => RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.pr : t.mut),
        overlayColor: WidgetStatePropertyAll(t.ink.withValues(alpha: .08)),
      );

  SliderThemeData get slider => SliderThemeData(
        activeTrackColor: t.pr,
        inactiveTrackColor: t.sf2,
        thumbColor: t.pr,
        overlayColor: t.ink.withValues(alpha: .10),
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
        textStyle: tx.labelSmall!.copyWith(fontWeight: BuType.emphasisWeight),
      );

  // --- Çip ve liste -------------------------------------------------------------------------------------

  /// Filtre/seçim/giriş/yardım çipi: seçili = TERS RENK (`pr` zemin + `onPr` yazı; onay işareti yok).
  ChipThemeData get chip => ChipThemeData(
        backgroundColor: t.sf,
        selectedColor: t.pr,
        disabledColor: t.sf2,
        surfaceTintColor: Colors.transparent,
        side: BorderSide(color: t.bd),
        shape: const StadiumBorder(),
        labelStyle: tx.labelLarge!.copyWith(color: t.mut),
        secondaryLabelStyle: tx.labelLarge!.copyWith(color: t.onPr),
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
        titleTextStyle: tx.bodyLarge!.copyWith(color: t.ink, fontWeight: BuType.emphasisWeight),
        subtitleTextStyle: tx.bodyMedium!.copyWith(color: t.mut),
        leadingAndTrailingTextStyle: tx.labelMedium!.copyWith(color: t.mut),
        selectedColor: t.onSoft,
        selectedTileColor: t.soft,
        shape: BuRadius.rect(BuRadius.md),
      );

  ExpansionTileThemeData get expansionTile => ExpansionTileThemeData(
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        iconColor: t.ink,
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
