import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/locale_controller.dart';
import 'bu.dart';

/// Ortak ön izleme (peek) kabuğu: bulanık + `scrim` jetonlu zemin üstünde ortalanmış kart. Dışına dokununca ya da
/// aşağı kaydırınca kapanır; hareket azaltma açıksa geçiş anında. Gönderi ve "Bugün kampüste" ön izlemeleri
/// aynı kabuğu kullanır. [builder] kartı kurar; kartın içinden kapatmak için verilen `close` çağrılır.
Future<void> showPeekDialog(
  BuildContext context, {
  required Widget Function(BuildContext ctx, VoidCallback close) builder,
}) {
  HapticFeedback.mediumImpact();
  final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration:
        reduce ? Duration.zero : const Duration(milliseconds: 220),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic);
      return AnimatedBuilder(
        animation: curved,
        builder: (_, __) => Stack(children: [
          Positioned.fill(
            child: IgnorePointer(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                    sigmaX: 14 * curved.value, sigmaY: 14 * curved.value),
                child: ColoredBox(
                    color: ctx.bu.scrim.withValues(alpha: .46 * curved.value)),
              ),
            ),
          ),
          Center(
            child: Opacity(
              opacity: curved.value.clamp(0.0, 1.0),
              child: Transform.scale(
                  scale: .88 + .12 * curved.value, child: child),
            ),
          ),
        ]),
      );
    },
    pageBuilder: (ctx, _, __) =>
        builder(ctx, () => Navigator.of(ctx).pop()),
  );
}
