import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/theme/bu_motion.dart';
import 'package:bu_kampus/features/chat/chatlist_widgets.dart' show ChatlistAvatar;
import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:bu_kampus/features/shell/floating_nav.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:bu_kampus/widgets/bu_list.dart' show BuCountBadge;
import 'package:bu_kampus/widgets/bu_pressable.dart' show BuHaptic, buHaptic;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_parsing/path_parsing.dart';

import '../support/fake_app.dart';
import '../support/store_shots_images.dart';

/// NAV-DESIGN (yon secildi): iOS tarzi yuzen "cam" hap, 5 sekme YALNIZ ikon, secili sekmenin arkasinda kayan oval,
/// secili ikon DOLU (Lucide geometrisi, ayni aile). Iki vurgu varyanti:
///   K = kirmizi tint oval (t.soft) + kirmizi dolu ikon, N = notr oval + kirmizi dolu ikon.
/// Yalniz prototip (uretim koduna dokunmaz). Uretim:
///   NAV_OUT='C:/bu_qa/shots/tasarim/nav' flutter test test/redesign/nav_secenek_shots_test.dart
/// Olcum/erisilebilirlik testleri (NAV_OUT'suz) her kosuda calisir.

enum NavVariant { k, n }

enum BadgeMode { count, dot }

// =================================================================================================================
// Lucide geometrisi (lucide_icons_flutter 4.0.1 kaynak SVG'leri; 24x24, cizgi 2): dolu hali icin yol verisi
// =================================================================================================================

class _PathSink implements PathProxy {
  _PathSink(this.path);
  final Path path;
  @override
  void moveTo(double x, double y) => path.moveTo(x, y);
  @override
  void lineTo(double x, double y) => path.lineTo(x, y);
  @override
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) =>
      path.cubicTo(x1, y1, x2, y2, x3, y3);
  @override
  void close() => path.close();
}

Path _svg(String d) {
  final p = Path();
  writeSvgPathDataToPath(d, _PathSink(p));
  return p;
}

/// Bir ikon: [solid] kapali govde (dolgu + cizgi), [detail] ic ayrinti (dolu halde oval renginde "oyuk"),
/// [lines] yalniz cizgi (dolgusuz) parcalar.
class _Glyph {
  _Glyph({this.solid = const [], this.detail = const [], this.lines = const [], this.detailFilled = false});
  final List<Path> solid;
  final List<Path> detail;
  final List<Path> lines;

  /// true: ayrinti dolu halde de dolgulu oyuk (pusula ibresi); false: dolu halde cizgi oyuk (ev kapisi).
  final bool detailFilled;
}

final List<_Glyph> _glyphs = [
  // house
  _Glyph(
    solid: [
      _svg('M3 10a2 2 0 0 1 .709-1.528l7-6a2 2 0 0 1 2.582 0l7 6A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z')
    ],
    detail: [_svg('M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8')],
  ),
  // compass
  _Glyph(
    solid: [Path()..addOval(const Rect.fromLTRB(2, 2, 22, 22))],
    detail: [_svg('m16.24 7.76-1.804 5.411a2 2 0 0 1-1.265 1.265L7.76 16.24l1.804-5.411a2 2 0 0 1 1.265-1.265z')],
    detailFilled: true,
  ),
  // message-circle
  _Glyph(
    solid: [
      _svg(
          'M2.992 16.342a2 2 0 0 1 .094 1.167l-1.065 3.29a1 1 0 0 0 1.236 1.168l3.413-.998a2 2 0 0 1 1.099.092 10 10 0 1 0-4.777-4.719')
    ],
  ),
  // users
  _Glyph(
    solid: [
      Path()..addOval(const Rect.fromLTRB(5, 3, 13, 11)),
      _svg('M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2z'),
    ],
    lines: [_svg('M16 3.128a4 4 0 0 1 0 7.744'), _svg('M22 21v-2a4 4 0 0 0-3-3.87')],
  ),
];

/// Lucide ikonu cizer; [fill] 0..1 (cizgi -> dolu gecisi), ayni geometri iki durumda da.
class LucideFillPainter extends CustomPainter {
  LucideFillPainter({required this.index, required this.color, required this.cutout, required this.fill});

  final int index;
  final Color color;
  final Color cutout; // dolu halde "oyuk" renk = oval zemin rengi
  final double fill;

