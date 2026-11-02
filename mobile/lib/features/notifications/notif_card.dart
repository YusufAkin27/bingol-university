import 'package:flutter/material.dart';

import '../../core/push/rich/rich_card.dart';
import '../../widgets/bu.dart';

/// Bildirimler sayfası süzgeç kategorisi (tasarım 08 çipleri).
enum NotifCategory { all, messages, events, announcements, social, unread }

/// Bildirim türü -> kategori (SAF; istemci süzgeci). Bilinmeyen tür yalnız "Tümü"nde görünür (null).
NotifCategory? notifCategoryOf(String? type, {String? subtype}) {
  final t = (type ?? '').toUpperCase();
  final s = (subtype ?? '').toUpperCase();
  switch (t) {
    case 'MESSAGE':
      return NotifCategory.messages;
    case 'EVENT':
    case 'COMMUNITY':
      return NotifCategory.events;
    case 'ANNOUNCEMENT':
    case 'NEWS':
      return NotifCategory.announcements;
    case 'POST_LIKE':
    case 'POST_COMMENT':
    case 'COMMENT_REPLY':
    case 'POST_MENTION':
    case 'USER_FOLLOW':
    case 'FOLLOW':
    case 'FOLLOW_REQUEST':
    case 'FOLLOW_ACCEPTED':
      return NotifCategory.social;
  }
  if (s.startsWith('EVENT')) return NotifCategory.events;
  if (s.startsWith('MESSAGE')) return NotifCategory.messages;
  return null;
}

/// Satır -> kart türü (rozet simgesi ve uyarı satırı için). Yük `data` içinde de üst düzeyde de gelebilir.
RichKind notifKindOf(Map<String, dynamic> n, Map<String, dynamic> data) {
  Object? pick(String k) => n[k] ?? data[k];
  final merged = <String, dynamic>{
    ...data,
    'type': pick('type'),
    'subtype': pick('subtype'),
    'channelId': pick('channelId'),
  };
  final actionsRaw = pick('actions');
  final actions = <String>[
    if (actionsRaw is List)
      for (final a in actionsRaw) '$a'.toLowerCase()
    else
      for (final a in '${actionsRaw ?? ''}'.split(',')) a.trim().toLowerCase(),
  ].where((a) => a.isNotEmpty).toList();
  return resolveRichKind(merged, actions, count: 1, style: RichImageStyle.none);
}

/// Sistem rozeti: (simge, ton). Ton: 0 = marka yumuşak, 1 = tehlike, 2 = nötr, 3 = başarı.
({IconData icon, int tone}) notifBadgeOf(RichKind k) {
  switch (k) {
    case RichKind.newDeviceLogin:
      return (icon: BuIcons.shield, tone: 1);
    case RichKind.passwordChanged:
      return (icon: BuIcons.lockKeyhole, tone: 1);
    case RichKind.twoFaChanged:
      return (icon: BuIcons.shieldCheck, tone: 1);
    case RichKind.sessionReplaced:
      return (icon: BuIcons.logOut, tone: 1);
    case RichKind.eventTomorrow:
    case RichKind.eventSoon:
    case RichKind.eventUpdate:
      return (icon: BuIcons.calendarDays, tone: 0);
    case RichKind.eventApproved:
      return (icon: BuIcons.calendarCheck, tone: 3);
    case RichKind.eventCancelled:
      return (icon: BuIcons.calendarX, tone: 1);
    case RichKind.announcement:
      return (icon: BuIcons.megaphone, tone: 0);
    case RichKind.deptAnnouncement:
      return (icon: BuIcons.squareTerminal, tone: 2);
    case RichKind.academicAnnouncement:
    case RichKind.examReminder:
    case RichKind.classSoon:
      return (icon: BuIcons.graduationCap, tone: 0);
    case RichKind.homework:
      return (icon: BuIcons.notebookPen, tone: 0);
    case RichKind.news:
      return (icon: BuIcons.newspaper, tone: 2);
    case RichKind.menuToday:
      return (icon: BuIcons.utensils, tone: 2);
    case RichKind.pollNew:
    case RichKind.pollClosing:
      return (icon: BuIcons.vote, tone: 0);
    case RichKind.supportReply:
      return (icon: BuIcons.headset, tone: 0);
    case RichKind.postLike:
      return (icon: BuIcons.heartFilled, tone: 1);
    case RichKind.newFollower:
    case RichKind.followRequest:
    case RichKind.followAccepted:
      return (icon: BuIcons.userPlus, tone: 0);
    default:
      return (icon: BuIcons.bell, tone: 2);
  }
}

