import 'package:flutter/material.dart';

import '../../features/academic/academic_models.dart' show istanbulWall, monthNameL, two;
import '../../features/chat/chatlist_widgets.dart' show ChatlistAvatar;
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import '../api.dart' show apiOrigin;
import '../locale_controller.dart';
import 'push_card_parts.dart';
import 'push_targets.dart' show isForumPush;

bool _flag(Object? v) => v == true || '$v'.toLowerCase() == 'true' || '$v' == '1';

String? _text(Map<String, dynamic> data, String key) {
  final v = data[key];
  return v is String && v.trim().isNotEmpty ? v.trim() : null;
}

/// Sunucu yükündeki zaman alanı (ISO 8601); yoksa/bozuksa null.
DateTime? pushDate(Map<String, dynamic> data, String key) {
  final s = _text(data, key);
  return s == null ? null : DateTime.tryParse(s);
}

/// Sunucu görsel kuralı istemcide de uygulanır: göreli yol (aynı API) ya da https + API ana makinesi / `bingol.edu.tr` alt alanı.
/// Aksi (üçüncü taraf, http) çizilmez; kişisel verinin başka sunucuya istek olarak sızmasını da önler.
String? pushImageUrl(String? raw, {String origin = apiOrigin}) {
  final s = raw?.trim();
  if (s == null || s.isEmpty) return null;
  if (s.startsWith('/') && !s.startsWith('//')) return fileUrl(s);
  final u = Uri.tryParse(s);
  if (u == null || !u.hasAuthority || u.host.isEmpty) return null;
  final api = Uri.tryParse(origin);
  final host = u.host.toLowerCase();
  if (api != null && api.host.isNotEmpty && host == api.host.toLowerCase()) return s;
  final campus = host == 'bingol.edu.tr' || host.endsWith('.bingol.edu.tr');
  return u.scheme == 'https' && campus ? s : null;
}

/// Kartın kullanacağı stil. Sunucu `style` verirse (büyük/küçük harf fark etmez) o; vermezse yükten türetilir.
String pushCardStyle(Map<String, dynamic> data) {
  // Forum: sunucu `style=social|system` yollar ama anonim yazar kişi avatarı almamalı; moderasyon ayrı ton.
  if (isForumPush(data)) return '${data['type'] ?? ''}'.toUpperCase() == 'FORUM_MODERATION' ? 'MODERATION' : 'FORUM';
  final explicit = '${data['style'] ?? ''}'.toUpperCase();
  if (explicit.isNotEmpty) {
    return switch (explicit) {
      'CHAT' => 'CHAT_DIRECT',
      _ => explicit,
    };
  }
  final type = '${data['type'] ?? ''}'.toUpperCase();
  final subtype = '${data['subtype'] ?? ''}'.toUpperCase();
  if (type == 'MESSAGE' || data['conversationId'] != null) {
    if (data['imageUrl'] != null) return 'CHAT_MEDIA';
    return data['conversationType'] == 'GROUP' ? 'CHAT_GROUP' : 'CHAT_DIRECT';
  }
  if (type == 'FOLLOW_REQUEST') return 'FOLLOW_REQUEST';
  if (type == 'FOLLOW_ACCEPTED') return 'FOLLOW_ACCEPTED';
  if (type == 'USER_FOLLOW') return 'FOLLOW';
  if (type == 'POST_MENTION') return 'MENTION';
  if (type.startsWith('POST_') || type == 'COMMENT_REPLY') return 'SOCIAL';
  if (data['pollId'] != null || subtype == 'POLL') return 'POLL';
  if (data['examId'] != null || subtype == 'EXAM_REMINDER') return 'EXAM';
  if (data['ticketId'] != null || data['feedbackId'] != null) return 'SUPPORT';
  if (data['target'] == 'MEAL' || data['targetType'] == 'MEAL') return 'MEAL';
  if (type == 'SYSTEM') {
    // Her SYSTEM bildirimi güvenlik değildir (moderasyon, bakım...): yalnız `securityKind`/kritik/güvenlik hedefli olanlar.
    final security = _text(data, 'securityKind') != null ||
        data['severity'] == 'critical' ||
        '${data['target'] ?? data['targetType'] ?? ''}'.toUpperCase() == 'ACCOUNT_SECURITY' ||
        subtype.contains('SECURITY');
    return security ? 'SECURITY' : 'SYSTEM';
  }
  if (type == 'EVENT' || data['eventId'] != null) {
    if (subtype == 'EVENT_REMINDER') return 'EVENT_REMINDER';
    if (subtype == 'EVENT_ADMISSION') return 'EVENT_ADMISSION';
    return 'EVENT_UPDATE';
  }
  return 'ANNOUNCEMENT';
}