  @override
  void paint(Canvas canvas, Size size) {
    final g = _glyphs[index];
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: color.a * fill);
    for (final p in g.solid) {
      canvas.drawPath(p, fillPaint);
      canvas.drawPath(p, stroke);
    }
    for (final p in g.lines) {
      canvas.drawPath(p, stroke);
    }
    for (final p in g.detail) {
      if (g.detailFilled) {
        // pusula ibresi: cizgi renginden oyuk renge, ici oyuk renkle dolar
        canvas.drawPath(p, Paint()..style = PaintingStyle.fill..color = cutout.withValues(alpha: fill));
        canvas.drawPath(p, stroke..color = Color.lerp(color, cutout, fill)!);
      } else {
        canvas.drawPath(p, stroke..color = Color.lerp(color, cutout, fill)!);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(LucideFillPainter old) =>
      old.index != index || old.color != color || old.cutout != cutout || old.fill != fill;
}

// =================================================================================================================
// Cam zemin (BackdropFilter YOK): yari saydam dolgu + ic parlama gradyani + ustten aydinlik 1 dp kenar + tek golge
// =================================================================================================================

class _GlassPainter extends CustomPainter {
  _GlassPainter({
    required this.fill,
    required this.sheen,
    required this.edgeTop,
    required this.edgeBottom,
    required this.outline,
    required this.shadow,
  });

  final Color fill;
  final Color sheen;
  final Color edgeTop;
  final Color edgeBottom;
  final Color? outline;
  final BoxShadow shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(size.height / 2));
    final path = shape.getOuterPath(rect);
    // 1) golge YALNIZ sekil disina (yari saydam dolgunun altindan leke sizmasin)
    // Bulanik golge (MaskFilter) yerine 5 kademeli yari saydam katman: test goruntusunde de yumusak gorunur ve
    // uretimde de ucuzdur (blur maliyeti yok).
    final outside = Path.combine(PathOperation.difference, Path()..addRect(rect.inflate(80)), path);
    canvas.save();
    canvas.clipPath(outside);
    const steps = 5;
    for (var i = 0; i < steps; i++) {
      final f = (i + 1) / steps; // 0.2 .. 1.0
      final grow = (1 - f) * 7; // dista buyuyen, icte kuculen halkalar
      final layer = path.shift(Offset(0, shadow.offset.dy * (.4 + .6 * f)));
      canvas.drawPath(
        layer,
        Paint()
          ..color = shadow.color.withValues(alpha: shadow.color.a * .22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * grow + 1.5
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(layer, Paint()..color = shadow.color.withValues(alpha: shadow.color.a * .16));
    }
    canvas.restore();
    // 2) dolgu
    canvas.drawPath(path, Paint()..color = fill);
    // 3) ic parlama: ustte aydinlik, ortada kaybolur
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [sheen, sheen.withValues(alpha: 0)], [0, .62]),
    );
    // 4) ince dis cizgi (acik tema) + ustten asagi solan 1 dp parlak kenar
    if (outline != null) {
      canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = outline!);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [edgeTop, edgeBottom]),
    );
  }

  @override
  bool shouldRepaint(_GlassPainter old) =>
      old.fill != fill || old.sheen != sheen || old.edgeTop != edgeTop || old.edgeBottom != edgeBottom || old.outline != outline;
}

class _Glass extends StatelessWidget {
  const _Glass({required this.child, this.width, this.height = ProtoNav.height});
  final Widget child;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      painter: _GlassPainter(
        fill: dark ? t.sf3.withValues(alpha: .80) : t.sf.withValues(alpha: .82),
        sheen: t.onMedia.withValues(alpha: dark ? .09 : .65),
        edgeTop: t.onMedia.withValues(alpha: dark ? .40 : .95),
        edgeBottom: t.onMedia.withValues(alpha: dark ? .06 : .30),
        outline: dark ? null : t.bd.withValues(alpha: .85),
        shadow: BoxShadow(
          color: (dark ? t.scrim : t.shadow).withValues(alpha: dark ? .38 : .14),
          blurRadius: 22,
          offset: const Offset(0, 8),
        ),
      ),
      child: SizedBox(width: width, height: height, child: child),
    );
  }
}

/// Seçili oval ve ikon renkleri (varyanta ve temaya gore). Yeni renk yok: yalniz BuTokens.
class _NavColors {
  _NavColors(BuildContext c, NavVariant v) {
    final t = c.bu;
    final dark = Theme.of(c).brightness == Brightness.dark;
    surface = dark ? t.sf3 : t.sf;
    ink = t.ink;
    accent = t.pr;
    oval = v == NavVariant.k ? t.soft : (dark ? t.onMedia.withValues(alpha: .16) : t.ink.withValues(alpha: .08));
    cutout = Color.alphaBlend(oval, surface);
    ghost = oval;
    pressTint = t.ink.withValues(alpha: .07);
  }

  late final Color surface, ink, accent, oval, cutout, ghost, pressTint;
}

// =================================================================================================================
// Prototip gezinme
// =================================================================================================================

class ProtoNav extends StatelessWidget {
  const ProtoNav({
    super.key,
    required this.variant,
    required this.index,
    required this.onChanged,
    required this.unread,
    this.badgeMode = BadgeMode.count,
    this.compact = false,
    this.ovalPos,
  });

  final NavVariant variant;
  final int index;
  final ValueChanged<int> onChanged;
  final ValueNotifier<int> unread;
  final BadgeMode badgeMode;

  /// Asagi kaydirinca kuculme/inme (yalniz transform); yer ayirma (layout) sabit kalir.
  final bool compact;

  /// Yalniz gorsel kare uretimi icin: ovalin ara konumu (null: normal animasyon).
  final double? ovalPos;

  static const double height = 64; // cam hap
  static const double maxWidth = 320;
  static const double minSide = 20; // ekran kenarindan en az
  static const double pad = 5;
  static const double ovalW = 58, ovalH = 44;
  static const double icon = 28;
  static const double floatGap = 12;

