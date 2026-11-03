import 'package:flutter/material.dart';

import '../../widgets/bu.dart';
import '../locale_controller.dart';

String pushCardStyle(Map<String, dynamic> data) {
  final explicit = '${data['style'] ?? ''}';
  if (explicit.isNotEmpty) return explicit;
  final type = '${data['type'] ?? ''}'.toUpperCase();
  final subtype = '${data['subtype'] ?? ''}'.toUpperCase();
  if (type == 'MESSAGE' || data['conversationId'] != null) {
    if (data['imageUrl'] != null) return 'CHAT_MEDIA';
    return data['conversationType'] == 'GROUP' ? 'CHAT_GROUP' : 'CHAT_DIRECT';
  }
  if (type == 'FOLLOW_REQUEST') return 'FOLLOW_REQUEST';
  if (type == 'FOLLOW_ACCEPTED') return 'FOLLOW_ACCEPTED';
  if (type == 'USER_FOLLOW') return 'FOLLOW';
  if (type.startsWith('POST_') || type == 'COMMENT_REPLY') return 'SOCIAL';
  if (data['pollId'] != null || subtype == 'POLL') return 'POLL';
  if (data['examId'] != null || subtype == 'EXAM_REMINDER') return 'EXAM';
  if (data['ticketId'] != null || data['feedbackId'] != null) return 'SUPPORT';
  if (data['target'] == 'MEAL' || data['targetType'] == 'MEAL') return 'MEAL';
  if (type == 'SYSTEM') return 'SECURITY';
  if (type == 'EVENT' || data['eventId'] != null) {
    if (subtype == 'EVENT_REMINDER') return 'EVENT_REMINDER';
    if (subtype == 'EVENT_ADMISSION') return 'EVENT_ADMISSION';
    return 'EVENT_UPDATE';
  }
  if (subtype == 'ACADEMIC_ANNOUNCEMENT') return 'ACADEMIC';
  return 'ANNOUNCEMENT';
}

List<String> pushCardActions(Map<String, dynamic> data) =>
    switch (pushCardStyle(data)) {
      'CHAT_DIRECT' => ['reply', if (data['messageId'] != null) 'mark_read'],
      'CHAT_GROUP' => ['reply', 'mute_hour'],
      'CHAT_MEDIA' => ['open', 'reply'],
      'FOLLOW_REQUEST' => ['follow_accept', 'follow_decline'],
      'FOLLOW' => ['follow'],
      'EVENT_REMINDER' => ['calendar', 'map'],
      'SECURITY' => ['security'],
      _ => ['open'],
    };

