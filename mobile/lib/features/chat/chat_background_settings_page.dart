import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'chat_wallpaper.dart';

/// Profil > Ayarlar > Sohbetler > "Sohbet arka planı": Desen (varsayılan), Hafif, Orta, Düz.
///
/// Tercih cihazda ve kullanıcıya özel saklanır ([ChatBackgroundPrefs]; çıkışta silinir), sunucu ucu yoktur. Üstte
/// seçimi canlı gösteren sakin bir önizleme (iki örnek balon); seçenek satırına dokunmak hemen uygular.
class ChatBackgroundSettingsPage extends StatelessWidget {
  const ChatBackgroundSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final prefs = ChatBackgroundPrefs.instance;
    final labels = {
      ChatBgStyle.pattern: l.p67ChatBgPattern,
      ChatBgStyle.soft: l.p67ChatBgSoft,
      ChatBgStyle.strong: l.p67ChatBgStrong,
      ChatBgStyle.plain: l.p67ChatBgPlain,
    };
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(title: l.p67ChatBgTitle, onBack: () => Navigator.maybePop(context)),
          Expanded(
            child: ListenableBuilder(
              listenable: prefs,
              builder: (context, _) {
                final current = prefs.style;
                return ListView(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.paddingOf(context).bottom),
                  children: [
                    ClipRRect(
                      borderRadius: BuRadius.bLg,
                      child: DecoratedBox(
                        decoration: BoxDecoration(border: Border.all(color: t.bd), borderRadius: BuRadius.bLg),
                        child: SizedBox(
                          height: 216,
                          child: ChatWallpaper(
                            key: const ValueKey('chatBgPreview'),
                            style: current,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _PreviewBubble(text: l.p67ChatBgPreviewIn, mine: false),
                                  const SizedBox(height: 8),
                                  _PreviewBubble(text: l.p67ChatBgPreviewOut, mine: true),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    for (final s in [ChatBgStyle.pattern, ChatBgStyle.soft, ChatBgStyle.strong, ChatBgStyle.plain])
                      Semantics(
                        button: true,
                        selected: current == s,
                        label: labels[s],
                        excludeSemantics: true,
                        child: InkWell(
                          key: ValueKey('chatBg-${s.name}'),
                          borderRadius: BuRadius.bMd,
                          onTap: () {
                            if (current != s) HapticFeedback.selectionClick();
                            prefs.set(s);
                          },
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: BuSize.row),
                            child: Row(children: [
                              Expanded(child: Text(labels[s]!, style: tx.bodyLarge!.copyWith(color: t.ink, fontWeight: current == s ? FontWeight.w600 : FontWeight.w400))),
                              AnimatedSwitcher(
                                duration: BuMotion.of(context, BuMotion.short),
                                child: current == s
                                    ? Icon(LucideIcons.check, key: const ValueKey('on'), size: 22, color: t.pr)
                                    : const SizedBox(key: ValueKey('off'), width: 22, height: 22),
                              ),
                            ]),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Önizlemedeki örnek balon: gerçek balonla aynı renk/köşe düzeni (gelen: yüzey + ince çizgi, giden: marka rengi).
class _PreviewBubble extends StatelessWidget {
  const _PreviewBubble({required this.text, required this.mine});

  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    const r = Radius.circular(20);
    const small = Radius.circular(6);
    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: mine ? t.pr : t.sf,
          border: mine ? null : Border.all(color: t.bd),
          borderRadius: BorderRadiusDirectional.only(topStart: r, topEnd: r, bottomStart: mine ? r : small, bottomEnd: mine ? small : r),
        ),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: mine ? t.onPr : t.ink)),
      ),
    );
  }
}