  /// Cam hapin alt bosluğu: guvenli alandan 12 dp yukari (iPhone'da ev gostergesine binmez, 22 dp; Android 12 dp).
  static double bottomGap(double inset) => math.max(inset - 12, floatGap);

  static double barWidth(double screenW) => math.min(maxWidth, screenW - 2 * minSide);

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return AnimatedSize(
      duration: BuMotion.of(context, BuMotion.short),
      curve: BuMotion.standard,
      alignment: Alignment.bottomCenter,
      child: keyboard
          ? const SizedBox(width: double.infinity)
          : MediaQuery.withClampedTextScaling(maxScaleFactor: 1.15, child: _bar(context)),
    );
  }

  Widget _bar(BuildContext c) {
    final inset = MediaQuery.viewPaddingOf(c).bottom;
    final w = barWidth(MediaQuery.sizeOf(c).width);
    final slot = (w - 2 * pad) / 5;
    final rtl = Directionality.of(c) == TextDirection.rtl;
    final k = _NavColors(c, variant);
    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap(inset)),
      child: Center(
        heightFactor: 1,
        child: AnimatedScale(
          scale: compact ? .86 : 1,
          alignment: Alignment.bottomCenter,
          duration: BuMotion.of(c, BuMotion.medium),
          curve: BuMotion.standard,
          child: AnimatedSlide(
            offset: Offset(0, compact ? .06 : 0),
            duration: BuMotion.of(c, BuMotion.medium),
            curve: BuMotion.standard,
            child: RepaintBoundary(
              child: _Glass(
                width: w,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: pad),
                  child: Stack(
                    children: [
                      // Kayan oval: tek katman, yalniz Transform ile tasinir (250 ms easeOutCubic).
                      ExcludeSemantics(
                        child: TweenAnimationBuilder<double>(
                          key: const ValueKey('nav-oval'),
                          tween: Tween<double>(end: ovalPos ?? index.toDouble()),
                          duration: ovalPos != null ? Duration.zero : BuMotion.of(c, BuMotion.medium),
                          curve: BuMotion.decelerate,
                          builder: (_, pos, __) => Transform.translate(
                            offset: Offset((rtl ? -1 : 1) * pos * slot + (slot - ovalW) / 2, (height - ovalH) / 2),
                            child: Align(
                              alignment: AlignmentDirectional.topStart,
                              child: DecoratedBox(
                                decoration: ShapeDecoration(
                                  color: k.oval,
                                  shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(ovalH / 2)),
                                ),
                                child: const SizedBox(width: ovalW, height: ovalH),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(children: [
                        for (var i = 0; i < 5; i++)
                          SizedBox(
                            width: slot,
                            height: height,
                            child: NavSlot(
                              position: i,
                              selected: (ovalPos ?? index.toDouble()).round() == i,
                              variant: variant,
                              unread: unread,
                              badgeMode: badgeMode,
                              onTap: () {
                                if (i != index) buHaptic(BuHaptic.selection);
                                onChanged(i);
                              },
                            ),
                          ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tek sekme: ikon (ya da avatar), hover/basili ayna ovali, rozet, Semantics. [forceHover]/[forcePressed] durum
/// tablosu icin.
class NavSlot extends StatefulWidget {
  const NavSlot({
    super.key,
    required this.position,
    required this.selected,
    required this.variant,
    required this.unread,
    required this.badgeMode,
    required this.onTap,
    this.forceHover = false,
    this.forcePressed = false,
  });

  final int position;
  final bool selected;
  final NavVariant variant;
  final ValueNotifier<int> unread;
  final BadgeMode badgeMode;
  final VoidCallback onTap;
  final bool forceHover;
  final bool forcePressed;

  @override
  State<NavSlot> createState() => _NavSlotState();
}

class _NavSlotState extends State<NavSlot> {
  bool _hover = false, _down = false;

  bool get _pressed => _down || widget.forcePressed;
  bool get _isHover => _hover || widget.forceHover;

  @override
  Widget build(BuildContext context) {
    final i = widget.position;
    final k = _NavColors(context, widget.variant);
    final label = ProtoNav_labels(context)[i];
    final tab = MaterialLocalizations.of(context).tabLabel(tabIndex: i + 1, tabCount: 5);
    final sel = widget.selected;
    // Ayna oval: secili degilken hover %40, basili %70; seciliyken yalniz basili ince koyulasma.
    final ghostOpacity = sel ? 0.0 : (_pressed ? .7 : (_isHover ? .4 : 0.0));
    final dur = BuMotion.of(context, BuMotion.short);

    Widget body = Stack(
      alignment: Alignment.center,
      children: [
        AnimatedOpacity(
          key: ValueKey('ghost-$i'),
          opacity: ghostOpacity,
          duration: dur,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: k.ghost,
              shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(ProtoNav.ovalH / 2)),
            ),
            child: const SizedBox(width: ProtoNav.ovalW, height: ProtoNav.ovalH),
          ),
        ),
        if (sel)
          AnimatedOpacity(
            opacity: _pressed ? 1 : 0,
            duration: dur,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: k.pressTint,
                shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(ProtoNav.ovalH / 2)),
              ),
              child: const SizedBox(width: ProtoNav.ovalW, height: ProtoNav.ovalH),
            ),
          ),
        AnimatedScale(
          scale: _pressed ? .92 : 1,
          duration: BuMotion.of(context, const Duration(milliseconds: 100)),
          curve: Curves.easeOut,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: sel ? 1 : 0),
            duration: BuMotion.of(context, BuMotion.short), // dolgu gecisi 150 ms capraz solma
            builder: (_, v, __) => _glyph(context, k, v),
          ),
        ),
      ],
    );

    body = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: body,
      ),
    );

    Widget sem(String text) => Semantics(
          container: true,
          button: true,
          selected: sel,
          inMutuallyExclusiveGroup: true,
          label: text,
          hint: tab,
          onTap: widget.onTap,
          child: ExcludeSemantics(child: SizedBox.expand(key: ValueKey('slot-$i'), child: body)),
        );
    if (i != 2) return sem(label);
    return ValueListenableBuilder<int>(
      valueListenable: widget.unread,
      builder: (ctx, n, _) => sem(n > 0 && !sel ? '$label, ${ctx.l10n.p18NavUnread(n > 99 ? '99+' : '$n')}' : label),
    );
  }

  Widget _glyph(BuildContext c, _NavColors k, double v) {
    final i = widget.position;
    final color = Color.lerp(k.ink, k.accent, v)!;
    Widget g;
    if (i < 4) {
      g = CustomPaint(
        size: const Size.square(ProtoNav.icon),
        painter: LucideFillPainter(index: i, color: color, cutout: k.cutout, fill: v),
      );
    } else {
      g = Container(
        width: ProtoNav.icon,
        height: ProtoNav.icon,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.75 + .5 * v),
        ),
        child: ChatlistAvatar(name: 'Toprak Çevik', url: null, size: ProtoNav.icon - 6, circle: true),
      );
    }
    if (i != 2) return g;
    return ValueListenableBuilder<int>(
      valueListenable: widget.unread,
      builder: (ctx, n, _) {
        final show = n > 0 && v < .5;
        final dot = widget.badgeMode == BadgeMode.dot;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            g,
            if (show)
              PositionedDirectional(
                end: dot ? -2 : -10,
                top: dot ? -2 : -8,
                child: ExcludeSemantics(
                  child: dot
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            color: k.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: k.surface, width: 2),
                          ),
                          child: const SizedBox(width: 11, height: 11),
                        )
                      : BuCountBadge(n, key: const ValueKey('nav-badge')),
                ),
              ),
          ],
        );
      },
    );
  }
}

