import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';

const eventMonthShort = ['OCA', 'ŞUB', 'MAR', 'NİS', 'MAY', 'HAZ', 'TEM', 'AĞU', 'EYL', 'EKİ', 'KAS', 'ARA'];

/// Dile göre kısa ay adı (1-12), rozet için.
String eventMonthShortOf(BuildContext c, int m) {
  final l = c.l10n;
  return [
    l.eventListMon1, l.eventListMon2, l.eventListMon3, l.eventListMon4,
    l.eventListMon5, l.eventListMon6, l.eventListMon7, l.eventListMon8,
    l.eventListMon9, l.eventListMon10, l.eventListMon11, l.eventListMon12,
  ][m - 1];
}

/// Dile göre ay adı (1-12).
String eventMonthNameOf(BuildContext c, int m) {
  final l = c.l10n;
  return [
    l.eventListMonth1, l.eventListMonth2, l.eventListMonth3, l.eventListMonth4,
    l.eventListMonth5, l.eventListMonth6, l.eventListMonth7, l.eventListMonth8,
    l.eventListMonth9, l.eventListMonth10, l.eventListMonth11, l.eventListMonth12,
  ][m - 1];
}

/// Dile göre kısa gün adı (DateTime.weekday: 1 Pzt - 7 Paz).
String eventDayShortOf(BuildContext c, int w) {
  final l = c.l10n;
  return [
    l.eventListDayShort1, l.eventListDayShort2, l.eventListDayShort3,
    l.eventListDayShort4, l.eventListDayShort5, l.eventListDayShort6,
    l.eventListDayShort7,
  ][w - 1];
}

/// Dile göre "5 Ekim, Pazartesi" biçimli tarih.
String eventLongDateOf(BuildContext c, DateTime d) {
  final l = c.l10n;
  final wd = [
    l.eventListDayLong1, l.eventListDayLong2, l.eventListDayLong3,
    l.eventListDayLong4, l.eventListDayLong5, l.eventListDayLong6,
    l.eventListDayLong7,
  ][d.weekday - 1];
  return l.eventListLongDate('${d.day}', eventMonthNameOf(c, d.month), wd);
}

String eventHm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Kayıtlar kapalı etkinlikte katılım isteği 409 `EVENT_REGISTRATION_CLOSED` döner.
String eventErrorText(Object e) {
  if (e is ApiError && e.code == 'EVENT_REGISTRATION_CLOSED' && e.message.isEmpty) {
    return 'Bu etkinliğin kayıtları kapalı.';
  }
  return errorText(e);
}

/// Bağlamlı (yerelleştirilmiş) sürüm.
String eventErrorTextL(BuildContext context, Object e) {
  if (e is ApiError && e.code == 'EVENT_REGISTRATION_CLOSED' && e.message.isEmpty) {
    return context.l10n.eventListRegClosedError;
  }
  return errorText(e);
}

bool eventIsCancelled(Map<String, dynamic> e) => e['status'] == 'CANCELLED';
bool eventIsPendingReview(Map<String, dynamic> e) => e['status'] == 'PENDING_REVIEW';
bool eventIsRejected(Map<String, dynamic> e) => e['status'] == 'REJECTED';

