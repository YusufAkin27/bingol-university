import 'package:flutter/material.dart';

import '../../core/icons/bu_icons.dart';
import '../../core/locale_controller.dart';
import '../../core/theme/bu_motion.dart';

/// Mesaj durumu (yalnız gönderenin kendi mesajlarında).
/// pending: saat; failed: uyarı; SENT: tek gri tik; DELIVERED: çift gri tik; READ: çift MAVİ tik.
///
/// Neden tek CustomPainter: eski çözüm Lucide `check`/`checkCheck` glifleriydi. İki glifin 24'lük ızgaradaki iç
/// payı farklıdır (tek tik 4..20, çift tik 2..22) ve [AnimatedSwitcher]'ın varsayılan Stack'i çocukları ortaladığından
/// farklı boyutlu simgelerin sağ kenarı durumdan duruma kayıyordu; yama (Transform.translate) yalnız belirtiyi örtüyordu.
/// Burada tek ve çift tik AYNI sabit kutuda, tek bir [Path] olarak çizilir; sağ (bitiş) kenar tüm durumlarda aynıdır.
class MessageStatusIcon extends StatelessWidget {
  const MessageStatusIcon({
    super.key,
    required this.status,
    required this.color,
    required this.readColor,
    required this.failedColor,
    this.size = 17.5,
  });

  final String status;
  final Color color;
  final Color readColor;
  final Color failedColor;

  /// Simge boyutu (çift tikin yüksekliği ile aynı ölçek); kutu genişliği = size.
  final double size;

  /// Sabit sınırlayıcı kutu: tüm durumlar bu kutuda bitiş kenarına yaslanır.
  static Size boxFor(double size) => Size(size, size * 19 / 17.5);

  @override
  Widget build(BuildContext context) {
    final box = boxFor(size);
    final label = switch (status) {
      'pending' => context.l10n.chatMiscStatusSending,
      'failed' => context.l10n.chatMiscSendFailed,
      'SENT' => context.l10n.chatMiscStatusSent,
      'DELIVERED' => context.l10n.chatMiscStatusDelivered,
      _ => context.l10n.chatMiscStatusRead,
    };
    final Widget glyph = switch (status) {
      'pending' => Align(
          key: const ValueKey<String>('msg-status-pending'),
          alignment: AlignmentDirectional.centerEnd,
          child: Icon(BuIcons.clock, size: size, color: color),
        ),
      'failed' => Align(
          key: const ValueKey<String>('msg-status-failed'),
          alignment: AlignmentDirectional.centerEnd,
          child: Icon(BuIcons.circleAlert, size: size, color: failedColor),
        ),
      _ => CustomPaint(
          key: ValueKey<String>('msg-status-$status'),
          size: box,
          painter: MessageTickPainter(
            isDouble: status != 'SENT',
            color: status == 'READ' ? readColor : color,
            rtl: Directionality.of(context) == TextDirection.rtl,
          ),
        ),
    };
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: SizedBox(
          width: box.width,
          height: box.height,
          child: AnimatedSwitcher(
            duration: BuMotion.of(context, BuMotion.short),
            // Tüm çocuklar aynı kutuda, bitiş kenarına yaslı (varsayılan layoutBuilder ortalardı).
            layoutBuilder: (current, previous) => Stack(
              alignment: AlignmentDirectional.centerEnd,
              clipBehavior: Clip.none,
              children: [...previous, if (current != null) current],
            ),
            transitionBuilder: (c, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                  alignment: Directionality.of(context) == TextDirection.rtl ? Alignment.centerLeft : Alignment.centerRight,
                  scale: Tween<double>(begin: .7, end: 1).animate(anim),
                  child: c),
            ),
            child: SizedBox(
                key: ValueKey<String>(status),
                width: box.width,
                height: box.height,
                child: glyph),
          ),
        ),
      ),
    );
  }
}

/// Tek ya da çift tik: tek [Path], yuvarlak uç/köşe. Çift tikte iki işaret çok yakın ve hafif üst üste biner.
class MessageTickPainter extends CustomPainter {
  const MessageTickPainter({required this.isDouble, required this.color, this.rtl = false});

  final bool isDouble;
  final Color color;
  final bool rtl;

  // 17.5 birimlik referans kutuda ölçüler (çizim boyutla orantılı ölçeklenir).
  static const double _ref = 17.5;
  static const double _stroke = 1.7;
  static const double _tickW = 10.2;
  static const double _tickH = 8.3;
  static const double _step = 4.6; // iki tik arası yatay kayma
  static const double _inset = _stroke / 2 + .5; // bitiş kenarından iç pay

  /// Çizilen yol (kutu koordinatlarında). RTL'de bitiş kenarı sol olur.
  static Path pathFor(Size size, {required bool isDouble, required bool rtl}) {
    final k = size.width / _ref;
    final y0 = (size.height - _tickH * k) / 2;
    void tick(Path p, double x0) {
      // x0: tikin sol-üst referansı; kısa kol sola-aşağı, uzun kol sağa-yukarı.
      p.moveTo(x0, y0 + 4.6 * k);
      p.lineTo(x0 + 3.7 * k, y0 + _tickH * k);
      p.lineTo(x0 + _tickW * k, y0);
    }

    final path = Path();
    final endMost = rtl ? _inset * k : size.width - (_inset + _tickW) * k;
    final dx = (rtl ? 1 : -1) * _step * k;
    if (isDouble) tick(path, endMost + dx);
    tick(path, endMost);
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke * size.width / _ref
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    canvas.drawPath(pathFor(size, isDouble: isDouble, rtl: rtl), paint);
  }

  @override
  bool shouldRepaint(MessageTickPainter old) =>
      old.isDouble != isDouble || old.color != color || old.rtl != rtl;
}
