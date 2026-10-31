import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'chat_media.dart';

/// Eski sohbet detay tasarımının sabit tonu. Geriye uyum için durur; yeni kod `context.bu.scrim` kullanır.
final Color kChatdNavy = BuTokens.light.ink;

/// Medya üstü yarı saydam koyu zemin (hap, "+N", halka). `scrim` her iki temada aynıdır (siyah).
Color chatdScrim([double alpha = .66]) => BuTokens.light.scrim.withValues(alpha: alpha);

/// Video/yükleme üstü alt gölge.
final LinearGradient chatdBottomShade = LinearGradient(
  begin: Alignment.bottomCenter,
  end: Alignment.topCenter,
  colors: [chatdScrim(.55), chatdScrim(0)],
  stops: const [0, .6],
);

/// Izgara hücresi köşeleri: dış köşeler 16, iç köşeler 6 (RTL'de aynalanır).
BorderRadiusDirectional chatdCellRadius(int i, int cols, int count) {
  const big = Radius.circular(16);
  const small = Radius.circular(6);
  final rows = (count + cols - 1) ~/ cols;
  final row = i ~/ cols;
  final col = i % cols;
  final first = col == 0;
  final last = col == cols - 1 || i == count - 1;
  final top = row == 0;
  final bottom = row == rows - 1;
  return BorderRadiusDirectional.only(
    topStart: top && first ? big : small,
    topEnd: top && last ? big : small,
    bottomStart: bottom && first ? big : small,
    bottomEnd: bottom && last ? big : small,
  );
}

/// Koyu, tam yuvarlak küçük hap (saat, süre, durum). Yazı `labelSmall` (11), `onMedia`.
class ChatdPill extends StatelessWidget {
  const ChatdPill({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return DecoratedBox(
      decoration: BoxDecoration(color: t.scrim.withValues(alpha: .58), borderRadius: BuRadius.bPill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: DefaultTextStyle(
          style: Theme.of(context).textTheme.labelSmall!.copyWith(color: t.onMedia, fontWeight: FontWeight.w600),
          child: child,
        ),
      ),
    );
  }
}

/// Video süresi hapı: küçük video simgesi + "0:24".
class ChatdDuration extends StatelessWidget {
  const ChatdDuration({super.key, required this.ms});

  final int ms;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return ChatdPill(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(LucideIcons.video, size: 12, color: t.onMedia),
        const SizedBox(width: 4),
        Text(formatMediaDuration(ms), textDirection: TextDirection.ltr),
      ]),
    );
  }
}

/// Oynat düğmesi: açık (beyaz) daire + koyu üçgen (referans 19: görselin ortasında).
class ChatdPlay extends StatelessWidget {
  const ChatdPlay({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: t.onMedia.withValues(alpha: .92)),
      alignment: Alignment.center,
      child: Padding(
        // Üçgenin optik merkezi geometrik merkezden biraz sağdadır; ortalamak için hafif içeri.
        padding: EdgeInsetsDirectional.only(start: size * .04),
        child: Icon(Icons.play_arrow_rounded, size: size * .6, color: t.scrim),
      ),
    );
  }
}

/// İlerleme halkası: 56 dp koyu daire, ince halka, ortada simge. [value] null ise belirsiz (dönen) halka.
class ChatdRing extends StatelessWidget {
  const ChatdRing({super.key, this.value, required this.icon, this.semantics, this.arc});

  final double? value;
  final IconData icon;
  final String? semantics;

  /// İlerleme yayının rengi (varsayılan: medya üstü açık renk).
  final Color? arc;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final pct = value == null ? null : (value! * 100).round();
    return Semantics(
      label: semantics,
      value: pct == null ? null : '$pct%',
      child: ExcludeSemantics(
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: t.scrim.withValues(alpha: .62), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 3,
                strokeCap: StrokeCap.round,
                color: arc ?? t.onMedia,
                backgroundColor: t.onMedia.withValues(alpha: .26),
              ),
            ),
            Icon(icon, size: 20, color: t.onMedia),
          ]),
        ),
      ),
    );
  }
}

/// Ağdan inen görsel için yer tutucu: nabız atan iskelet (tek ortak ticker), ortada görsel simgesi,
/// büyük hücrede "Fotoğraf yükleniyor…" etiketi.
class ChatdSkeleton extends StatelessWidget {
  const ChatdSkeleton({super.key, this.showLabel = true});

  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final label = context.l10n.chatdPhotoLoading;
    return Semantics(
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: LayoutBuilder(builder: (context, c) {
          final w = c.hasBoundedWidth ? c.maxWidth : 200.0;
          final h = c.hasBoundedHeight ? c.maxHeight : 150.0;
          final big = showLabel && h >= 90;
          return Stack(alignment: Alignment.center, children: [
            BuSkeleton(width: w, height: h, radius: 0),
            if (!big) Icon(LucideIcons.image, size: h < 70 ? 18 : 26, color: t.mut.withValues(alpha: .7)),
            if (big)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: t.sf, shape: BoxShape.circle, border: Border.all(color: t.bd)),
                    child: Icon(LucideIcons.image, size: 20, color: t.mut),
                  ),
                  const SizedBox(height: 10),
                  Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(context.l10n.p08PhotoLoadingSub, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall!.copyWith(color: t.mut)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BuRadius.bPill,
                    child: SizedBox(width: 120, height: 4, child: ColoredBox(color: t.sf, child: Align(alignment: AlignmentDirectional.centerStart, child: FractionallySizedBox(widthFactor: .35, heightFactor: 1, child: ColoredBox(color: t.ink))))),
                  ),
                ]),
              ),
          ]);
        }),
      ),
    );
  }
}

/// Sohbet başlığındaki "yazıyor" göstergesi: sondaki "…" yerine üç noktalı nabız (yalnız opacity; hareket
/// azaltılmışsa durağan). Durum satırı ile "yazıyor" arasındaki geçiş kısa solma ile yapılır.
class ChatTypingDots extends StatefulWidget {
  const ChatTypingDots({super.key, required this.color});

  final Color color;

  @override
  State<ChatTypingDots> createState() => _ChatTypingDotsState();
}

class _ChatTypingDotsState extends State<ChatTypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (BuMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = BuMotion.reduced(context);
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: EdgeInsetsDirectional.only(start: i == 0 ? 0 : 3),
                child: Opacity(
                  opacity: reduced ? .7 : .25 + .75 * _pulse((_c.value - i * .16) % 1.0),
                  child: Container(width: 4, height: 4, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  /// 0..1 arası yumuşak tepe (ilk %45'te yükselip iner, geri kalanda dinlenir).
  static double _pulse(double v) => v > .45 ? 0 : (1 - (v / .225 - 1).abs()).clamp(0.0, 1.0);
}
