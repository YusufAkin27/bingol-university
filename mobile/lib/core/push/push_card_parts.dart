import 'package:flutter/material.dart';

import '../../widgets/bu.dart';

/// Bildirim kartÄ± ve gelen kutusu satÄ±rÄ±nÄ±n ortak kÃ¼Ã§Ã¼k parÃ§alarÄ± (tek gÃ¶rsel dil: tasarÄ±m 01-08).
/// Renkler yalnÄ±z [BuTokens] Ã¼zerinden gelir.

/// AvatarÄ±n kÃ¶ÅŸesindeki kÃ¼Ã§Ã¼k rozetin anlamÄ±.
enum PushAvatarRole { like, follow, request, accepted, mention }

/// [style] anahtarÄ±na gÃ¶re simge + renk ailesi (karo zemini/simgesi). Palet: marka, mavi, yeÅŸil, amber, su mavisi, nÃ¶tr.
IconData pushStyleIcon(String style) => switch (style) {
      'SECURITY' => BuIcons.shield,
      'EXAM' || 'ACADEMIC' => BuIcons.graduationCap,
      'EVENT_REMINDER' => BuIcons.calendar,
      'EVENT_ADMISSION' => BuIcons.calendarCheck,
      'EVENT_UPDATE' || 'EVENT' => BuIcons.calendarClock,
      'EVENT_CANCELLED' => BuIcons.calendarX,
      'MODERATION' => BuIcons.shieldAlert,
      'FORUM' => BuIcons.messageSquareText,
      'POLL' => BuIcons.vote,
      'SUPPORT' => BuIcons.headset,
      'MEAL' => BuIcons.utensils,
      'SYSTEM' => BuIcons.info,
      'MENTION' => BuIcons.atSign,
      'FOLLOW' || 'FOLLOW_REQUEST' || 'FOLLOW_ACCEPTED' || 'CLUB_JOIN_REQUEST' || 'SOCIAL' || 'LIKE' => BuIcons.users,
      'CHAT_GROUP' => BuIcons.users,
      'CHAT_DIRECT' || 'CHAT_MEDIA' => BuIcons.messageCircle,
      _ => BuIcons.megaphone,
    };

BuTint pushStyleTint(BuTokens t, String style) => t.tints[switch (style) {
      'SECURITY' || 'EVENT_CANCELLED' => BuTintId.brand,
      'EXAM' || 'ACADEMIC' => BuTintId.blue,
      'EVENT_REMINDER' || 'EVENT_ADMISSION' || 'EVENT_UPDATE' || 'EVENT' => BuTintId.blue,
      'POLL' => BuTintId.aqua,
      'MEAL' => BuTintId.amber,
      'SUPPORT' || 'SYSTEM' || 'MODERATION' || 'FORUM' || 'LIKE' || 'MENTION' || 'SOCIAL' || 'FOLLOW' || 'FOLLOW_REQUEST' || 'FOLLOW_ACCEPTED' || 'CLUB_JOIN_REQUEST' => BuTintId.slate,
      _ => BuTintId.brand,
    }];

/// Pastel zeminli kategori karosu (avatarÄ± olmayan bildirimler).
class PushTile extends StatelessWidget {
  const PushTile({super.key, required this.style, this.size = 46, this.icon});

  final String style;
  final double size;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tint = pushStyleTint(context.bu, style);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: tint.bg, borderRadius: BorderRadius.circular(size * .32)),
      // Kenarlık yerleşimi daraltmasın (sabit boyutlu karoda taşma): ön plan dekorasyonu.
      foregroundDecoration: BoxDecoration(borderRadius: BorderRadius.circular(size * .32), border: Border.all(color: context.bu.bd)),
      child: Icon(icon ?? pushStyleIcon(style), size: size * .5, color: tint.fg),
    );
  }
}

/// Etkinlik iÃ§in tarih karosu ("KAS / 2"): yalnÄ±z gerÃ§ek baÅŸlangÄ±Ã§ zamanÄ± varsa Ã§izilir.
class PushDateTile extends StatelessWidget {
  const PushDateTile({super.key, required this.month, required this.day, this.size = 44});

  final String month, day;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tint = t.tints[BuTintId.blue];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tint.bg, borderRadius: BorderRadius.circular(size * .3)),
      foregroundDecoration: BoxDecoration(borderRadius: BorderRadius.circular(size * .3), border: Border.all(color: t.bd)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(month, maxLines: 1, style: BuType.caption.copyWith(fontSize: 11, height: 1.1, fontWeight: FontWeight.w400, color: tint.fg)),
        Text(day, maxLines: 1, style: BuType.caption.copyWith(fontSize: 17, height: 1.1, fontWeight: FontWeight.w400, color: tint.fg)),
      ]),
    );
  }
}

