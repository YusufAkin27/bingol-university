import 'package:flutter/material.dart';

/// Marka renkleri: web/src/styles/tokens.css ile aynı değerler (Kampüs Kırmızısı + lacivert mürekkep).
class BuColors {
  BuColors._();

  static const ink = Color(0xFF171E33);
  static const red600 = Color(0xFFF73A2E); // logo kırmızısı: büyük yüzeyler, hero
  static const red700 = Color(0xFFC62A20); // eylem kırmızısı: düğme/bağlantı
  static const red800 = Color(0xFF8E1B13);
  static const red100 = Color(0xFFFDE7E4);
}

/// Tasarım belirteçleri (mobile/design/*.dc.html içindeki CSS değişkenleriyle birebir).
/// Kullanım: `final t = context.bu;` sonra `t.pr`, `t.sf`, `t.mut`...
@immutable
class BuTokens extends ThemeExtension<BuTokens> {
  const BuTokens({
    required this.bg,
    required this.sf,
    required this.sf2,
    required this.ink,
    required this.mut,
    required this.bd,
    required this.pr,
    required this.onPr,
    required this.soft,
    required this.onSoft,
    required this.nav,
    required this.onNav,
    required this.h1,
    required this.h2,
    required this.ok,
    required this.okSoft,
    required this.danger,
  });

  final Color bg; // sayfa zemini
  final Color sf; // kart/yüzey
  final Color sf2; // ikincil yüzey (segment, görsel yer tutucu)
  final Color ink; // ana yazı
  final Color mut; // soluk yazı
  final Color bd; // çizgi
  final Color pr; // eylem kırmızısı
  final Color onPr; // pr üstündeki yazı
  final Color soft; // pr'nin yumuşak zemini
  final Color onSoft; // soft üstündeki yazı
  final Color nav; // yüzen gezinme zemini
  final Color onNav;
  final Color h1; // hero gradyan başı
  final Color h2; // hero gradyan sonu
  final Color ok;
  final Color okSoft;
  final Color danger;

  LinearGradient get hero => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [h1, h2],
      );

  static const light = BuTokens(
    bg: Color(0xFFFAF6F3),
    sf: Color(0xFFFFFFFF),
    sf2: Color(0xFFF3ECE7),
    ink: Color(0xFF171E33),
    mut: Color(0xFF5F6577),
    bd: Color(0xFFE8DFD8),
    pr: Color(0xFFC62A20),
    onPr: Color(0xFFFFFFFF),
    soft: Color(0xFFFDE7E4),
    onSoft: Color(0xFF8E1B13),
    nav: Color(0xFF171E33),
    onNav: Color(0xFFFFFFFF),
    h1: Color(0xFFF73A2E),
    h2: Color(0xFFC62A20),
    ok: Color(0xFF1B7A4B),
    okSoft: Color(0xFFDFF3E8),
    danger: Color(0xFFB3261E),
  );

  static const dark = BuTokens(
    bg: Color(0xFF14161F),
    sf: Color(0xFF1D2030),
    sf2: Color(0xFF24283A),
    ink: Color(0xFFF4EFEB),
    mut: Color(0xFFA5A9BA),
    bd: Color(0xFF2E3247),
    pr: Color(0xFFFF6A5F),
    onPr: Color(0xFF1A0907),
    soft: Color(0xFF3A1F22),
    onSoft: Color(0xFFFFB4AC),
    nav: Color(0xFF232738),
    onNav: Color(0xFFF4EFEB),
    h1: Color(0xFFC62A20),
    h2: Color(0xFF9E1F17),
    ok: Color(0xFF5FD596),
    okSoft: Color(0xFF11301F),
    danger: Color(0xFFFF8A82),
  );

  @override
  BuTokens copyWith() => this;

  @override
  BuTokens lerp(ThemeExtension<BuTokens>? other, double t) => t < 0.5 ? this : (other as BuTokens? ?? this);
}

extension BuThemeX on BuildContext {
  BuTokens get bu => Theme.of(this).extension<BuTokens>()!;
}

class BuTheme {
  BuTheme._();

  static const fontFamily = null; // sistem yazı tipi (iOS: SF Pro). Gerekirse paketlenmiş font eklenir.

  static ThemeData light() => _build(BuTokens.light, Brightness.light);
  static ThemeData dark() => _build(BuTokens.dark, Brightness.dark);

  static ThemeData _build(BuTokens t, Brightness b) {
    final cs = ColorScheme(
      brightness: b,
      primary: t.pr,
      onPrimary: t.onPr,
      primaryContainer: t.soft,
      onPrimaryContainer: t.onSoft,
      secondary: t.ink,
      onSecondary: t.bg,
      error: t.danger,
      onError: Colors.white,
      errorContainer: b == Brightness.light ? const Color(0xFFFBE3E1) : const Color(0xFF3B1816),
      onErrorContainer: t.danger,
      surface: t.sf,
      onSurface: t.ink,
      onSurfaceVariant: t.mut,
      surfaceContainerHighest: t.sf2,
      outline: t.mut,
      outlineVariant: t.bd,
    );
    final radius = BorderRadius.circular(14);
    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: c, width: w));

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: cs,
      extensions: [t],
      scaffoldBackgroundColor: t.bg,
      appBarTheme: AppBarTheme(
        backgroundColor: t.bg,
        foregroundColor: t.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: t.sf,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: t.bd)),
      ),
      dividerTheme: DividerThemeData(color: t.bd, space: 1, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.sf,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: border(t.bd),
        enabledBorder: border(t.bd),
        focusedBorder: border(t.pr, 2),
        errorBorder: border(t.danger),
        focusedErrorBorder: border(t.danger, 2),
        hintStyle: TextStyle(color: t.mut),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.pr,
          foregroundColor: t.onPr,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.ink,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: radius),
          side: BorderSide(color: t.bd),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.pr,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.onPr : Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.pr : t.sf2),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.pr : Colors.transparent),
        checkColor: WidgetStatePropertyAll(t.onPr),
        side: BorderSide(color: t.bd, width: 2),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.ink,
        contentTextStyle: TextStyle(color: t.bg),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.sf,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