List<String> ProtoNav_labels(BuildContext c) {
  final l = c.l10n;
  return [l.navHome, l.navDiscover, l.navChat, l.navClubs, l.navProfile];
}

// =================================================================================================================
// Ana bilgisayar: gercek kabuktaki gibi Scaffold(extendBody) + bottomNavigationBar
// =================================================================================================================

double lastBodyBottom = -1; // Scaffold'un govdeye verdigi alt pay (BuScrollPadding kaynagi)

class _Host extends StatefulWidget {
  const _Host({
    required this.variant,
    required this.body,
    this.initial = 1,
    this.unread = 3,
    this.compact = false,
    this.old = false,
  });

  final NavVariant variant;
  final Widget body;
  final int initial;
  final int unread;
  final bool compact;
  final bool old; // mevcut FloatingNav (once/sonra karsilastirmasi)

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late int index = widget.initial;
  late final ValueNotifier<int> unread = ValueNotifier<int>(widget.unread);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Builder(builder: (c) {
        lastBodyBottom = MediaQuery.paddingOf(c).bottom;
        return widget.body;
      }),
      bottomNavigationBar: widget.old
          ? FloatingNav(index: index, onChanged: (i) => setState(() => index = i), chatBadge: unread)
          : ProtoNav(
              variant: widget.variant,
              index: index,
              onChanged: (i) => setState(() => index = i),
              unread: unread,
              compact: widget.compact,
            ),
    );
  }
}

// =================================================================================================================
// Test yardimcilari
// =================================================================================================================

const _dpr = 2.5;

Widget _app(Widget home, bool dark, GlobalKey key, {double scale = 1}) {
  const lang = 'tr';
  return RepaintBoundary(
    key: key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BuTheme.forLocale(Brightness.light, lang),
      darkTheme: BuTheme.forLocale(Brightness.dark, lang),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale(lang),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: home,
    ),
  );
}

void _view(WidgetTester t, double w, double h, double inset) {
  t.view.devicePixelRatio = _dpr;
  t.view.physicalSize = Size(w * _dpr, h * _dpr);
  t.view.padding = FakeViewPadding(top: 28 * _dpr, bottom: inset * _dpr);
  t.view.viewPadding = FakeViewPadding(top: 28 * _dpr, bottom: inset * _dpr);
  addTearDown(t.view.reset);
}

const _authors = [
  ('Emre Kaya', 'Çim Alan', 2),
  ('Zeynep Arslan', 'Kütüphane', 4),
  ('Kaan Çelik', 'Kafeterya', 6),
  ('Kampüs Spor', 'Spor Salonu', 8),
];