String pushActionLabel(BuildContext context, String action, String style) {
  final l = context.l10n;
  final lang = Localizations.localeOf(context).languageCode;
  String label(String tr, String en, String ar) => lang == 'ar'
      ? ar
      : lang == 'en'
          ? en
          : tr;
  return switch (action) {
    'reply' => l.chatDetailReply,
    'mark_read' => label('Okundu işaretle', 'Mark as read', 'تحديد كمقروء'),
    'mute_hour' => label('1 Saat Sessize Al', 'Mute for 1 hour', 'كتم لساعة'),
    'follow_accept' => label('Onayla', 'Accept', 'قبول'),
    'follow_decline' => label('Reddet', 'Decline', 'رفض'),
    'follow' => label('Takip et', 'Follow', 'متابعة'),
    'calendar' => label('Takvime Ekle', 'Add to calendar', 'إضافة للتقويم'),
    'map' => label('Haritada Gör', 'Show on map', 'عرض الخريطة'),
    'security' => l.profil1AccountSecurity,
    _ => switch (style) {
        'CHAT_MEDIA' => label('Görüntüle', 'View', 'عرض'),
        'POLL' => label('Oy ver', 'Vote', 'تصويت'),
        'FOLLOW_ACCEPTED' => label('Profili Gör', 'View profile', 'عرض الملف'),
        'EVENT_ADMISSION' => label('Giriş Kartı', 'Entry card', 'بطاقة الدخول'),
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
      _ => style == 'POLL'
          ? Icons.how_to_vote_outlined
          : style == 'EVENT_ADMISSION'
              ? Icons.badge_outlined
              : Icons.visibility_outlined,
    };

/// The reference's white notification card. Used by the live in-app push overlay and visual fixtures.
/// The Android/iOS system header and lock-screen controls remain native.
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
  static const navy = Color(0xff171e33),
      red = Color(0xffed211b),
      muted = Color(0xff60616b);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final style = pushCardStyle(data);
    final chat = style.startsWith('CHAT');
    final social = style.startsWith('FOLLOW') || style == 'SOCIAL';
    final image = fileUrl(data['imageUrl'] as String?);
    final avatar = data['senderAvatarUrl'] as String?;
    final thumbnail = image != null &&
        (style == 'MEAL' || style == 'SOCIAL' || style == 'ANNOUNCEMENT');
    final lang = Localizations.localeOf(context).languageCode;
    final countLabel = lang == 'en'
        ? '$count new messages'
        : lang == 'ar'
            ? '$count رسائل جديدة'
            : '$count yeni mesaj';
    final source = data['sourceName'] ?? data['conversationTitle'];
    final section = source is String && source.isNotEmpty
        ? source
        : switch (style) {
            'CHAT_DIRECT' => l.bildirimmobilKanalChat,
            'CHAT_GROUP' => l.bildirimTypeCommunity,
            'CHAT_MEDIA' => l.chatDetailMedia,
            'EVENT_REMINDER' ||
            'EVENT_ADMISSION' ||
            'EVENT_UPDATE' =>
              l.bildirimTypeEvent,
            'EXAM' || 'ACADEMIC' => l.profileAcademic,
            'POLL' => l.bildirimTypePoll,
            'SECURITY' => l.profil1AccountSecurity,
            'SUPPORT' => l.supportTitle,
            'MEAL' => l.p03HomeMenuDetail,
            _ => social ? l.profilePrefsSocial : l.bildirimTypeAnnouncement,
          };
    final icon = switch (style) {
      'EXAM' || 'ACADEMIC' => Icons.school_outlined,
      'EVENT_REMINDER' ||
      'EVENT_ADMISSION' ||
      'EVENT_UPDATE' =>
        Icons.event_outlined,
      'POLL' => Icons.poll_outlined,
      'SECURITY' => Icons.shield_outlined,
      'SUPPORT' => Icons.support_agent,
      'MEAL' => Icons.restaurant,
      _ => Icons.campaign_outlined,
    };
    final actions = pushCardActions(data);
    if (compact) {
      final actionable = chat || style.startsWith('EVENT');
      return Material(color: Colors.white, elevation: 5, shadowColor: Colors.black.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20), clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.fromLTRB(12, 0, 4, 10), child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(width: 15, height: 15, alignment: Alignment.center, decoration: const BoxDecoration(color: red, shape: BoxShape.circle),
                child: const Text('B', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800))),
              const SizedBox(width: 5),
              Expanded(child: Text('BU Kampüs · ' + (time ?? l.notifNow), maxLines: 1,
                style: const TextStyle(color: red, fontSize: 10, fontWeight: FontWeight.w600))),
              if (onClose != null) IconButton(onPressed: onClose, tooltip: l.commonClose,
                icon: const Icon(Icons.close, size: 16, color: muted), constraints: const BoxConstraints(minWidth: 44, minHeight: 44)),
            ]),
            Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: Row(children: [
              if (chat || social) BuAvatar(name: title, url: avatar, size: 36, headers: avatarHeaders)
              else Container(width: 36, height: 36, decoration: BoxDecoration(color: red.withValues(alpha: .1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: red, size: 19)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: navy, fontSize: 15, height: 1.3, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(count > 1 ? countLabel : body, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: count > 1 ? red : muted, fontSize: 12, height: 1.3)),
              ])),
              if (actionable) Padding(padding: const EdgeInsetsDirectional.only(start: 8), child: TextButton(
                onPressed: () => onAction(actions.first), style: TextButton.styleFrom(minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 10), backgroundColor: chat ? const Color(0xffeff0f3) : navy,
                  foregroundColor: chat ? navy : Colors.white, textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600)),
                child: Text(chat ? pushActionLabel(context, actions.first, style) : l.p14Detail))),
            ])),
          ],
        ))),
      );
    }

    return Material(
      color: Colors.white,
      elevation: 5,
      shadowColor: Colors.black.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: data['severity'] == 'critical'
                ? const BoxDecoration(
                    border: Border(top: BorderSide(color: red, width: 3)))
                : null,
            padding: const EdgeInsets.fromLTRB(13, 10, 10, 12),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                            color: chat ? red : Colors.transparent,
                            borderRadius: BorderRadius.circular(12)),
                        child: Text('BU KAMPÜS',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: chat ? Colors.white : red))),
                    const SizedBox(width: 5),
                    Expanded(
                        child: Text('· $section',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontSize: 10, color: muted))),
                    Text(time ?? l.notifNow,
                        style: const TextStyle(fontSize: 10, color: muted)),
                    if (onClose != null)
                      IconButton(
                          tooltip: l.commonClose,
                          onPressed: onClose,
                          visualDensity: VisualDensity.compact,
                          constraints:
                              const BoxConstraints(minHeight: 44, minWidth: 44),
                          icon:
                              const Icon(Icons.close, size: 17, color: muted)),
                  ]),
                  const SizedBox(height: 7),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (chat || social) ...[
                      BuAvatar(
                          name: title,
                          url: avatar,
                          headers: avatarHeaders,
                          size: 42),
                      const SizedBox(width: 11),
                    ] else ...[
                      Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                              color: red.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(icon,
                              color: style == 'ACADEMIC' || style == 'POLL'
                                  ? const Color(0xff3159c7)
                                  : red,
                              size: 19)),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          Text(title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.25,
                                  fontWeight: FontWeight.w700,
                                  color: navy)),
                          if (body.isNotEmpty)
                            Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(body,
                                    maxLines: compact ? 1 : 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        height: 1.45,
                                        color: muted))),
                          if (count > 1)
                            Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(countLabel,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: red))),
                          if (image != null && !compact && !thumbnail)
                            Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(image,
                                        height: 108,
                                        fit: BoxFit.cover,
                                        headers: avatarHeaders,
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox.shrink()))),
                          if (data['badgeText'] is String)
                            Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(data['badgeText'] as String,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: red,
                                        fontWeight: FontWeight.w700))),
                        ])),
                    if (thumbnail && !compact)
                      Padding(
                          padding: const EdgeInsetsDirectional.only(start: 8),
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(image!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink()))),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(spacing: 7, runSpacing: 4, children: [
                    for (final action in (compact ? actions.take(1) : actions))
                      TextButton.icon(
                          onPressed: () => onAction(action),
                          style: TextButton.styleFrom(
                              minimumSize: const Size(0, 36),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              backgroundColor: action == 'follow'
                                  ? red
                                  : action == 'follow_accept' ||
                                          style == 'POLL' && action == 'open'
                                      ? navy
                                      : const Color(0xffeff0f3),
                              foregroundColor: action == 'follow' ||
                                      action == 'follow_accept' ||
                                      style == 'POLL' && action == 'open'
                                  ? Colors.white
                                  : navy,
                              textStyle: const TextStyle(
                                  fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600)),
                          icon: Icon(pushActionIcon(action, style), size: 12),
                          label: Text(pushActionLabel(context, action, style))),
                  ]),
                ]),
          )),
    );
  }
}
