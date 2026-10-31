import 'package:flutter/material.dart';

import '../../widgets/bu.dart';

/// Bildirim türü tonu: tema belirteçlerinden (açık/koyu kendiliğinden).
enum NotifTone {
  red,
  blue,
  green,
  amber,
  aqua,
  slate;

  BuTint tint(BuildContext c) {
    final t = c.bu;
    return switch (this) {
      NotifTone.red => t.tint(BuTintId.brand),
      NotifTone.blue => t.tint(BuTintId.blue),
      NotifTone.green => t.tint(BuTintId.green),
      NotifTone.amber => t.tint(BuTintId.amber),
      NotifTone.aqua => t.tint(BuTintId.aqua),
      NotifTone.slate => t.tint(BuTintId.slate),
    };
  }

  Color fg(BuildContext c) => tint(c).fg;
  Color bg(BuildContext c) => tint(c).bg;
}

/// Renkli ikon karosu (bildirim satırı ve akademik ekran ortak kullanır).
class NotifIconTile extends StatelessWidget {
  const NotifIconTile({super.key, required this.icon, required this.tone, this.size = 44, this.radius = 14});

  final IconData icon;
  final NotifTone tone;
  final double size, radius;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: tone.bg(context), borderRadius: BorderRadius.circular(radius)),
        child: Icon(icon, size: size * .5, color: tone.fg(context)),
      );
}

/// Bildirim satırı (referans: 15/16): sol yuvarlak tür simgesi (okunmamışta köşe noktası), üstte tür etiketi +
/// kısa zaman, altında başlık (tek satır) ve en çok iki satır gövde.
class NotifRow extends StatelessWidget {
  const NotifRow({
    super.key,
    required this.icon,
    required this.tone,
    required this.title,
    required this.typeLabel,
    required this.time,
    required this.unread,
    required this.onTap,
    this.body = '',
    this.unreadLabel,
    this.strong = false,
  });

  /// true: koyu (mürekkep) daire + açık simge (etkinlik/duyuru türleri).
  final bool strong;
  final IconData icon;
  final NotifTone tone;
  final String title, typeLabel, time, body;
  final bool unread;
  final VoidCallback onTap;
  final String? unreadLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(20);
    // Koyu daireli türlerde etiket mavi tonda (referans); diğerlerinde dairenin tonunda.
    final chipTone = strong ? NotifTone.blue : tone;
    final chipBg = chipTone.bg(context);
    final chipFg = chipTone.fg(context);
    final circleBg = strong ? t.ink : tone.bg(context);
    final circleFg = strong ? t.bg : tone.fg(context);
    return Semantics(
      button: true,
      label: unread ? unreadLabel : null,
      // Basılı tutunca hafif küçülür (dokunmayı içerideki InkWell yakalar).
      child: BuPressable(
        scale: .985,
        child: Container(
        decoration: BoxDecoration(
          color: t.sf,
          borderRadius: radius,
          border: Border.all(color: t.bd.withValues(alpha: .6)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(clipBehavior: Clip.none, children: [
                    Container(
                      width: 46,
                      height: 46,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(color: circleBg, shape: BoxShape.circle),
                      child: Icon(icon, size: 22, color: circleFg),
                    ),
                    // Okundu olunca nokta küçülerek solar (ağaçta kalır; yalnız transform + opaklık).
                    PositionedDirectional(
                      end: 0,
                      top: 0,
                      child: AnimatedScale(
                        key: const ValueKey('notif-unread-dot'),
                        scale: unread ? 1 : 0,
                        duration: BuMotion.of(context, BuMotion.medium),
                        curve: BuMotion.emphasizedDecelerate,
                        child: AnimatedOpacity(
                          opacity: unread ? 1 : 0,
                          duration: BuMotion.of(context, BuMotion.short),
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                                color: t.pr, shape: BoxShape.circle, border: Border.all(color: t.sf, width: 2)),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child:
                      Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(BuRadius.pill)),
                            child: Text(typeLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w700, color: chipFg)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(time,
                          maxLines: 1, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w500, color: t.mut)),
                    ]),
                    const SizedBox(height: 6),
                    // Gövde yoksa başlık iki satıra kadar okunur (mesajın kendisi); gövde varsa tek satır.
                    // Okundu olunca başlık yumuşakça hafifler (kalınlık + ton, 250 ms).
                    AnimatedDefaultTextStyle(
                      duration: BuMotion.of(context, BuMotion.medium),
                      maxLines: body.isEmpty ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: tx.titleMedium!.copyWith(
                          height: 1.25,
                          color: unread ? t.ink : Color.lerp(t.ink, t.mut, .3),
                          fontWeight: unread ? FontWeight.w800 : FontWeight.w600),
                      child: Text(title, maxLines: body.isEmpty ? 2 : 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (body.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tx.bodyMedium!.copyWith(height: 1.4, color: t.mut)),
                      ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        ),
      ),
    );
  }
}