Map<String, dynamic> _post(int i) {
  final a = _authors[i % _authors.length];
  final p = samplePost(
    id: 500 - i,
    media: [samplePostMedia(id: 40 + i, width: 1200, height: 900)],
    text: const [
      'Güneşli ve huzurlu bir sonbahar günü',
      'Kütüphane merdivenlerinde nöbet tutan sevimli dostumuz',
      'Vize haftasında sıcak bir kahve molası',
      'Sabah antrenmanları tüm hızıyla devam ediyor',
    ][i % 4],
    likeCount: const [284, 512, 189, 340][i % 4],
    authorId: 20 + i,
    authorName: a.$1,
    createdAt: DateTime.now().subtract(Duration(hours: a.$3)).toUtc().toIso8601String(),
  );
  (p['author'] as Map)['department'] = a.$2;
  return p;
}

FakeBackend _backend() {
  return FakeBackend()
    ..on('/feed*', {'items': [for (var i = 0; i < 4; i++) _post(i)], 'nextCursor': null, 'hint': null})
    ..on('/users/me/follow-suggestions*', {'items': <Object>[]})
    ..on('/menu/today', {'date': '2026-01-01', 'items': ['Mercimek çorbası', 'Orman kebabı', 'Pilav']});
}

Future<void> _precache(WidgetTester tester) async {
  await tester.runAsync(() async {
    final ctx = tester.element(find.byType(Material).first);
    await precacheImage(const AssetImage('assets/branding/default_avatar.png'), ctx);
  });
}

Future<void> _snap(WidgetTester tester, GlobalKey key, String dir, String name) async {
  await tester.runAsync(() async {
    final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await ro.toImage(pixelRatio: _dpr);
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    final d = Directory(dir)..createSync(recursive: true);
    final f = File('${d.path}/$name.png')..writeAsBytesSync(data.buffer.asUint8List());
    // ignore: avoid_print
    print('YAZILDI ${f.path} ${image.width}x${image.height}');
  });
}

