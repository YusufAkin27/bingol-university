import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'chat_wallpaper.dart';

/// Profil > Ayarlar > Sohbetler > "Sohbet arka planı" (Stitch v3 Kategori 6): başlık, mini konuşma önizlemesi,
/// segment Desen | Düz, Desen'de segment Yoğunluk Hafif | Orta, kırmızı "Uygula", "Varsayılana dön".
///
/// Eşleme: Desen + Hafif = varsayılan kampüs doodle duvar kağıdı ([ChatBgStyle.pattern]), Desen + Orta = daha belirgin
/// desen ([ChatBgStyle.strong]), Düz = [ChatBgStyle.plain]. Seçim "Uygula" ile cihazda (kullanıcıya özel) saklanır.
class ChatBackgroundSettingsPage extends StatefulWidget {
  const ChatBackgroundSettingsPage({super.key});

  @override
  State<ChatBackgroundSettingsPage> createState() => _ChatBackgroundSettingsPageState();
}

class _ChatBackgroundSettingsPageState extends State<ChatBackgroundSettingsPage> {
  late ChatBgStyle _draft = _normalize(ChatBackgroundPrefs.instance.style);

  /// Eski "Hafif" yordamsal stil artık varsayılan desenle birleşik gösterilir.
  static ChatBgStyle _normalize(ChatBgStyle s) => s == ChatBgStyle.soft ? ChatBgStyle.pattern : s;

  @override
  void initState() {
    super.initState();
    // Kayıtlı tercih sayfa açıldıktan sonra okunursa taslak onunla eşitlenir.
    ChatBackgroundPrefs.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _draft = _normalize(ChatBackgroundPrefs.instance.style));
    });
  }

  bool get _isPattern => _draft != ChatBgStyle.plain;

  Future<void> _apply() async {
    await ChatBackgroundPrefs.instance.set(_draft);
    if (mounted) Navigator.maybePop(context);
  }

  Future<void> _reset() async {
    setState(() => _draft = ChatBgStyle.pattern);
    await ChatBackgroundPrefs.instance.set(ChatBgStyle.pattern);
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
                        style: _draft,
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
                const SizedBox(height: 16),
                BuSegmented(
                  key: const ValueKey('chatBgMode'),
                  items: [l.p67ChatBgPattern, l.p67ChatBgPlain],
                  index: _isPattern ? 0 : 1,
                  onChanged: (i) => setState(() => _draft = i == 0 ? (_draft == ChatBgStyle.plain ? ChatBgStyle.pattern : _draft) : ChatBgStyle.plain),
                ),
                if (_isPattern) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Text(l.p67ChatBgDensity, style: tx.bodyMedium!.copyWith(color: t.mut)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: BuSegmented(
                        key: const ValueKey('chatBgDensity'),
                        items: [l.p67ChatBgSoft, l.p67ChatBgStrong],
                        index: _draft == ChatBgStyle.strong ? 1 : 0,
                        onChanged: (i) => setState(() => _draft = i == 1 ? ChatBgStyle.strong : ChatBgStyle.pattern),
                      ),
                    ),
                  ]),
                ],
                const SizedBox(height: 24),
                BuButton(key: const ValueKey('chatBgApply'), label: l.p67ChatBgApply, onPressed: _apply),
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    key: const ValueKey('chatBgReset'),
                    onPressed: _reset,
                    style: TextButton.styleFrom(foregroundColor: t.pr, minimumSize: const Size(48, 48)),
                    child: Text(l.p67ChatBgReset, style: tx.bodyMedium!.copyWith(color: t.pr, fontWeight: FontWeight.w500)),
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

class _PreviewPill extends StatelessWidget {
  const _PreviewPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(color: t.sf2, border: Border.all(color: t.bd), borderRadius: BuRadius.bPill),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall!.copyWith(color: t.mut, fontWeight: FontWeight.w500)),
    );
  }
}

/// Önizlemedeki örnek balon: gerçek balonla aynı renk/köşe düzeni (gelen: yüzey + ince çizgi, giden: marka rengi).
class _PreviewBubble extends StatelessWidget {
  const _PreviewBubble({required this.text, required this.time, required this.mine});

  final String text;
  final String time;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    const r = Radius.circular(14);
    const small = Radius.circular(4);
    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: mine ? t.pr : t.sf,
          border: mine ? null : Border.all(color: t.bd),
          borderRadius: BorderRadiusDirectional.only(topStart: r, topEnd: mine ? small : r, bottomStart: mine ? r : small, bottomEnd: r),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: mine ? t.onPr : t.ink))),
          const SizedBox(width: 8),
          Text(time, style: tx.labelSmall!.copyWith(color: mine ? t.onPr.withValues(alpha: .75) : t.mut, fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      ),
    );
  }
}
