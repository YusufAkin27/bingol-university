import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../session.dart';
import 'push_router.dart';
import 'push_targets.dart';

typedef PushOpen = Future<void> Function(Map<String, dynamic> data,
    {bool compose});

/// Called only by the signed native notification bridge / UNNotificationResponse.
/// Local reminders and URL intents deliberately never enter this action path.
class PushActions {
  PushActions(this.session, {PushOpen? open}) : open = open ?? _open;
  final Session session;
  final PushOpen open;
  final _completed = <String>{};
  final _pending = <String>{};
  static const channel = MethodChannel('bu_kampus/push_actions');

  static Future<void> _open(Map<String, dynamic> data,
          {bool compose = false}) =>
      PushRouter.open(data, compose: compose);

  int? _id(Object? value) {
    final id = int.tryParse('$value');
    return id != null && id > 0 ? id : null;
  }

  Future<bool> perform(Map<String, dynamic> data) async {
    if (data['preview'] == '1') return true;
    if (session.state != SessionState.signedIn) return false;
    final recipient = _id(data['recipientId']);
    if (recipient != null) {
      final current = session.userId ??
          _id((await session.api.get('/auth/me') as Map)['id']);
      if (session.state != SessionState.signedIn || current != recipient)
        return false;
    }
    final key = '${data['actionId'] ?? ''}';
    if (key.isNotEmpty && _completed.contains(key)) return true;
    if (key.isNotEmpty && !_pending.add(key)) return false;
    try {
      final action = '${data['notificationAction'] ?? 'open'}';
      final conversation = _id(data['conversationId']);
      final message = _id(data['messageId']);
      final user = _id(data['userId'] ??
          data['requesterId'] ??
          data['targetId'] ??
          data['value']);
      switch (action) {
        case 'reply':
          if (conversation == null) {
            await open(data);
            break;
          }
          final text = data['replyText'];
          if (text is String && text.trim().isNotEmpty) {
            if (text.length > 4000 || key.isEmpty)
              throw const FormatException('Invalid notification reply');
            await session.api.post('/conversations/$conversation/messages', {
              'text': text.trim(),
              'clientId': key,
              if (message != null) 'replyToMessageId': message,
            });
            session.badges.conversationsDirty.value++;
          } else {
            await open(data, compose: true);
          }
        case 'mark_read':
          if (conversation != null && message != null) {
            await session.api.post('/conversations/$conversation/read',
                {'lastMessageId': message});
            session.badges.conversationsDirty.value++;
          } else {
            await open(data);
          }
        case 'mute_hour':
          if (conversation != null) {
            await session.api.put(
                '/conversations/$conversation/mute', {'durationMinutes': 60});
            session.badges.conversationsDirty.value++;
          } else {
            await open(data);
          }
        case 'follow_accept':
        case 'follow_decline':
          if (user != null) {
            final decision = action == 'follow_accept' ? 'accept' : 'decline';
            await session.api.post('/users/me/follow-requests/$user/$decision');
            final unread = await session.api.get('/notifications/unread-count').catchError((Object _) => null);
            if (unread is Map && unread['unreadCount'] is num) {
              session.badges.notifications.value =
                  (unread['unreadCount'] as num).toInt();
            }
          } else {
            await open(data);
          }
        case 'follow':
          if (user != null) {
            await session.api.post('/users/$user/follow');
          } else {
            await open(data);
          }
        case 'security':
          // "Bu ben değilim" / "Hemen Sıfırla" / "2FA Aç": oturumları kapatma ve şifre değiştirme bu sayfadadır.
          await open({'targetType': 'ACCOUNT_SECURITY'});
        case 'checkin':
          // "QR ile Giriş": etkinlik sayfası, yoklama açıksa QR tarayıcıyı kendiliğinden açar.
          await open(data, compose: true);
        case 'calendar':
        case 'map':
          final target = resolvePushTarget(data);
          if (target.dest != PushDest.event || target.id == null) {
            await open(data);
            break;
          }
          final event = await session.api.get('/events/${target.id}');
          if (event is! Map) {
            await open(data);
            break;
          }
          final location = '${event['location'] ?? ''}'.trim();
          if (action == 'map' && location.isNotEmpty) {
            final launched = await launchUrl(
                Uri.https('www.google.com', '/maps/search/',
                    {'api': '1', 'query': location}),
                mode: LaunchMode.externalApplication);
            if (!launched) await open(data);
          } else if (action == 'calendar') {
            final start = DateTime.tryParse('${event['startsAt']}');
            final end = DateTime.tryParse('${event['endsAt']}') ??
                start?.add(const Duration(hours: 1));
            if (start == null || end == null) {
              await open(data);
              break;
            }
            bool native = false;
            try {
              native = await channel.invokeMethod<bool>('addCalendar', {
                    'title': event['title'],
                    'location': location,
                    'start': start.millisecondsSinceEpoch,
                    'end': end.millisecondsSinceEpoch,
                  }) ??
                  false;
            } on MissingPluginException {
              /* Web/iOS falls back to a calendar draft. */
            }
            if (!native) {
              String stamp(DateTime date) =>
                  date
                      .toUtc()
                      .toIso8601String()
                      .split('.')
                      .first
                      .replaceAll(RegExp('[-:]'), '') +
                  'Z';
              final launched = await launchUrl(
                  Uri.https('calendar.google.com', '/calendar/render', {
                    'action': 'TEMPLATE',
                    'text': '${event['title'] ?? ''}',
                    'location': location,
                    'dates': '${stamp(start)}/${stamp(end)}',
                  }),
                  mode: LaunchMode.externalApplication);
              if (!launched) await open(data);
            }
          } else {
            await open(data);
          }
        default:
          await open(data);
      }
      if (key.isNotEmpty) {
        _completed.add(key);
        if (_completed.length > 100) _completed.remove(_completed.first);
      }
      return true;
    } finally {
      _pending.remove(key);
    }
  }
}
