import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'chat_bubble_colors.dart';
import 'chat_wallpaper.dart';

/// Profil > Ayarlar > Sohbetler > "Sohbet arka planı": mini konuşma önizlemesi, desen seçici (Ders, Sosyal,
/// Bilim, Geometri; düz zemin YOK), Yoğunluk Hafif | Orta, "Uygula", "Varsayılana dön".
///
/// Seçim "Uygula" ile cihazda (kullanıcıya özel) saklanır; arka plan konuşmada sabittir (kaydırmayla oynamaz).
class ChatBackgroundSettingsPage extends StatefulWidget {
  const ChatBackgroundSettingsPage({super.key});

  @override
  State<ChatBackgroundSettingsPage> createState() => _ChatBackgroundSettingsPageState();
}

class _ChatBackgroundSettingsPageState extends State<ChatBackgroundSettingsPage> {
  ChatBgStyle _style = ChatBackgroundPrefs.instance.style;
  ChatBgDensity _density = ChatBackgroundPrefs.instance.density;

  @override
  void initState() {
    super.initState();
    // Kayıtlı tercih sayfa açıldıktan sonra okunursa taslak onunla eşitlenir.
    ChatBackgroundPrefs.instance.ensureLoaded().then((_) {
      if (!mounted) return;
      setState(() {
        _style = ChatBackgroundPrefs.instance.style;
        _density = ChatBackgroundPrefs.instance.density;
      });
    });
  }

  Future<void> _apply() async {
    await ChatBackgroundPrefs.instance.set(_style, density: _density);
    if (mounted) Navigator.maybePop(context);
  }

  Future<void> _reset() async {
    setState(() {
      _style = ChatBgStyle.study;
      _density = ChatBgDensity.soft;
    });
    await ChatBackgroundPrefs.instance.set(ChatBgStyle.study, density: ChatBgDensity.soft);
  }

  String _label(ChatBgStyle s) {
    final l = context.l10n;
    return switch (s) {
      ChatBgStyle.study => l.p67ChatBgStyleStudy,
      ChatBgStyle.social => l.p67ChatBgStyleSocial,
      ChatBgStyle.science => l.p67ChatBgStyleScience,
      ChatBgStyle.geometry => l.p67ChatBgStyleGeometry,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(title: l.p67ChatBgTitle, onBack: () => Navigator.maybePop(context)),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.paddingOf(context).bottom),
              children: [
                // Önizleme: 1 dp bd çerçeveli, 16 dp köşeli mini konuşma (Bugün, gelen, giden).
                ClipRRect(
                  borderRadius: BuRadius.bMd,
                  child: DecoratedBox(
                    decoration: BoxDecoration(border: Border.all(color: t.bd), borderRadius: BuRadius.bMd),
                    child: SizedBox(
                      height: 150,
                      child: ChatWallpaper(
                        key: const ValueKey('chatBgPreview'),
                        style: _style,
                        density: _density,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(child: _PreviewPill(text: l.chatDetailToday)),
                              const Spacer(),
                              _PreviewBubble(text: l.p67ChatBgPreviewIn, time: '09:12', mine: false),
                              const SizedBox(height: 8),
                              _PreviewBubble(text: l.p67ChatBgPreviewOut, time: '09:14', mine: true),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(l.p67ChatBgStyleLabel, style: tx.bodyMedium!.copyWith(color: t.mut)),
                const SizedBox(height: 10),
                SizedBox(
                  key: const ValueKey('chatBgStyles'),
                  height: 148,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: ChatBgStyle.values.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final s = ChatBgStyle.values[i];
                      return _StyleSwatch(
                        key: ValueKey('chatBgStyle-${s.name}'),
                        style: s,
                        density: _density,
                        label: _label(s),
                        selected: s == _style,
                        onTap: () => setState(() => _style = s),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Text(l.p67ChatBgDensity, style: tx.bodyMedium!.copyWith(color: t.mut)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: BuSegmented(
                      key: const ValueKey('chatBgDensity'),
                      items: [l.p67ChatBgSoft, l.p67ChatBgStrong],
                      index: _density == ChatBgDensity.strong ? 1 : 0,
                      onChanged: (i) => setState(() => _density = i == 1 ? ChatBgDensity.strong : ChatBgDensity.soft),
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
                BuButton(key: const ValueKey('chatBgApply'), label: l.p67ChatBgApply, onPressed: _apply),
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    key: const ValueKey('chatBgReset'),
                    onPressed: _reset,
                    style: TextButton.styleFrom(foregroundColor: t.prText, minimumSize: const Size(48, 48)),
                    child: Text(l.p67ChatBgReset, style: tx.bodyMedium!.copyWith(color: t.prText, fontWeight: BuType.emphasisWeight)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Desen seçici karosu: küçük gerçek önizleme + ad; seçili olan 2 dp belirgin çerçeveli.
class _StyleSwatch extends StatelessWidget {
  const _StyleSwatch({
    super.key,
    required this.style,
    required this.density,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ChatBgStyle style;
  final ChatBgDensity density;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 96,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    border: Border.all(color: selected ? t.ink : t.bd, width: selected ? 2 : 1),
                    borderRadius: BuRadius.bMd,
                  ),
                  child: ClipRRect(
                    borderRadius: BuRadius.bMd,
                    child: IgnorePointer(child: ChatWallpaper(style: style, density: ChatBgDensity.strong, child: const SizedBox.expand())),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tx.labelMedium!.copyWith(color: selected ? t.ink : t.mut, fontWeight: BuType.emphasisWeight)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewPill extends StatelessWidget {
  const _PreviewPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(color: t.sf, border: Border.all(color: t.bdSubtle), borderRadius: BuRadius.bPill),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall!.copyWith(color: t.mut, fontWeight: BuType.emphasisWeight)),
    );
  }
}

/// Önizlemedeki örnek balon: gerçek balonla aynı renk/köşe düzeni ([ChatBubbleColors]: gelen gri yüzey + ince çizgi, giden birincil ton).
class _PreviewBubble extends StatelessWidget {
  const _PreviewBubble({required this.text, required this.time, required this.mine});

  final String text;
  final String time;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final bc = ChatBubbleColors.of(t);
    final tx = Theme.of(context).textTheme;
    const r = Radius.circular(14);
    const small = Radius.circular(4);
    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: mine ? bc.outgoing : bc.incoming,
          border: mine ? null : Border.all(color: t.bd),
          borderRadius: BorderRadiusDirectional.only(topStart: r, topEnd: mine ? small : r, bottomStart: mine ? r : small, bottomEnd: r),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: mine ? bc.onOutgoing : bc.onIncoming))),
          const SizedBox(width: 8),
          Text(time, style: tx.labelSmall!.copyWith(color: mine ? bc.metaOutgoing : bc.metaIncoming, fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      ),
    );
  }
}