/// Aksiyon seti: uygulama içi şerit, gelen kutusu satırı ve (kimlikleri eşleşen) sistem bildirimi AYNI tablodan okur.
/// Yalnız gerçek işlevi olan aksiyonlar listelenir. `ack` = yalnız kartı kapat/okundu say; `open_all` = sohbeti aç.
List<String> pushCardActions(Map<String, dynamic> data, {int count = 1}) =>
    switch (pushCardStyle(data)) {
      'CHAT_DIRECT' => count > 1 ? ['reply', 'open_all'] : ['reply', if (data['messageId'] != null) 'mark_read'],
      'CHAT_GROUP' => ['reply', 'mute_hour'],
      'CHAT_MEDIA' => ['open', 'reply'],
      'FOLLOW_REQUEST' => ['follow_accept', 'follow_decline'],
      'FOLLOW' => ['follow'],
      'EVENT_REMINDER' => ['calendar', 'map'],
      'EVENT_UPDATE' => ['ack', 'open'],
      'SECURITY' => ['security'],
      _ => ['open'],
    };

String pushActionLabel(BuildContext context, String action, String style, {bool many = false, String? securityKind}) {
  final l = context.l10n;
  final lang = l.localeName;
  String label(String tr, String en, String ar) => lang == 'ar'
      ? ar
      : lang == 'en'
          ? en
          : tr;
  return switch (action) {
    'reply' => many ? l.notifActionQuickReply : l.chatDetailReply,
    'mark_read' => label('Okundu işaretle', 'Mark as read', 'تحديد كمقروء'),
    'mute_hour' => label('1 Saat Sessize Al', 'Mute for 1 hour', 'كتم لساعة'),
    'follow_accept' => label('Onayla', 'Accept', 'قبول'),
    'follow_decline' => label('Reddet', 'Decline', 'رفض'),
    'follow' => label('Takip et', 'Follow', 'متابعة'),
    'calendar' => label('Takvime Ekle', 'Add to calendar', 'إضافة للتقويم'),
    'map' => label('Haritada Gör', 'Show on map', 'عرض الخريطة'),
    'security' => switch (securityKind) {
        // Hesap Güvenliği sayfasında "tüm oturumları kapat" ve şifre değiştirme var; etiket olayı anlatır.
        'NEW_DEVICE' => label('Bu ben değilim', "This wasn't me", 'لست أنا'),
        'PASSWORD_CHANGED' => label('Hemen Sıfırla', 'Reset now', 'إعادة التعيين الآن'),
        _ => l.profil1AccountSecurity,
      },
    'ack' => l.notifActionAck,
    'open_all' => l.notifActionOpenAll,
    _ => switch (style) {
        'CHAT_MEDIA' => label('Görüntüle', 'View', 'عرض'),
        'POLL' => label('Oy ver', 'Vote', 'تصويت'),
        'FOLLOW_ACCEPTED' => label('Profili Gör', 'View profile', 'عرض الملف'),
        'EVENT_ADMISSION' => label('Giriş Kartı', 'Entry card', 'بطاقة الدخول'),
        'EVENT_UPDATE' => l.notifActionProgram,
        'EXAM' => label('Sınav Detayı', 'Exam details', 'تفاصيل الامتحان'),
        'SUPPORT' => label('Talebi Görüntüle', 'View ticket', 'عرض الطلب'),
        'MEAL' => label('Menüyü Gör', 'View menu', 'عرض القائمة'),
        _ => l.p14Detail,
      },
  };
}