/// KiÅŸi avatarÄ± + kÃ¶ÅŸe rozeti (kalp / kiÅŸi+ / kilit / onay) ya da sayÄ± rozeti.
class PushAvatar extends StatelessWidget {
  const PushAvatar({
    super.key,
    required this.name,
    this.url,
    this.size = 46,
    this.role,
    this.count = 0,
    this.group = false,
    this.headers,
  });

  final String name;
  final String? url;
  final double size;
  final PushAvatarRole? role;

  /// 1'den bÃ¼yÃ¼kse avatarÄ±n Ã¼stÃ¼nde kÄ±rmÄ±zÄ± sayÄ± rozeti (birleÅŸik sohbet bildirimi).
  final int count;
  final bool group;
  final Map<String, String>? headers;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final badge = size * .42;
    final roleStyle = switch (role) {
      PushAvatarRole.like => (BuIcons.heartFilled, t.heart, t.onMedia),
      PushAvatarRole.follow => (BuIcons.userPlus, t.ink, t.bg),
      PushAvatarRole.request => (BuIcons.lock, t.ink, t.bg),
      PushAvatarRole.accepted => (BuIcons.check, t.ok, t.sf),
      PushAvatarRole.mention => (BuIcons.atSign, t.pr, t.onPr),
      null => null,
    };
    return SizedBox(
      width: size + 4,
      height: size + 4,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(child: Align(alignment: AlignmentDirectional.centerStart, child: BuAvatar(name: name, url: url, size: size, group: group, headers: headers))),
        if (count > 1)
          PositionedDirectional(
            top: -3,
            start: -3,
            child: Container(
              constraints: BoxConstraints(minWidth: badge, minHeight: badge),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: t.pr, shape: BoxShape.rectangle, borderRadius: BorderRadius.circular(badge), border: Border.all(color: t.sf, width: 1.5)),
              child: Text(count > 99 ? '99+' : '$count',
                  maxLines: 1, style: BuType.caption.copyWith(fontSize: 11, height: 1.1, fontWeight: FontWeight.w400, color: t.onPr)),
            ),
          )
        else if (roleStyle != null)
          PositionedDirectional(
            bottom: -1,
            end: -1,
            child: Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(color: roleStyle.$2, shape: BoxShape.circle, border: Border.all(color: t.sf, width: 1.5)),
              child: Icon(roleStyle.$1, size: badge * .62, color: roleStyle.$3),
            ),
          ),
      ]),
    );
  }
}

enum PushChipTone { neutral, danger, ok, info, warn }

/// BaÅŸlÄ±k yanÄ± etiketi ya da bilgi Ã§ipi (zemin + yazÄ± aynÄ± aileden; AA).
class PushChip extends StatelessWidget {
  const PushChip({super.key, required this.label, this.icon, this.tone = PushChipTone.neutral, this.maxWidth = 220, this.strike = false});

  final String label;
  final IconData? icon;
  final PushChipTone tone;
  final double maxWidth;
  final bool strike;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final (bg, fg) = switch (tone) {
      PushChipTone.danger => (t.dangerSoft, t.danger),
      PushChipTone.ok => (t.okSoft, t.onOkSoft),
      PushChipTone.info => (t.infoSoft, t.onInfoSoft),
      PushChipTone.warn => (t.warnSoft, t.onWarnSoft),
      PushChipTone.neutral => (t.sf2, t.ink),
    };
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(BuRadius.pill)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BuType.caption.copyWith(
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w400,
                    color: fg,
                    decoration: strike ? TextDecoration.lineThrough : null)),
          ),
        ]),
      ),
    );
  }
}

/// Aksiyon dÃ¼ÄŸmesi (hap): birincil = koyu ya da kÄ±rmÄ±zÄ± dolgu, ikincil = soluk gri.
enum PushButtonKind { secondary, primary, accent }

class PushActionButton extends StatelessWidget {
  const PushActionButton({super.key, required this.label, required this.icon, required this.onPressed, this.kind = PushButtonKind.secondary, this.minHeight = 44});

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final PushButtonKind kind;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final (bg, fg) = switch (kind) {
      PushButtonKind.primary => (t.ink, t.bg),
      PushButtonKind.accent => (t.prPressed, t.onPr),
      PushButtonKind.secondary => (t.sf2, t.ink),
    };
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: Size(0, minHeight),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: bg,
        disabledBackgroundColor: bg.withValues(alpha: .5),
        foregroundColor: fg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: BuType.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w400),
      ),
      icon: Icon(icon, size: 14),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
