import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'chat_media.dart';

/// Sohbet detay tasarımının sabit tonu (medya üstü koyu yüzeyler; her iki temada aynı).
const Color kChatdNavy = Color(0xFF171E33);

/// Medya üstü yarı saydam koyu zemin (hap, "+N", halka).
Color chatdScrim([double alpha = .66]) => kChatdNavy.withValues(alpha: alpha);

/// Video/yükleme üstü alt gölge.
const LinearGradient chatdBottomShade = LinearGradient(
  begin: Alignment.bottomCenter,
  end: Alignment.topCenter,
  colors: [Color(0x8C171E33), Color(0x00171E33)],
  stops: [0, .55],
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

/// Koyu, yuvarlak köşeli küçük hap (saat, süre, durum). Yazı 11 px / 600, beyaz.
class ChatdPill extends StatelessWidget {
  const ChatdPill({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: chatdScrim(), borderRadius: BorderRadius.circular(10)),
      child: DefaultTextStyle(
        style: BuType.micro.copyWith(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
        child: child,
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
    return ChatdPill(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(LucideIcons.video, size: 12, color: Colors.white),
        const SizedBox(width: 4),
        Text(formatMediaDuration(ms), textDirection: TextDirection.ltr),
      ]),
    );
  }
}

/// Oynat düğmesi: koyu yarı saydam daire + ince beyaz halka.
class ChatdPlay extends StatelessWidget {
  const ChatdPlay({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: chatdScrim(.62),
        border: Border.all(color: Colors.white.withValues(alpha: .85), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.play_arrow_rounded, size: size * .55, color: Colors.white),
    );
  }
}

/// İlerleme halkası: 56 px koyu daire, 3 px beyaz halka, ortada simge.
/// [value] null ise belirsiz (dönen) halka.
class ChatdRing extends StatelessWidget {
  const ChatdRing({super.key, this.value, required this.icon, this.semantics});

  final double? value;
  final IconData icon;
  final String? semantics;

  @override
  Widget build(BuildContext context) {
    final pct = value == null ? null : (value! * 100).round();
    return Semantics(
      label: semantics,
      value: pct == null ? null : '$pct%',
      child: ExcludeSemantics(
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: chatdScrim(), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 3,
                strokeCap: StrokeCap.round,
                color: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: .28),
              ),
            ),
            Icon(icon, size: 20, color: Colors.white),
          ]),
        ),
      ),
    );
  }
}

/// Ağdan inen görsel için yer tutucu: sıcak gri zemin, halka + görsel simgesi, "Fotoğraf yükleniyor…".
class ChatdSkeleton extends StatelessWidget {
  const ChatdSkeleton({super.key, this.showLabel = true});

  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final light = Color.alphaBlend(t.sf.withValues(alpha: .55), t.sf2);
    return Semantics(
      liveRegion: true,
      label: context.l10n.chatdPhotoLoading,
      child: ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: const Alignment(-1, -.3),
              end: const Alignment(1, .3),
              colors: [t.sf2, light, t.sf2],
              stops: const [.2, .45, .7],
            ),
          ),
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(
                  width: 38,
                  height: 38,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    strokeCap: StrokeCap.round,
                    color: t.mut,
                    backgroundColor: t.mut.withValues(alpha: .3),
                  ),
                ),
                Icon(LucideIcons.image, size: 20, color: t.mut),
              ]),
            ),
            if (showLabel)
              PositionedDirectional(
                start: 8,
                bottom: 8,
                child: Text(context.l10n.chatdPhotoLoading,
                    style: BuType.micro.copyWith(
                        color: t.mut, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
      ),
    );
  }
}