IconData pushActionIcon(String action, String style) => switch (action) {
      'reply' => Icons.reply,
      'mark_read' => Icons.done_all,
      'mute_hour' => Icons.notifications_off_outlined,
      'follow_accept' => Icons.check,
      'follow_decline' => Icons.close,
      'follow' => Icons.person_add_outlined,
      'calendar' => Icons.event_available_outlined,
      'map' => Icons.location_on_outlined,
      'security' => Icons.shield_outlined,
      'ack' => Icons.check_circle_outline,
      'open_all' => Icons.expand_more,
      _ => switch (style) {
          'POLL' => Icons.how_to_vote_outlined,
          'EVENT_ADMISSION' => Icons.badge_outlined,
          'EVENT_UPDATE' => Icons.info_outline,
          'SUPPORT' => Icons.arrow_forward,
          _ => Icons.visibility_outlined,
        },
    };

PushButtonKind pushActionKind(String action, String style) {
  if (action == 'follow') return PushButtonKind.accent;
  if (action == 'follow_accept') return PushButtonKind.primary;
  if (action == 'open' && (style == 'POLL' || style == 'EVENT_ADMISSION' || style == 'SUPPORT')) {
    return PushButtonKind.primary;
  }
  return PushButtonKind.secondary;
}

/// Köşe rozeti: yalnız kişi bildirimlerinde (beğeni/takip/istek/kabul).
PushAvatarRole? pushAvatarRole(Map<String, dynamic> data) {
  final type = '${data['type'] ?? ''}'.toUpperCase();
  return switch (type) {
    'POST_LIKE' => PushAvatarRole.like,
    'POST_MENTION' => PushAvatarRole.mention,
    'USER_FOLLOW' => PushAvatarRole.follow,
    'FOLLOW_REQUEST' => PushAvatarRole.request,
    'FOLLOW_ACCEPTED' => PushAvatarRole.accepted,
    _ => switch (pushCardStyle(data)) {
        'LIKE' => PushAvatarRole.like,
        'MENTION' => PushAvatarRole.mention,
        'FOLLOW' => PushAvatarRole.follow,
        'FOLLOW_REQUEST' => PushAvatarRole.request,
        'FOLLOW_ACCEPTED' => PushAvatarRole.accepted,
        _ => null,
      },
  };
}

/// "Yarın 14:00" / "Bugün 09:30" / "12 Kasım 10:00" (İstanbul saati).
String pushWhenLabel(AppLocalizations l, DateTime instant, {DateTime? now}) {
  final w = istanbulWall(instant);
  final n = istanbulWall(now ?? DateTime.now());
  final days = DateTime.utc(w.year, w.month, w.day).difference(DateTime.utc(n.year, n.month, n.day)).inDays;
  final time = '${two(w.hour)}:${two(w.minute)}';
  final day = days == 0
      ? l.evdChipToday
      : days == 1
          ? l.evdChipTomorrow
          : '${w.day} ${monthNameL(l, w.month)}';
  return '$day $time';
}

String _hm(DateTime instant) {
  final w = istanbulWall(instant);
  return '${two(w.hour)}:${two(w.minute)}';
}

/// Başlık yanı etiket tonu: önemli/iptal/kritik = kırmızı, aksi nötr. Sunucu `badgeTone` (danger|info|ok|warn) verirse o.
PushChipTone pushBadgeTone(Map<String, dynamic> data) {
  final tone = '${data['badgeTone'] ?? ''}'.toLowerCase();
  switch (tone) {
    case 'danger':
      return PushChipTone.danger;
    case 'info':
      return PushChipTone.info;
    case 'ok':
      return PushChipTone.ok;
    case 'warn':
      return PushChipTone.warn;
    case 'neutral':
      return PushChipTone.neutral;
  }
  final subtype = '${data['subtype'] ?? ''}'.toUpperCase();
  final style = pushCardStyle(data);
  if (style == 'EVENT_CANCELLED' || (style == 'POLL' && _text(data, 'badgeText') != null)) return PushChipTone.danger;
  if (_flag(data['important']) || data['severity'] == 'critical' || subtype.contains('CANCEL')) {
    return PushChipTone.danger;
  }
  return PushChipTone.neutral;
}