/// Satırın başında kişi avatarı mı gösterilir (sosyal + sohbet), yoksa sistem rozeti mi.
bool notifIsPerson(RichKind k) => isPersonKind(k);

/// Bildirim kartı (tasarım 08): okunmamış = açık zemin + çerçeve + kırmızı nokta; okunmuş = hafif gri zemin.
/// Solda avatar/rozet, başlık + zaman, gövde, isteğe bağlı eylem düğmeleri ve uyarı satırı.
class NotifCard extends StatelessWidget {
  const NotifCard({
    super.key,
    required this.title,
    required this.time,
    required this.unread,
    required this.onTap,
    required this.leading,
    this.body = '',
    this.semanticsLabel,
    this.actions,
    this.warning,
  });

  final String title, time, body;
  final bool unread;
  final VoidCallback onTap;
  final Widget leading;
  final String? semanticsLabel;

  /// Başlık altı eylem satırı (takip isteği: Onayla/Reddet).
  final Widget? actions;

  /// Kırmızı uyarı satırı (yeni cihaz girişi).
  final String? warning;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: BuPressable(
        scale: .985,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: unread ? t.sf : t.sf2.withValues(alpha: .6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: unread ? t.bd : Colors.transparent),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ExcludeSemantics(child: leading),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            child: AnimatedDefaultTextStyle(
                              duration: BuMotion.of(context, BuMotion.medium),
                              maxLines: body.isEmpty ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: BuType.caption.copyWith(
                                  fontSize: 15, height: 1.35, fontWeight: FontWeight.w700, color: unread ? t.ink : Color.lerp(t.ink, t.mut, .25)),
                              child: Text(title, maxLines: body.isEmpty ? 2 : 1, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(time, maxLines: 1, style: BuType.caption.copyWith(fontSize: 12, height: 1.3, color: t.mut)),
                          ),
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: SizedBox(
                              width: 8,
                              height: 8,
                              child: AnimatedScale(
                                key: const ValueKey('notif-unread-dot'),
                                scale: unread ? 1 : 0,
                                duration: BuMotion.of(context, BuMotion.medium),
                                curve: BuMotion.emphasizedDecelerate,
                                child: DecoratedBox(decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle)),
                              ),
                            ),
                          ),
                        ]),
                        if (body.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(body, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(fontSize: 14, height: 1.4, color: t.mut)),
                          ),
                        if (warning != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(children: [
                              Icon(BuIcons.triangleAlert, size: 14, color: t.danger),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(warning!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: BuType.caption.copyWith(fontSize: 12, height: 1.3, fontWeight: FontWeight.w600, color: t.danger)),
                              ),
                            ]),
                          ),
                        if (actions != null) Padding(padding: const EdgeInsets.only(top: 10), child: actions),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sistem rozeti (kişi olmayan satırlar): yuvarlatılmış kare + simge.
class NotifBadge extends StatelessWidget {
  const NotifBadge({super.key, required this.kind});

  final RichKind kind;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final b = notifBadgeOf(kind);
    final (bg, fg) = switch (b.tone) {
      1 => (t.dangerSoft, t.danger),
      3 => (t.okSoft, t.ok),
      2 => (t.sf2, t.mut),
      _ => (t.soft, t.onSoft),
    };
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Icon(b.icon, size: 22, color: fg),
    );
  }
}

/// Satır içi küçük eylem hapı (Onayla koyu, Reddet açık).
class NotifPill extends StatelessWidget {
  const NotifPill({super.key, required this.label, required this.primary, required this.onTap});

  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      child: Material(
        color: primary ? t.ink : t.sf2,
        borderRadius: BorderRadius.circular(BuRadius.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(BuRadius.pill),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36, minWidth: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Center(
                widthFactor: 1,
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BuType.caption.copyWith(fontSize: 13, height: 1.2, fontWeight: FontWeight.w700, color: primary ? t.bg : t.ink)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