/// Admin reddinde varsa neden (alan adı sunucuya göre değişebilir).
String? eventRejectReason(Map<String, dynamic> e) {
  for (final k in const ['rejectReason', 'rejectionReason', 'reviewNote']) {
    final v = e[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

/// Etkinlik oluşturma/düzenleme hatası: kulüp kuralı kodları her zaman yerel (açık) metinle,
/// diğerlerinde sunucunun istek dilindeki mesajı, boşsa koda göre yerel metin.
String eventSaveErrorText(BuildContext context, Object e) {
  final l = context.l10n;
  if (e is ApiError && !e.isNetwork) {
    switch (e.code) {
      case 'EVENT_CLUB_REQUIRED':
        return l.evcErrClubRequired;
      case 'FORBIDDEN':
        return l.evcErrForbidden;
    }
    if (e.status == 403) return l.evcErrForbidden;
    if (e.message.isEmpty) {
      switch (e.code) {
        case 'COMMUNITY_NOT_ACTIVE':
          return l.evcErrClubNotActive;
        case 'EVENT_NOT_FOUND':
          return l.eventFormNotFound;
        case 'PAST_EVENT':
          return l.evcErrPast;
        case 'INVALID_DATES':
          return l.evcErrDates;
        case 'EVENT_DESCRIPTION_TOO_LONG':
          return l.evdErrDescTooLongServer;
        case 'CONTENT_PROFANITY':
          return l.evcErrProfanity;
      }
    }
  }
  return errorText(e);
}

bool eventIsNotFound(Object e) => e is ApiError && e.status == 404;
bool eventIsClosed(Map<String, dynamic> e) => e['registrationClosed'] == true;

/// Katıldıktan sonra kısa onay: "Etkinliklerime eklendi" + "Etkinliklerim" kısayolu.
void showJoinedToast(BuildContext context, VoidCallback openMine) {
  BuToast.show(
    context,
    context.l10n.eventListAddedMine,
    kind: BuToastKind.success,
    actionLabel: context.l10n.eventListTabMine,
    onAction: openMine,
  );
}

/// Onay diyaloğu; onaylanırsa `true`. [danger] true: onay düğmesi kırmızı. [centered] true: simge + başlık ortada
/// (iptal onayı), false: sola hizalı (katılımdan ayrıl). Vazgeç düğmesi nötr gridir.
Future<bool> confirmEventDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
  IconData? icon,
  bool centered = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => _EventConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: c.l10n.eventListDismiss,
      danger: danger,
      centered: centered,
      icon: icon ?? (danger ? LucideIcons.triangleAlert : LucideIcons.circleHelp),
    ),
  );
  return r == true;
}

class _EventConfirmDialog extends StatelessWidget {
  const _EventConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.danger,
    required this.centered,
    required this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool danger;
  final bool centered;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final align = centered ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final ta = centered ? TextAlign.center : TextAlign.start;
    final iconBg = centered && danger ? t.danger.withValues(alpha: .12) : t.mut.withValues(alpha: .12);
    final iconFg = centered && danger ? t.danger : t.ink;
    Widget btn(Key key, String label, Color bg, Color fg, bool result) => Expanded(
          child: Material(
            color: bg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BuRadius.md)),
            child: InkWell(
              key: key,
              borderRadius: BorderRadius.circular(BuRadius.md),
              onTap: () => Navigator.pop(context, result),
              child: Container(
                constraints: const BoxConstraints(minHeight: BuSize.button),
                alignment: Alignment.center,
                child: Text(label, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: fg)),
              ),
            ),
          ),
        );
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: align, children: [
          ExcludeSemantics(
            child: Container(
              width: centered ? 56 : 44,
              height: centered ? 56 : 44,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, size: centered ? 28 : 22, color: iconFg),
            ),
          ),
          const SizedBox(height: 14),
          Semantics(header: true, child: Text(title, textAlign: ta, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w700, color: t.ink))),
          const SizedBox(height: 6),
          Text(message, textAlign: ta, style: tx.bodyMedium!.copyWith(height: 1.45, color: t.mut)),
          const SizedBox(height: 20),
          Row(children: [
            btn(const ValueKey('event-confirm-no'), cancelLabel, t.mut.withValues(alpha: .12), t.ink, false),
            const SizedBox(width: 10),
            btn(const ValueKey('event-confirm-yes'), confirmLabel, danger ? t.danger : t.pr, t.onPr, true),
          ]),
        ]),
      ),
    );
  }
}

/// Katılım durumu çipi: "Etkinliklerimde" (dokununca Etkinliklerim açılır, geri alma yapmaz).
class EventJoinedChip extends StatelessWidget {
  const EventJoinedChip({super.key, this.label, this.onTap, this.large = false});