/// "Toplam 820 kcal": yalnız sunucu `kcalComplete` derse ve `totalKcal` sayıysa (eksik menüde toplam gösterilmez).
String? pushKcalText(AppLocalizations l, Map<String, dynamic> data) {
  // Sunucu `totalKcal`'i yalnız eksiksiz menüde yazar; `kcalComplete` açıkça false ise de gösterilmez.
  if (data.containsKey('kcalComplete') && !_flag(data['kcalComplete'])) return null;
  final n = num.tryParse('${data['totalKcal'] ?? ''}');
  if (n == null || n <= 0) return null;
  return l.notifKcalTotal(n.round().toString());
}

/// Kaynak etiketi: sunucu `sourceName` (kulüp/birim) > sohbet başlığı > stile göre sabit ad.
String pushSectionLabel(AppLocalizations l, Map<String, dynamic> data, String style) {
  final source = _text(data, 'sourceName') ?? _text(data, 'conversationTitle');
  if (source != null) return source;
  return switch (style) {
    'CHAT_DIRECT' => l.bildirimmobilKanalChat,
    'CHAT_GROUP' => l.bildirimTypeCommunity,
    'CHAT_MEDIA' => l.chatDetailMedia,
    'EVENT_REMINDER' || 'EVENT_ADMISSION' || 'EVENT_UPDATE' || 'EVENT_CANCELLED' || 'EVENT' => l.bildirimTypeEvent,
    'EXAM' || 'ACADEMIC' => l.profileAcademic,
    'POLL' => l.bildirimTypePoll,
    'SECURITY' => l.profil1AccountSecurity,
    'MODERATION' => l.notifSourceModeration,
    'SUPPORT' => l.supportTitle,
    'MEAL' => l.p03HomeMenuDetail,
    'SOCIAL' || 'LIKE' || 'MENTION' || 'FOLLOW' || 'FOLLOW_REQUEST' || 'FOLLOW_ACCEPTED' => l.profilePrefsSocial,
    'SYSTEM' => l.bildirimTypeOther,
    'FORUM' => l.forumPrefsNotifLabel,
    _ => l.bildirimTypeAnnouncement,
  };
}

/// Gövde altı bilgi çipleri (kart ve gelen kutusu ortak): etkinlik/sınav zamanı + yeri, menü kcal toplamı.
/// Yalnız sunucu alanı varsa çizilir.
List<Widget> pushInfoChips(AppLocalizations l, Map<String, dynamic> data, String style) {
  final start = pushDate(data, 'eventStartsAt') ?? pushDate(data, 'startsAt');
  final place = _text(data, 'location') ?? _text(data, 'room');
  final kcal = pushKcalText(l, data);
  return [
    if (start != null && (style.startsWith('EVENT') || style == 'EXAM' || style == 'ACADEMIC'))
      PushChip(
          label: [pushWhenLabel(l, start), if (place != null) place].join(' · '),
          icon: Icons.event_outlined,
          tone: style == 'EXAM' ? PushChipTone.danger : PushChipTone.info,
          maxWidth: 260),
    if (kcal != null) PushChip(label: kcal, icon: Icons.local_fire_department_outlined, tone: PushChipTone.ok),
  ];
}

