import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';

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
bool eventIsClosed(Map<String, dynamic> e) => e['registrationClosed'] == true;

/// Katıldıktan sonra kısa onay: "Etkinliklerime eklendi" + "Etkinliklerim" kısayolu.
void showJoinedToast(BuildContext context, VoidCallback openMine) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(LucideIcons.check, size: 14.5),
        const SizedBox(width: 8),
        Flexible(child: Text(context.l10n.eventListAddedMine)),
      ]),
      action: SnackBarAction(label: context.l10n.eventListTabMine, onPressed: openMine),
    ));
}

/// Onay diyaloğu; onaylanırsa `true`. [danger] true: onay düğmesi uyarı renginde.
Future<bool> confirmEventDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
}) async {
  final t = context.bu;
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title, style: BuType.heading.copyWith(color: t.ink)),
      content: Text(message, style: BuType.body.copyWith(color: t.mut)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.l10n.eventListDismiss)),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(confirmLabel, style: TextStyle(color: danger ? t.danger : t.pr)),
        ),
      ],
    ),
  );
  return r == true;
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
    return Material(
      color: t.okSoft,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          height: large ? 54 : 36,
          padding: EdgeInsets.symmetric(horizontal: large ? 20 : 14),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.calendarCheck, size: large ? 18 : 13.5, color: t.ok),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label ?? context.l10n.eventListInMine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (large ? BuType.heading : BuType.label).copyWith(color: t.ok)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Küçük durum etiketi (Açık / Kayıt kapalı / İptal).
class EventStatusTag extends StatelessWidget {
  const EventStatusTag(this.label, {super.key, this.tone = EventTone.ok});

  final String label;
  final EventTone tone;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final (bg, fg) = switch (tone) {
      EventTone.ok => (t.okSoft, t.ok),
      EventTone.warn => (t.soft, t.onSoft),
      EventTone.danger => (t.danger.withValues(alpha: .14), t.danger),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: BuType.micro.copyWith(color: fg)),
    );
  }
}

enum EventTone { ok, warn, danger }

/// Tarih rozeti: ay kısaltması + gün.
class EventDateBadge extends StatelessWidget {
  const EventDateBadge(this.day, {super.key, this.onCover = false});

  final DateTime? day;
  final bool onCover;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final bg = onCover ? Colors.white : t.soft;
    final fg = onCover ? const Color(0xFF8E1B13) : t.onSoft;
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(day == null ? '' : eventMonthShortOf(context, day!.month), style: BuType.micro.copyWith(color: fg)),
        Text(day == null ? '' : '${day!.day}', style: BuType.title.copyWith(height: 1.1, color: fg)),
      ]),
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
    final shown = avatars.take(4).toList();
    const size = 26.0;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (shown.isEmpty)
        Icon(LucideIcons.users, size: 13.5, color: t.mut)
      else
        SizedBox(
          height: size,
          width: size + (shown.length - 1) * 16,
          child: Stack(children: [
            for (var i = 0; i < shown.length; i++)
              PositionedDirectional(
                start: i * 16.0,
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
      Text('$total', style: BuType.label.copyWith(color: t.ink)),
    ]);
  }
}

/// Kapak yoksa marka renkli degrade.
class EventCoverFallback extends StatelessWidget {
  const EventCoverFallback({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: t.hero),
      child: Stack(children: [
        PositionedDirectional(
          end: -30,
          top: -40,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .12)),
          ),
        ),
      ]),
    );
  }
}