  final String? label;
  final VoidCallback? onTap;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final chip = Container(
      height: large ? 54 : 36,
      padding: EdgeInsets.symmetric(horizontal: large ? 20 : 14),
      alignment: Alignment.center,
      decoration: ShapeDecoration(color: t.okSoft, shape: const StadiumBorder()),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(LucideIcons.calendarCheck, size: large ? 19 : 15, color: t.ok),
        const SizedBox(width: 8),
        Flexible(
          child: Text(label ?? context.l10n.eventListInMine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (large ? tx.titleMedium! : tx.labelLarge!).copyWith(color: t.ok, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
    if (onTap == null) return chip;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: large ? 54 : 48),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: BuPressable(scale: .96, onTap: onTap, haptic: BuHaptic.light, child: chip),
      ),
    );
  }
}

/// Küçük durum etiketi (Açık / Kayıt kapalı / İptal). [icon] verilirse başta küçük simge.
class EventStatusTag extends StatelessWidget {
  const EventStatusTag(this.label, {super.key, this.tone = EventTone.ok, this.icon, this.dot = false});

  final String label;
  final EventTone tone;
  final IconData? icon;

  /// true: başta küçük renkli nokta (Açık / Katılıyor).
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final (bg, fg) = switch (tone) {
      EventTone.ok => (t.okSoft, t.ok),
      EventTone.warn => (t.warnSoft, t.onWarnSoft),
      EventTone.danger => (t.danger.withValues(alpha: .14), t.danger),
      EventTone.neutral => (t.mut.withValues(alpha: .12), t.mut),
      EventTone.brand => (t.soft, t.onSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot) ...[
          Container(width: 7, height: 7, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          const SizedBox(width: 6),
        ] else if (icon != null) ...[
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium!.copyWith(color: fg, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

enum EventTone { ok, warn, danger, neutral, brand }

/// Tarih rozeti: ay kısaltması + gün. [onCover] true: fotoğraf üstünde okunur sabit açık zemin.
class EventDateBadge extends StatelessWidget {
  const EventDateBadge(this.day, {super.key, this.onCover = false});

  final DateTime? day;
  final bool onCover;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    // Kapak üstünde tema fark etmeksizin açık zemin + koyu kırmızı yazı (fotoğrafta yüksek kontrast).
    final bg = onCover ? BuTokens.light.sf : t.soft;
    final fg = onCover ? BuTokens.light.onSoft : t.onSoft;
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return ExcludeSemantics(
      child: Container(
        width: 52,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: onCover ? [BoxShadow(color: t.scrim.withValues(alpha: .18), blurRadius: 8, offset: const Offset(0, 2))] : null,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(day == null ? '' : eventMonthShortOf(context, day!.month),
              style: tx.labelSmall!.copyWith(color: fg, fontWeight: FontWeight.w800, letterSpacing: ar ? 0 : .6)),
          Text(day == null ? '' : '${day!.day}', style: tx.titleLarge!.copyWith(height: 1.1, color: fg, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

/// Katılımcı avatar yığını + sayı. [avatars] boşsa yalnızca ikon + sayı.
class EventAvatarStack extends StatelessWidget {
  const EventAvatarStack({super.key, required this.avatars, required this.total});

  final List<Map<String, dynamic>> avatars;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final shown = avatars.take(3).toList();
    const size = 28.0;
    const step = 17.0;
    return Semantics(
      label: context.l10n.eventListAttendeeCount('$total'),
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (shown.isEmpty)
          Icon(LucideIcons.users, size: 15, color: t.mut)
        else
          SizedBox(
            height: size,
            width: size + (shown.length - 1) * step,
            child: Stack(children: [
              for (var i = 0; i < shown.length; i++)
                PositionedDirectional(
                  start: i * step,
                  child: Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: t.sf, width: 2)),
                    child: BuAvatar(
                        name: shown[i]['displayName'] as String?,
                        url: shown[i]['avatarUrl'] as String?,
                        size: size - 4),
                  ),
                ),
            ]),
          ),
        const SizedBox(width: 8),
        Text('$total', style: Theme.of(context).textTheme.labelLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