/// Tasarımdaki beyaz bildirim kartı. Uygulama içi ön plan şeridi ve gelen kutusu aynı görsel dili kullanır;
/// sunucudan gelen isteğe bağlı alanlar (`sourceName`, `badgeText`, `important`, `severity`, `imageUrl`, `senderAvatarUrl`,
/// `eventStartsAt`, `location`, `oldStartsAt`/`newStartsAt`, `totalKcal`+`kcalComplete`) varsa kendiliğinden çizilir; yoksa o öğe çizilmez.
/// Android/iOS sistem başlığı ve kilit ekranı denetimleri yereldir.
class NotificationPushCard extends StatelessWidget {
  const NotificationPushCard(
      {super.key,
      required this.title,
      required this.body,
      required this.data,
      required this.onTap,
      required this.onAction,
      this.onClose,
      this.count = 1,
      this.time,
      this.avatarHeaders,
      this.compact = false});
  final String title, body;
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final ValueChanged<String> onAction;
  final VoidCallback? onClose;
  final int count;
  final bool compact;
  final String? time;
  final Map<String, String>? avatarHeaders;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final style = pushCardStyle(data);
    final chat = style.startsWith('CHAT');
    final social = style.startsWith('FOLLOW') || style == 'SOCIAL' || style == 'LIKE' || style == 'MENTION';
    final person = chat || social;
    final image = pushImageUrl(_text(data, 'imageUrl'));
    final avatar = pushImageUrl(_text(data, 'senderAvatarUrl') ?? _text(data, 'actorAvatarUrl'));
    final headers = avatarHeaders ?? ChatlistAvatar.authHeadersFor(avatar);
    final thumbnail = image != null && !chat;
    final wide = image != null && style == 'CHAT_MEDIA' && !compact;
    final lang = l.localeName;
    final countLabel = lang == 'en'
        ? '$count new messages'
        : lang == 'ar'
            ? '$count رسائل جديدة'
            : '$count yeni mesaj';
    final section = pushSectionLabel(l, data, style);
    final actions = pushCardActions(data, count: count);
    final badge = _text(data, 'badgeText');
    final important = _flag(data['important']);
    final start = pushDate(data, 'eventStartsAt') ?? pushDate(data, 'startsAt');
    final place = _text(data, 'location') ?? _text(data, 'room');
    final role = pushAvatarRole(data);
    final securityKind = _text(data, 'securityKind');
    final timeText = time ?? l.notifNow;
    final critical = data['severity'] == 'critical';

    Widget leading(double size) {
      if (person) {
        return PushAvatar(
            name: title,
            url: avatar,
            size: size,
            group: style == 'CHAT_GROUP',
            role: role,
            count: chat ? count : 0,
            headers: headers);
      }
      if (compact && start != null && style.startsWith('EVENT')) {
        final w = istanbulWall(start);
        return PushDateTile(month: trUpper(monthNameL(l, w.month)).characters.take(3).toString(), day: '${w.day}', size: size);
      }
      return PushTile(style: style, size: size);
    }

