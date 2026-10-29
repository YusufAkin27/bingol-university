import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/bu_motion.dart';

// --- Aşamalı (staggered) giriş -------------------------------------------------------------------------------

/// Aşamalı girişte hangi öğelerin zaten oynatıldığını tutar; kaydırınca geri gelen öğeler yeniden oynamaz.
class BuStaggerScope extends StatefulWidget {
  const BuStaggerScope({super.key, required this.child});

  final Widget child;

  @override
  State<BuStaggerScope> createState() => _BuStaggerScopeState();
}

class _BuStaggerScopeState extends State<BuStaggerScope> {
  final _played = <int>{};

  @override
  Widget build(BuildContext context) => _StaggerData(played: _played, child: widget.child);
}

class _StaggerData extends InheritedWidget {
  const _StaggerData({required this.played, required super.child});

  final Set<int> played;

  @override
  bool updateShouldNotify(_StaggerData old) => false;
}

/// Öğeyi (solma + 14 dp yükselme) ile içeri alır; gecikme `index * 40 ms`, en çok [maxAnimated] öğe.
/// Kapsam ([BuStaggerScope]) varsa her indeks yalnız bir kez oynar. "Animasyonları azalt" açıksa anında.
class BuStaggerItem extends StatefulWidget {
  const BuStaggerItem({super.key, required this.index, required this.child, this.maxAnimated = 8});

  final int index;
  final Widget child;
  final int maxAnimated;

  @override
  State<BuStaggerItem> createState() => _BuStaggerItemState();
}

class _BuStaggerItemState extends State<BuStaggerItem> with SingleTickerProviderStateMixin {
  AnimationController? _c;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  bool _static = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null || !_static) return;
    final played = context.getInheritedWidgetOfExactType<_StaggerData>()?.played;
    final skip = BuMotion.reduced(context) || widget.index >= widget.maxAnimated || (played?.contains(widget.index) ?? false);
    if (skip) return;
    played?.add(widget.index);
    _static = false;
    final delay = BuMotion.stagger.inMilliseconds * widget.index;
    final total = BuMotion.long.inMilliseconds + delay;
    final c = AnimationController(vsync: this, duration: Duration(milliseconds: total));
    final curve = CurvedAnimation(
      parent: c,
      curve: Interval(delay / total, 1, curve: BuMotion.emphasizedDecelerate),
    );
    _fade = curve;
    _slide = Tween(begin: const Offset(0, .06), end: Offset.zero).animate(curve);
    _c = c..forward();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_static || _c == null) return widget.child;
    return FadeTransition(opacity: _fade, child: SlideTransition(position: _slide, child: widget.child));
  }
}

/// Aşamalı girişli, tembel (`ListView.builder`) liste: ilk 8 öğe sırayla belirir, geri kalanı anında.
/// Yatay kenar boşluğunu [padding] ile verin.
class BuStaggeredList extends StatelessWidget {
  const BuStaggeredList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
    this.controller,
    this.physics,
    this.separatorBuilder,
    this.shrinkWrap = false,
    this.maxAnimated = 8,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;

  /// Verilirse öğeler arasına ayraç konur.
  final IndexedWidgetBuilder? separatorBuilder;
  final bool shrinkWrap;
  final int maxAnimated;

  @override
  Widget build(BuildContext context) {
    Widget item(BuildContext c, int i) => BuStaggerItem(index: i, maxAnimated: maxAnimated, child: itemBuilder(c, i));
    return BuStaggerScope(
      child: separatorBuilder == null
          ? ListView.builder(
              controller: controller,
              physics: physics,
              padding: padding,
              shrinkWrap: shrinkWrap,
              itemCount: itemCount,
              itemBuilder: item,
            )
          : ListView.separated(
              controller: controller,
              physics: physics,
              padding: padding,
              shrinkWrap: shrinkWrap,
              itemCount: itemCount,
              itemBuilder: item,
              separatorBuilder: separatorBuilder!,
            ),
    );
  }
}

// --- Geçişler ------------------------------------------------------------------------------------------------

