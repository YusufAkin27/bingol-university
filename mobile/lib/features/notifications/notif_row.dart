import 'package:flutter/material.dart';

import '../../core/push/push_card_parts.dart';
import '../../widgets/bu.dart';

/// Gelen kutusu satırı (tasarım 08): solda avatar + köşe rozeti ya da pastel kategori karosu; başlık + sağda
/// "12 dk önce" + okunmamış noktası; 2 satır gövde; okunmamış satırda bağlamsal aksiyonlar. Okunmuş satır `sf2` zeminlidir.
class NotifRow extends StatelessWidget {
  const NotifRow({
    super.key,
    required this.title,
    required this.typeLabel,
    required this.time,
    required this.unread,
    required this.onTap,
    this.body = '',
    this.unreadLabel,
    this.style = 'ANNOUNCEMENT',
    this.icon,
    this.avatar,
    this.source,
    this.actions = const [],
    this.critical = false,
    this.badge,
    this.badgeTone = PushChipTone.neutral,
    this.chips = const [],
  });

  final String title, typeLabel, time, body;
  final bool unread, critical;
  final VoidCallback onTap;
  final String? unreadLabel;

  /// Kart stili (`pushCardStyle`): karo simgesi/rengi buradan gelir.
  final String style;
  final IconData? icon;

  /// Kişi bildirimlerinde avatar (PushAvatar); verilirse karo yerine çizilir.
  final Widget? avatar;

  /// Kaynak etiketi (kulüp/etkinlik düzenleyicisi): yalnız sunucu verirse başlığın üstünde küçük satır.
  final String? source;
  final List<Widget> actions;

  /// Başlık yanı etiketi (ör. İptal, Saat Revizesi); yalnız sunucu verirse.
  final String? badge;
  final PushChipTone badgeTone;

  /// Gövde altı bilgi çipleri (etkinlik saati, kcal...).
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final radius = BorderRadius.circular(22);
    final timeStyle = BuType.caption.copyWith(fontSize: 12, height: 1.3, color: t.mut);
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 11.5 || MediaQuery.sizeOf(context).width < 340;
    final sourceStyle = BuType.caption.copyWith(fontSize: 12, height: 1.3, fontWeight: FontWeight.w400, color: t.prText);
    final timeBox = Row(mainAxisSize: MainAxisSize.min, children: [
      Text(time, style: timeStyle),
      const SizedBox(width: 4),
      AnimatedContainer(
        key: const ValueKey('notif-unread-dot'),
        duration: BuMotion.of(context, BuMotion.short),
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: unread ? t.pr : Colors.transparent, shape: BoxShape.circle),
      ),
    ]);
    final titleText = Text.rich(
      TextSpan(style: BuType.caption.copyWith(fontSize: 16, height: 1.3, fontWeight: FontWeight.w400, color: t.ink), children: [
        TextSpan(text: title),
        if (badge != null)
          WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(padding: const EdgeInsetsDirectional.only(start: 8), child: PushChip(label: badge!, tone: badgeTone, maxWidth: 150))),
      ]),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        label: [
          if (unread && unreadLabel != null) unreadLabel!,
          typeLabel,
          time
        ].where((s) => s.isNotEmpty).join(', '),
        child: Material(
          color: unread ? t.sf : t.sf2,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Container(
              decoration: critical ? BoxDecoration(border: Border(top: BorderSide(color: t.danger, width: 3))) : null,
              padding: const EdgeInsets.all(14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ExcludeSemantics(child: avatar ?? PushTile(style: style, icon: icon)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (stacked)
                    // Dar ekran / büyük yazı: zaman üst satıra çıkar, başlık tam genişlikte kalır (kelime bölünmesin).
                    Row(children: [
                      Expanded(
                          child: source != null && source!.isNotEmpty
                              ? Text(source!, maxLines: 1, overflow: TextOverflow.ellipsis, style: sourceStyle)
                              : const SizedBox.shrink()),
                      timeBox,
                    ])
                  else if (source != null && source!.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(source!, maxLines: 1, overflow: TextOverflow.ellipsis, style: sourceStyle)),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: titleText),
                    if (!stacked) ...[const SizedBox(width: 8), Padding(padding: const EdgeInsets.only(top: 3), child: timeBox)],
                  ]),
                  if (body.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(body, maxLines: 3, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(fontSize: 14, height: 1.4, color: t.mut)),
                    ),
                  if (chips.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 6, runSpacing: 4, children: chips)),
                  if (actions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(spacing: 8, runSpacing: 4, children: actions),
                    ),
                ])),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
