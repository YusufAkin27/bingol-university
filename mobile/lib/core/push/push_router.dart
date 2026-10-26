import 'package:flutter/material.dart';

import '../../features/chat/chat_detail_page.dart';
import '../../features/clubs/club_detail_page.dart';
import '../../features/events/event_detail_page.dart';
import '../../features/news/news_detail_page.dart';
import '../../features/notifications/notifications_page.dart';
import '../api.dart';
import '../nav.dart';
import '../session.dart';

/// Push `data` yüküne göre sayfa açar (MOBILE_API_GUIDE bölüm 6).
class PushRouter {
  PushRouter._();

  /// PushService tarafından atanır.
  static Session? session;

  static int? _id(Object? v) => v == null ? null : int.tryParse('$v');

  /// Kampanya hedefi (`target`/`value`) veya doğrudan anahtarlar (conversationId...) kabul edilir.
  static Future<void> open(Map<String, dynamic> data) async {
    final s = session;
    final nav = rootNavigatorKey.currentState;
    if (s == null || nav == null || s.state != SessionState.signedIn) return;

    var conversationId = _id(data['conversationId']);
    var eventId = _id(data['eventId']);
    var communityId = _id(data['communityId']);
    var newsId = _id(data['newsId']);
    final target = '${data['target'] ?? ''}'.toUpperCase();
    final value = _id(data['value']);
    if (value != null) {
      if (target == 'NEWS') newsId ??= value;
      if (target == 'EVENT') eventId ??= value;
      if (target == 'COMMUNITY') communityId ??= value;
    }

    if (conversationId != null) {
      try {
        final conv = await s.api.get('/conversations/$conversationId') as Map<String, dynamic>;
        nav.push(MaterialPageRoute(builder: (_) => ChatDetailPage(session: s, conversation: conv)));
        return;
      } on ApiError {
        // Sohbet açılamazsa bildirim listesine düş.
      }
    } else if (eventId != null) {
      nav.push(MaterialPageRoute(builder: (_) => EventDetailPage(session: s, eventId: eventId!)));
      return;
    } else if (communityId != null) {
      nav.push(MaterialPageRoute(builder: (_) => ClubDetailPage(session: s, communityId: communityId!)));
      return;
    } else if (newsId != null) {
      nav.push(MaterialPageRoute(
          builder: (_) => NewsDetailPage(session: s, item: <String, dynamic>{'id': newsId})));
      return;
    }
    nav.push(MaterialPageRoute(builder: (_) => NotificationsPage(session: s)));
  }
}
