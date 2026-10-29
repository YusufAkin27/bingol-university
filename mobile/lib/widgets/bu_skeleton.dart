import 'package:flutter/material.dart';

import '../core/locale_controller.dart';
import '../core/theme.dart';
import '../core/theme/bu_motion.dart';

/// Tek paylaşılan animasyonu iskelet kutularına dağıtan kapsam. Bir grup iskelet [BuSkeletonScope] altında
/// çizilirse ekranda yalnız BİR AnimationController çalışır ("tek ticker"). Kutular yeniden kurulmaz,
/// yalnızca boyanır (`CustomPainter(repaint:)`). "Animasyonları azalt" açıksa statik renk.
class BuSkeletonScope extends StatefulWidget {
  const BuSkeletonScope({super.key, required this.child});

  final Widget child;

  @override
  State<BuSkeletonScope> createState() => _BuSkeletonScopeState();
}

class _BuSkeletonScopeState extends State<BuSkeletonScope> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  bool? _reduced;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = BuMotion.reduced(context);
    if (_reduced == r) return;
    _reduced = r;
    if (r) {
      _c.stop();
      _c.value = 0;
    } else {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SkeletonAnim(animation: _c, child: widget.child);
}

class _SkeletonAnim extends InheritedWidget {
  const _SkeletonAnim({required this.animation, required super.child});

  final Animation<double> animation;

  static Animation<double>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SkeletonAnim>()?.animation;

  @override
  bool updateShouldNotify(_SkeletonAnim old) => old.animation != animation;
}

/// İskelet kutusu (yükleniyor yer tutucusu). Dikdörtgen/hap [BuSkeleton], daire [BuSkeleton.circle],
/// metin satırı [BuSkeleton.line]. Kapsam yoksa kendi kapsamını kurar; çok sayıda kutu için
/// [BuSkeletonScope] ya da [BuSkeletonList] kullanın.
class BuSkeleton extends StatelessWidget {
  const BuSkeleton({super.key, this.width, this.height = 14, this.radius = 8}) : _circle = false;

  /// Daire (avatar yer tutucusu).
  const BuSkeleton.circle(double size, {super.key})
      : width = size,
        height = size,
        radius = 0,
        _circle = true;

  /// Metin satırı yer tutucusu (yükseklik 12, köşe 6).
  const BuSkeleton.line({super.key, this.width, this.height = 12}) : radius = 6, _circle = false;

  /// null: ebeveynin genişliği.
  final double? width;
  final double height;
  final double radius;
  final bool _circle;

  @override
  Widget build(BuildContext context) {
    final anim = _SkeletonAnim.maybeOf(context);
    if (anim == null) return BuSkeletonScope(child: this);
    final t = context.bu;
    final box = RepaintBoundary(
      child: CustomPaint(
        size: Size(width ?? double.infinity, height),
        painter: _SkeletonPainter(anim, t.sf2, t.bd, radius, _circle),
      ),
    );
    return ExcludeSemantics(
      child: width == null ? SizedBox(height: height, width: double.infinity, child: box) : SizedBox(width: width, height: height, child: box),
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  _SkeletonPainter(this.anim, this.a, this.b, this.radius, this.circle) : super(repaint: anim);

  final Animation<double> anim;
  final Color a;
  final Color b;
  final double radius;
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Color.lerp(a, b, Curves.easeInOut.transform(anim.value))!;
    if (circle) {
      canvas.drawCircle(size.center(Offset.zero), size.shortestSide / 2, p);
    } else {
      canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)), p);
    }
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) => old.a != a || old.b != b || old.radius != radius || old.circle != circle;
}

/// Hazır iskelet düzeni.
enum BuSkeletonVariant {
  /// Avatar + iki satır (sohbet, bildirim, kişi listesi).
  row,

  /// Üstte görsel + satırlar (haber, etkinlik kartı).
  card,

  /// İki sütunlu ızgara karoları (keşfet, galeri).
  grid,
}

/// Yükleniyor durumu için hazır iskelet liste (tek ticker, kaydırılmaz). `BuPageScaffold` bunu varsayılan kullanır.
/// Erişilebilirlik: tek bir "Yükleniyor" etiketi okunur, kutular okunmaz.
class BuSkeletonList extends StatelessWidget {
  const BuSkeletonList({
    super.key,
    this.variant = BuSkeletonVariant.row,
    this.itemCount = 6,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 20),
    this.shrinkWrap = false,
  });

  final BuSkeletonVariant variant;
  final int itemCount;
  final EdgeInsetsGeometry padding;

  /// true: sliver/Column içinde (kaydırılmaz, içeriğe göre boyutlanır).
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.commonLoading;
    final Widget content = switch (variant) {
      BuSkeletonVariant.row => Column(children: [for (var i = 0; i < itemCount; i++) const _RowSkeleton()]),
      BuSkeletonVariant.card => Column(children: [for (var i = 0; i < itemCount; i++) const _CardSkeleton()]),
      BuSkeletonVariant.grid => _GridSkeleton(count: itemCount),
    };
    final body = Padding(padding: padding, child: content);
    return Semantics(
      label: label,
      liveRegion: true,
      container: true,
      child: BuSkeletonScope(
        child: shrinkWrap
            ? body
            : LayoutBuilder(
                builder: (context, c) => SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: ConstrainedBox(constraints: BoxConstraints(minHeight: c.hasBoundedHeight ? c.maxHeight : 0), child: body),
                ),
              ),
      ),
    );
  }
}

class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            BuSkeleton.circle(48),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BuSkeleton.line(width: 150, height: 14),
                  SizedBox(height: 8),
                  BuSkeleton.line(height: 12),
                ],
              ),
            ),
          ],
        ),
      );
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BuSkeleton(height: 150, radius: 20),
            SizedBox(height: 12),
            BuSkeleton.line(width: 220, height: 16),
            SizedBox(height: 8),
            BuSkeleton.line(height: 12),
          ],
        ),
      );
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final rows = (count / 2).ceil();
    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(child: BuSkeleton(height: r.isEven ? 190 : 150, radius: 20)),
                const SizedBox(width: 12),
                Expanded(child: BuSkeleton(height: r.isEven ? 150 : 190, radius: 20)),
              ],
            ),
          ),
      ],
    );
  }
}
