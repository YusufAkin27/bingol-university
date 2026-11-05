import 'package:flutter/material.dart';

import '../../../../core/locale_controller.dart';
import '../../../../widgets/bu.dart';

/// Keşfet'te belirgin "Kampüs Forum" giriş şeridi: nötr yüzey, ince çerçeve; kırmızı yalnız simge karosunda.
/// Dokununca forum ana sayfası açılır ([onTap]). Başlık bir İÇERİK başlığıdır (sayfa başlığı değil), bu yüzden görünür.
class ForumEntryStrip extends StatelessWidget {
  const ForumEntryStrip({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Semantics(
      button: true,
      label: '${l.forumHomeA11y}. ${l.forumHomeStripSub}',
      excludeSemantics: true,
      child: BuPressable(
        key: const ValueKey('forum-entry-strip'),
        onTap: onTap,
        haptic: BuHaptic.selection,
        scale: .98,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: t.sf,
              borderRadius: BorderRadius.circular(BuRadius.lg),
              border: Border.all(color: t.bd),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 12, 10),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(BuRadius.sm)),
                  child: Icon(BuIcons.messageSquareText, size: 22, color: t.pr),
                ),
                BuGap.w12,
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(l.forumHomeA11y,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleMedium?.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
                    Text(l.forumHomeStripSub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(color: t.mut)),
                  ]),
                ),
                BuGap.w8,
                Icon(buDirIcon(context, BuIcons.chevronRight), size: 20, color: t.mut),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