    Widget header() => Row(children: [
          if (chat)
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: t.prPressed, borderRadius: BorderRadius.circular(BuRadius.pill)),
                child: Text('BU KAMPÜS', style: BuType.caption.copyWith(fontSize: 11, height: 1.2, fontWeight: FontWeight.w400, color: t.onPr)))
          else ...[
            Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: t.prPressed, shape: BoxShape.circle),
                child: Text('BU', style: BuType.caption.copyWith(fontSize: 8, height: 1, fontWeight: FontWeight.w400, color: t.onPr))),
            const SizedBox(width: 6),
            Text('BU Kampüs', style: BuType.caption.copyWith(fontSize: 12, height: 1.2, fontWeight: FontWeight.w400, color: t.ink)),
          ],
          if (important && badge == null) ...[
            const SizedBox(width: 5),
            Text('• ${l.notifBadgeImportant}', style: BuType.caption.copyWith(fontSize: 11, height: 1.2, fontWeight: FontWeight.w400, color: t.danger)),
          ],
          const SizedBox(width: 5),
          Expanded(
              child: Text('· $section',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(fontSize: 11, height: 1.2, color: t.mut))),
          Text(timeText, style: BuType.caption.copyWith(fontSize: 11, height: 1.2, color: t.mut)),
          if (onClose != null)
            IconButton(
                tooltip: l.commonClose,
                onPressed: onClose,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                icon: Icon(Icons.close, size: 17, color: t.mut))
          else
            const SizedBox(width: 2),
        ]);

    final titleStyle = BuType.caption.copyWith(fontSize: compact ? 15 : 16, height: 1.25, fontWeight: FontWeight.w400, color: t.ink);

    if (compact) {
      final first = actions.first;
      final actionable = chat || style.startsWith('EVENT') || style == 'POLL';
      final subtitle = count > 1
          ? Text(countLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(fontSize: 13, height: 1.3, fontWeight: FontWeight.w400, color: t.prText))
          : start != null && style.startsWith('EVENT')
              ? Row(children: [
                  Icon(Icons.schedule, size: 14, color: t.prText),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text([_hm(start), if (place != null) place].join(' · '),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(fontSize: 13, height: 1.3, color: t.mut))),
                ])
              : Text(body, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(fontSize: 13, height: 1.3, color: t.mut));
      return Material(
        color: t.sf,
        elevation: 5,
        shadowColor: t.shadow.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: critical ? BoxDecoration(border: Border(top: BorderSide(color: t.danger, width: 3))) : null,
            padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 4, 10),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              header(),
              Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: Row(children: [
                    leading(40),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
                      const SizedBox(height: 3),
                      subtitle,
                    ])),
                    if (actionable)
                      Padding(
                          padding: const EdgeInsetsDirectional.only(start: 8),
                          child: PushActionButton(
                              label: chat ? pushActionLabel(context, first, style, many: count > 1, securityKind: securityKind) : l.p14Detail,
                              icon: chat ? pushActionIcon(first, style) : Icons.chevron_right,
                              kind: chat ? PushButtonKind.secondary : PushButtonKind.primary,
                              onPressed: () => onAction(first))),
                  ])),
            ]),
          ),
        ),
      );
    }

    final oldAt = pushDate(data, 'oldStartsAt');
    final newAt = pushDate(data, 'newStartsAt');
    final chips = chat ? const <Widget>[] : pushInfoChips(l, data, style);

    return Material(
      color: t.sf,
      elevation: 5,
      shadowColor: t.shadow.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: critical ? BoxDecoration(border: Border(top: BorderSide(color: t.danger, width: 3))) : null,
            padding: const EdgeInsetsDirectional.fromSTEB(13, 8, 10, 12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              header(),
              const SizedBox(height: 4),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                leading(person ? 44 : 38),
                const SizedBox(width: 11),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text.rich(
                    TextSpan(style: titleStyle, children: [
                      TextSpan(text: title),
                      if (badge != null)
                        WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                                padding: const EdgeInsetsDirectional.only(start: 8),
                                child: PushChip(label: badge, tone: pushBadgeTone(data), maxWidth: 170))),
                      if (chat && count > 1)
                        WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                                padding: const EdgeInsetsDirectional.only(start: 8),
                                child: PushChip(label: countLabel, tone: PushChipTone.danger, maxWidth: 150))),
                    ]),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (body.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(body, maxLines: 3, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(fontSize: 13, height: 1.45, color: t.mut))),
                  if (oldAt != null && newAt != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(spacing: 8, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          Text(l.notifNewTime(_hm(newAt)), style: BuType.caption.copyWith(fontSize: 13, height: 1.4, fontWeight: FontWeight.w400, color: t.ink)),
                          Text('(${l.notifOldTime(_hm(oldAt))})',
                              style: BuType.caption.copyWith(fontSize: 13, height: 1.4, color: t.mut, decoration: TextDecoration.lineThrough)),
                        ])),
                  if (wide)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(image,
                                height: 108,
                                fit: BoxFit.cover,
                                headers: avatarHeaders,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink()))),
                  if (chips.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 6, runSpacing: 4, children: chips)),
                ])),
                if (thumbnail)
                  Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(image,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              headers: avatarHeaders,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink()))),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 7, runSpacing: 4, children: [
                for (final action in actions)
                  PushActionButton(
                      label: pushActionLabel(context, action, style, many: count > 1, securityKind: securityKind),
                      icon: pushActionIcon(action, style),
                      kind: pushActionKind(action, style),
                      onPressed: () => onAction(action)),
              ]),
            ]),
          )),
    );
  }
}