/// Durum tablosu: tek sekmelik mini cam hap icinde her durum (normal/hover/basili/secili/secili+basili/rozet/avatar).
class _StateTable extends StatelessWidget {
  const _StateTable({required this.variant});
  final NavVariant variant;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final n3 = ValueNotifier<int>(3);
    final n0 = ValueNotifier<int>(0);
    final cells = <(String, Widget)>[
      ('Normal', _cell(variant, 0, n0)),
      ('Hover (oval %40)', _cell(variant, 0, n0, hover: true)),
      ('Basili (oval %70, ikon %92)', _cell(variant, 0, n0, pressed: true)),
      ('Secili (oval tam, dolu ikon)', _cell(variant, 0, n0, selected: true)),
      ('Secili + basili', _cell(variant, 0, n0, selected: true, pressed: true)),
      ('Kesfet secili', _cell(variant, 1, n0, selected: true)),
      ('Sohbet rozet: sayi (3)', _cell(variant, 2, n3)),
      ('Sohbet rozet: nokta', _cell(variant, 2, n3, dot: true)),
      ('Sohbet rozet: 99+', _cell(variant, 2, ValueNotifier<int>(128))),
      ('Sohbet secili (rozet gizli)', _cell(variant, 2, n3, selected: true)),
      ('Kulupler secili', _cell(variant, 3, n0, selected: true)),
      ('Profil (avatar) normal', _cell(variant, 4, n0)),
      ('Profil secili', _cell(variant, 4, n0, selected: true)),
      ('Profil basili', _cell(variant, 4, n0, pressed: true)),
      ('Profil hover', _cell(variant, 4, n0, hover: true)),
    ];
    return Material(
      color: t.bg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 40, 12, 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 14,
          children: [
            for (final c in cells)
              SizedBox(
                width: 112,
                child: Column(
                  children: [
                    c.$2,
                    const SizedBox(height: 6),
                    Text(c.$1,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall!.copyWith(color: t.mut)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Widget _cell(NavVariant v, int i, ValueNotifier<int> unread,
      {bool selected = false, bool pressed = false, bool hover = false, bool dot = false}) {
    return _Glass(
      width: 84,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (selected)
              Builder(builder: (c) {
                final k = _NavColors(c, v);
                return DecoratedBox(
                  decoration: ShapeDecoration(
                    color: k.oval,
                    shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(ProtoNav.ovalH / 2)),
                  ),
                  child: const SizedBox(width: ProtoNav.ovalW, height: ProtoNav.ovalH),
                );
              }),
            NavSlot(
              position: i,
              selected: selected,
              variant: v,
              unread: unread,
              badgeMode: dot ? BadgeMode.dot : BadgeMode.count,
              onTap: () {},
              forcePressed: pressed,
              forceHover: hover,
            ),
          ],
        ),
      ),
    );
  }
}

/// Kayma karelerinde: t = 0, .2, .4, .6, .8, 1 (Ana Sayfa -> Kulupler, easeOutCubic).
class _SlideFrames extends StatelessWidget {
  const _SlideFrames({required this.variant});
  final NavVariant variant;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Material(
      color: t.bg,
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            for (final f in const [0.0, .2, .4, .6, .8, 1.0])
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  children: [
                    Text('t = ${(f * 250).round()} ms',
                        style: Theme.of(context).textTheme.labelSmall!.copyWith(color: t.mut)),
                    const SizedBox(height: 4),
                    MediaQuery(
                      data: MediaQuery.of(context).copyWith(viewPadding: EdgeInsets.zero, padding: EdgeInsets.zero),
                      child: ProtoNav(
                        variant: variant,
                        index: f >= 1 ? 3 : 0,
                        ovalPos: 3 * Curves.easeOutCubic.transform(f),
                        onChanged: (_) {},
                        unread: ValueNotifier<int>(3),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void main() {
  final out = Platform.environment['NAV_OUT'];
  final skipShots = out == null ? 'NAV_OUT tanimli degil' : null;

  setUpAll(() async {
    await loadTestFonts();
  });

  String vn(NavVariant v) => v == NavVariant.k ? 'K' : 'N';

  // --------------------------------------------------------------------------------------------------------------
  // Ekran goruntuleri
  // --------------------------------------------------------------------------------------------------------------
  for (final dark in [false, true]) {
    final th = dark ? 'dark' : 'light';

    testWidgets('nav mevcut_$th', skip: skipShots != null, (tester) async {
      debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
      _view(tester, 390, 844, 34);
      final session = makeSession(_backend())..api.lang = 'tr';
      LocaleController.current = LocaleController(deviceLocales: () => [const Locale('tr')])..pref = 'tr';
      addTearDown(() => LocaleController.current = null);
      final key = GlobalKey();
      await tester.pumpWidget(_app(
        _Host(
            variant: NavVariant.k,
            old: true,
            body: DiscoverTab(session: session, typeRequest: ValueNotifier<String?>(null))),
        dark,
        key,
      ));
      await _precache(tester);
      await settle(tester, const Duration(milliseconds: 900));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 150));
      await _snap(tester, key, out!, 'nav_mevcut_${th}_390');
      await unmount(tester);
      debugNetworkImageHttpClientProvider = null;
    });

    for (final v in NavVariant.values) {
      for (final dim in const [(390.0, 844.0, 34.0), (360.0, 780.0, 0.0)]) {
        final name = 'nav_${vn(v)}_${th}_${dim.$1.toInt()}';
        testWidgets('nav $name', skip: skipShots != null, (tester) async {
          debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
          _view(tester, dim.$1, dim.$2, dim.$3);
          final session = makeSession(_backend())..api.lang = 'tr';
          LocaleController.current = LocaleController(deviceLocales: () => [const Locale('tr')])..pref = 'tr';
          addTearDown(() => LocaleController.current = null);
          final key = GlobalKey();
          await tester.pumpWidget(_app(
            _Host(variant: v, body: DiscoverTab(session: session, typeRequest: ValueNotifier<String?>(null))),
            dark,
            key,
          ));
          await _precache(tester);
          await settle(tester, const Duration(milliseconds: 900));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
          await tester.pump(const Duration(milliseconds: 150));
          final err = tester.takeException();
          if (err != null) fail('Istisna: $err');
          await _snap(tester, key, out!, name);
          await unmount(tester);
          debugNetworkImageHttpClientProvider = null;
        });
      }

      testWidgets('nav nav_${vn(v)}_${th}_390_home', skip: skipShots != null, (tester) async {
        _view(tester, 390, 844, 34);
        final session = makeSession(_backend())..api.lang = 'tr';
        LocaleController.current = LocaleController(deviceLocales: () => [const Locale('tr')])..pref = 'tr';
        addTearDown(() => LocaleController.current = null);
        final key = GlobalKey();
        await tester.pumpWidget(_app(
          _Host(variant: v, initial: 0, unread: 12, body: HomeTab(session: session, onOpenTab: (i, {newsType}) {})),
          dark,
          key,
        ));
        await _precache(tester);
        await settle(tester, const Duration(milliseconds: 900));
        final err = tester.takeException();
        if (err != null) fail('Istisna: $err');
        await _snap(tester, key, out!, 'nav_${vn(v)}_${th}_390_home');
        await unmount(tester);
      });

      // Kaydirinca kucuk (compact) hal
      testWidgets('nav nav_${vn(v)}_${th}_390_kucuk', skip: skipShots != null, (tester) async {
        debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
        _view(tester, 390, 844, 34);
        final session = makeSession(_backend())..api.lang = 'tr';
        LocaleController.current = LocaleController(deviceLocales: () => [const Locale('tr')])..pref = 'tr';
        addTearDown(() => LocaleController.current = null);
        final key = GlobalKey();
        await tester.pumpWidget(_app(
          _Host(
              variant: v,
              compact: true,
              body: DiscoverTab(session: session, typeRequest: ValueNotifier<String?>(null))),
          dark,
          key,
        ));
        await _precache(tester);
        await settle(tester, const Duration(milliseconds: 900));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
        await tester.pump(const Duration(milliseconds: 400));
        await _snap(tester, key, out!, 'nav_${vn(v)}_${th}_390_kucuk');
        await unmount(tester);
        debugNetworkImageHttpClientProvider = null;
      });

      testWidgets('nav nav_durumlar_${vn(v)}_$th', skip: skipShots != null, (tester) async {
        _view(tester, 390, 700, 0);
        LocaleController.current = LocaleController(deviceLocales: () => [const Locale('tr')])..pref = 'tr';
        addTearDown(() => LocaleController.current = null);
        final key = GlobalKey();
        await tester.pumpWidget(_app(_StateTable(variant: v), dark, key));
        await _precache(tester);
        await settle(tester, const Duration(milliseconds: 600));
        final err = tester.takeException();
        if (err != null) fail('Istisna: $err');
        await _snap(tester, key, out!, 'nav_durumlar_${vn(v)}_$th');
        await unmount(tester);
      });

      testWidgets('nav nav_kayma_${vn(v)}_$th', skip: skipShots != null, (tester) async {
        _view(tester, 390, 720, 0);
        LocaleController.current = LocaleController(deviceLocales: () => [const Locale('tr')])..pref = 'tr';
        addTearDown(() => LocaleController.current = null);
        final key = GlobalKey();
        await tester.pumpWidget(_app(_SlideFrames(variant: v), dark, key));
        await _precache(tester);
        await settle(tester, const Duration(milliseconds: 600));
        final err = tester.takeException();
        if (err != null) fail('Istisna: $err');
        await _snap(tester, key, out!, 'nav_kayma_${vn(v)}_$th');
        await unmount(tester);
      });
    }
  }

  // --------------------------------------------------------------------------------------------------------------
  // Olcum + erisilebilirlik (her kosuda)
  // --------------------------------------------------------------------------------------------------------------
  final report = StringBuffer();
  tearDownAll(() {
    // ignore: avoid_print
    print('\nNAV-OLCUM\n$report');
  });

  testWidgets('nav olcum: mevcut FloatingNav (HEAD) gercek yukseklik vs kNavInset', (tester) async {
    for (final inset in [0.0, 34.0]) {
      _view(tester, 390, 844, inset);
      LocaleController.current = LocaleController(deviceLocales: () => [const Locale('tr')])..pref = 'tr';
      final key = GlobalKey();
      await tester.pumpWidget(_app(
        Scaffold(
          extendBody: true,
          body: const SizedBox.expand(),
          bottomNavigationBar: FloatingNav(index: 0, onChanged: (_) {}, chatBadge: ValueNotifier<int>(0)),
        ),
        false,
        key,
      ));
      await tester.pump(const Duration(milliseconds: 400));
      final s = tester.getSize(find.byType(FloatingNav));
      final pill = tester.getSize(find.byKey(const ValueKey('nav-pill')));
      report.writeln('MEVCUT FloatingNav inset=$inset: toplam alt alan ${s.height} dp, hap ${pill.height} dp, sabit BuSize.navInset=96 (HEAD kNavInset=100)');
    }
    LocaleController.current = null;
  });

  for (final v in NavVariant.values) {
    for (final w in const [360.0, 390.0]) {
      for (final inset in const [0.0, 34.0]) {
        testWidgets('nav olcum ${vn(v)} w=$w inset=$inset: yukseklik, govde payi, genislik, 48 dp, semantics', (tester) async {
          final sem = tester.ensureSemantics();
          _view(tester, w, 800, inset);
          LocaleController.current = LocaleController(deviceLocales: () => [const Locale('tr')])..pref = 'tr';
          addTearDown(() => LocaleController.current = null);
          final key = GlobalKey();
          await tester.pumpWidget(_app(_Host(variant: v, initial: 1, body: const SizedBox.expand()), false, key));
          await _precache(tester);
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);

          // Toplam alt alan = Scaffold'un govdeye verdigi alt pay (BuScrollPadding tek kaynagi bunu okur).
          final total = tester.getSize(find.byType(ProtoNav)).height;
          expect(lastBodyBottom, closeTo(total, .6), reason: 'govde alt payi == gercek bar alani');
          expect(total, closeTo(ProtoNav.height + ProtoNav.bottomGap(inset), 1.2));

          // Genislik: en cok 320, ekran kenarindan >= 20.
          final hap = tester.getRect(find.byKey(const ValueKey('slot-0'))).left;
          final hapRight = tester.getRect(find.byKey(const ValueKey('slot-4'))).right;
          expect(hap, greaterThanOrEqualTo(20));
          expect(w - hapRight, greaterThanOrEqualTo(20));
          expect(hapRight - hap, lessThanOrEqualTo(320));

          final sizes = <String>[];
          for (var i = 0; i < 5; i++) {
            final s = tester.getSize(find.byKey(ValueKey('slot-$i')));
            sizes.add('${s.width.toStringAsFixed(1)}x${s.height.toStringAsFixed(1)}');
            expect(s.width, greaterThanOrEqualTo(48), reason: 'sekme $i genislik');
            expect(s.height, greaterThanOrEqualTo(48), reason: 'sekme $i yukseklik');
          }

          final selected = tester.getSemantics(find.byKey(const ValueKey('slot-1')));
          expect(selected.getSemanticsData().flagsCollection.isSelected, ui.Tristate.isTrue);
          final chat = tester.getSemantics(find.byKey(const ValueKey('slot-2')));
          expect(chat.label, contains('Sohbet'));
          expect(chat.label, contains('3'));

          await tester.tap(find.byKey(const ValueKey('slot-4')));
          await tester.pump(const Duration(milliseconds: 400));
          final s4 = tester.getSemantics(find.byKey(const ValueKey('slot-4')));
          expect(s4.getSemanticsData().flagsCollection.isSelected, ui.Tristate.isTrue);

          report.writeln(
              '${vn(v)} w=${w.toInt()} inset=${inset.toInt()}: alt alan ${total.toStringAsFixed(1)} dp (govde payi ${lastBodyBottom.toStringAsFixed(1)}), hap ${(hapRight - hap).toStringAsFixed(0)} dp, kenar ${hap.toStringAsFixed(0)}, sekme hedefleri [${sizes.join(', ')}]');
          sem.dispose();
          await unmount(tester);
        });
      }
    }
  }

  testWidgets('nav hover %40 ve basili %70 ayna oval; secili kaymasi', (tester) async {
    _view(tester, 390, 800, 34);
    LocaleController.current = LocaleController(deviceLocales: () => [const Locale('tr')])..pref = 'tr';
    addTearDown(() => LocaleController.current = null);
    final key = GlobalKey();
    await tester.pumpWidget(_app(_Host(variant: NavVariant.k, initial: 0, body: const SizedBox.expand()), false, key));
    await _precache(tester);
    await tester.pump(const Duration(milliseconds: 400));
    double ghost(int i) => tester.widget<AnimatedOpacity>(find.byKey(ValueKey('ghost-$i'))).opacity;

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey('slot-3'))));
    await tester.pump(const Duration(milliseconds: 200));
    expect(ghost(3), .4);
    expect(ghost(0), 0); // secili sekmede ayna oval yok (gercek oval var)

    await mouse.down(tester.getCenter(find.byKey(const ValueKey('slot-3'))));
    await tester.pump(const Duration(milliseconds: 120));
    expect(ghost(3), .7);
    await mouse.up();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400)); // animasyon ikinci karede baslar
    expect(ghost(3), 0); // artik secili

    // Oval konumu: 3. sekme merkezine oturur
    final oval = tester.getRect(find.descendant(of: find.byKey(const ValueKey('nav-oval')), matching: find.byType(DecoratedBox)).first);
    final slot = tester.getRect(find.byKey(const ValueKey('slot-3')));
    expect(oval.center.dx, closeTo(slot.center.dx, 1));
    await unmount(tester);
  });

  testWidgets('nav klavye: klavye acilinca bar kapanir (yer ayirma 0)', (tester) async {
    _view(tester, 390, 800, 34);
    LocaleController.current = LocaleController(deviceLocales: () => [const Locale('tr')])..pref = 'tr';
    addTearDown(() => LocaleController.current = null);
    final key = GlobalKey();
    await tester.pumpWidget(_app(_Host(variant: NavVariant.k, body: const SizedBox.expand()), false, key));
    await _precache(tester);
    await tester.pump(const Duration(milliseconds: 400));
    tester.view.viewInsets = FakeViewPadding(bottom: 300 * _dpr);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.getSize(find.byType(ProtoNav)).height, lessThan(1));
    await unmount(tester);
  });

  testWidgets('nav "animasyonlari azalt": oval ve dolgu anlik', (tester) async {
    _view(tester, 390, 800, 34);
    LocaleController.current = LocaleController(deviceLocales: () => [const Locale('tr')])..pref = 'tr';
    addTearDown(() => LocaleController.current = null);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final key = GlobalKey();
    await tester.pumpWidget(_app(_Host(variant: NavVariant.k, initial: 0, body: const SizedBox.expand()), false, key));
    await tester.tap(find.byKey(const ValueKey('slot-3')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final oval = tester.getRect(find.descendant(of: find.byKey(const ValueKey('nav-oval')), matching: find.byType(DecoratedBox)).first);
    final slot = tester.getRect(find.byKey(const ValueKey('slot-3')));
    expect(oval.center.dx, closeTo(slot.center.dx, 1));
    await unmount(tester);
  });

  testWidgets('nav yazi olcegi 1.3 (320 dp): tasma yok, hedefler >= 48, genislik 280', (tester) async {
    for (final v in NavVariant.values) {
      _view(tester, 320, 700, 34);
      LocaleController.current = LocaleController(deviceLocales: () => [const Locale('tr')])..pref = 'tr';
      final key = GlobalKey();
      await tester.pumpWidget(_app(_Host(variant: v, initial: 3, body: const SizedBox.expand()), false, key, scale: 1.3));
      await _precache(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: '${vn(v)} 320dp x1.3 tasma');
      for (var i = 0; i < 5; i++) {
        final s = tester.getSize(find.byKey(ValueKey('slot-$i')));
        expect(s.width, greaterThanOrEqualTo(48), reason: '${vn(v)} sekme $i');
      }
      report.writeln('${vn(v)} 320dp x1.3: alt alan ${tester.getSize(find.byType(ProtoNav)).height.toStringAsFixed(1)} dp, sekme ${tester.getSize(find.byKey(const ValueKey('slot-0'))).width.toStringAsFixed(1)} dp');
      await unmount(tester);
    }
    LocaleController.current = null;
  });
}