/// "Fade through": eski içerik solar, yenisi hafif büyüyerek belirir. İçerik değişiminde (iskelet -> veri,
/// sekme içeriği) kullanın; çocuğa **anahtar** (`ValueKey`) verin, yoksa geçiş oynamaz.
class BuFadeThrough extends StatelessWidget {
  const BuFadeThrough({super.key, required this.child, this.duration = BuMotion.medium});

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final d = BuMotion.of(context, duration);
    return AnimatedSwitcher(
      duration: d,
      reverseDuration: d,
      switchInCurve: BuMotion.emphasizedDecelerate,
      switchOutCurve: BuMotion.emphasizedAccelerate,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: const Interval(.3, 1)),
        child: ScaleTransition(scale: Tween(begin: .96, end: 1.0).animate(anim), child: child),
      ),
      child: child,
    );
  }
}

/// Paylaşılan eksen (shared axis): çocuk değişince yatay kayarak + solarak geçer. [reverse] true: geri yön.
/// RTL'de yön otomatik aynalanır. Çocuğa **anahtar** verin.
class BuSharedAxis extends StatelessWidget {
  const BuSharedAxis({super.key, required this.child, this.reverse = false, this.duration = BuMotion.medium, this.distance = 30});

  final Widget child;
  final bool reverse;
  final Duration duration;

  /// Kayma uzaklığı (dp).
  final double distance;

  @override
  Widget build(BuildContext context) {
    final d = BuMotion.of(context, duration);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final sign = (reverse ? -1.0 : 1.0) * (rtl ? -1.0 : 1.0);
    return AnimatedSwitcher(
      duration: d,
      reverseDuration: d,
      switchInCurve: BuMotion.emphasizedDecelerate,
      switchOutCurve: BuMotion.emphasizedAccelerate,
      layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, if (current != null) current]),
      transitionBuilder: (child, anim) {
        final entering = child.key == this.child.key;
        final begin = entering ? Offset(sign * distance, 0) : Offset(-sign * distance, 0);
        return FadeTransition(
          opacity: anim,
          child: AnimatedBuilder(
            animation: anim,
            child: child,
            builder: (context, c) => Transform.translate(offset: begin * (1 - anim.value), child: c),
          ),
        );
      },
      child: child,
    );
  }
}

/// Paylaşılan eksen (X) sayfa rotası: `Navigator.push(BuPageRoute(builder: (_) => Page()))`.
/// 300 ms, "animasyonları azalt" açıksa anında. Geri jesti (iOS kenar kaydırma / Android tahmini geri) için
/// tema geçişini (`MaterialPageRoute`) kullanmak yeterlidir; BuPageRoute özel akışlar (sihirbaz, tam ekran seçici) içindir.
class BuPageRoute<T> extends PageRouteBuilder<T> {
  BuPageRoute({required WidgetBuilder builder, super.settings, super.fullscreenDialog})
      : super(
          transitionDuration: BuMotion.long,
          reverseTransitionDuration: BuMotion.medium,
          pageBuilder: (context, _, __) => builder(context),
          transitionsBuilder: (context, animation, secondary, child) {
            if (BuMotion.reduced(context)) return child;
            final rtl = Directionality.of(context) == TextDirection.rtl;
            final dx = 30.0 * (rtl ? -1 : 1);
            final inCurve = CurvedAnimation(parent: animation, curve: BuMotion.emphasizedDecelerate, reverseCurve: BuMotion.emphasizedAccelerate);
            final outCurve = CurvedAnimation(parent: secondary, curve: BuMotion.emphasized);
            return AnimatedBuilder(
              animation: Listenable.merge([inCurve, outCurve]),
              child: child,
              builder: (context, c) {
                final enter = inCurve.value;
                final exit = outCurve.value;
                return Opacity(
                  opacity: math.min(enter, 1 - exit * .9).clamp(0.0, 1.0),
                  child: Transform.translate(offset: Offset(dx * (1 - enter) - dx * exit, 0), child: c),
                );
              },
            );
          },
        );
}
