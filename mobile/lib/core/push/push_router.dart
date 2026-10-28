import 'package:flutter/material.dart';

import '../../features/academic/announcements_page.dart';
import '../../features/academic/exams_page.dart';
import '../../features/academic/timetable_page.dart';
import '../../features/chat/chat_detail_page.dart';
import '../../features/clubs/club_detail_page.dart';
import '../../features/events/event_detail_page.dart';
import '../../features/news/news_detail_page.dart';
import '../../features/notifications/notifications_page.dart';
import '../../features/polls/poll_routes.dart';
import '../../features/posts/post_routes.dart';
import '../../features/profile/user_profile_page.dart';
import '../../features/support/support_page.dart';
import '../../features/support/support_ticket_page.dart';
import '../api.dart';
import '../closed_conversations.dart';
import '../nav.dart';
import '../session.dart';
import 'push_targets.dart';

/// Push / yerel hatırlatma `data` yüküne göre sayfa açar (MOBILE_API_GUIDE bölüm 6).
/// Eşleme saf fonksiyonda ([resolvePushTarget]); burada yalnız gezinme vardır.
/// Çözülemeyen/hatalı hedef Bildirimler listesine düşer; hiçbir koşulda exception sızmaz.
class PushRouter {
  PushRouter._();

  /// PushService tarafından atanır.
  static Session? session;

  static Future<void> open(Map<String, dynamic> data) async {
    final s = session;
    // Sohbet kapatıldı/yeniden açıldı bildirimi: durum, hedef ekran açılmadan önce işlenir (bantlı açılsın).
    ClosedConversations.instance.applyPushData(data);
    final target = resolvePushTarget(data);
    if (s != null && target.dest == PushDest.signOut) {
      await s.forceSignOut(reason: SignOutReason.replaced);
      return;
    }
    final nav = rootNavigatorKey.currentState;
    if (s == null || nav == null || s.state != SessionState.signedIn) return;
    try {
      if (await _go(nav, s, target)) return;
    } catch (_) {
      // Açılamayan hedef: bildirim listesine düş.
    }
    if (!nav.mounted) return;
    nav.push(MaterialPageRoute<void>(builder: (_) => NotificationsPage(session: s)));
  }

  /// `GET /conversations/{id}` yanıtı `{conversation, members}` sarmalayıcısıdır (ChatDetailPage
  /// düz `ConversationView` bekler). Eski/düz biçim de kabul edilir; `id` yoksa null döner.
  @visibleForTesting
  static Map<String, dynamic>? conversationFromDetail(Object? body) {
    if (body is! Map) return null;
    final inner = body['conversation'];
    final conv = Map<String, dynamic>.from(inner is Map ? inner : body);
    return conv['id'] is num ? conv : null;
  }

  /// true = hedef açıldı.
  static Future<bool> _go(NavigatorState nav, Session s, PushTarget t) async {
    final id = t.id;
    final ctx = nav.context;
    void push(Widget page) => nav.push(MaterialPageRoute<void>(builder: (_) => page));
    switch (t.dest) {
      case PushDest.conversation:
        try {
          final conv = conversationFromDetail(await s.api.get('/conversations/$id'));
          if (conv == null) return false; // beklenmeyen biçim: Bildirimler listesine düş
          push(ChatDetailPage(session: s, conversation: conv));
          return true;
        } on ApiError {
          return false;
        }
      case PushDest.chatList:
        // Sohbet sekmesi: açık rotaları kapatıp kabukta Sohbet'e geç.
        nav.popUntil((r) => r.isFirst);
        shellTabRequest.value = 2;
        return true;
      case PushDest.event:
        push(EventDetailPage(session: s, eventId: id!));
        return true;
      case PushDest.community:
        push(ClubDetailPage(session: s, communityId: id!));
        return true;
      case PushDest.news:
        push(NewsDetailPage(session: s, item: <String, dynamic>{'id': id}));
        return true;
      case PushDest.post:
        await openPostDetail(ctx, s, id!);
        return true;
      case PushDest.poll:
        await openPollDetail(ctx, s, id!);
        return true;
      case PushDest.user:
        await openUserProfile(ctx, s, userId: id!);
        return true;
      case PushDest.deptAnnouncement:
        push(AnnouncementDetailPage(session: s, id: id!));
        return true;
      case PushDest.timetable:
        push(TimetablePage(session: s));
        return true;
      case PushDest.exams:
        push(ExamsPage(session: s));
        return true;
      case PushDest.ticket:
        push(SupportTicketPage(session: s, ticketId: id!));
        return true;
      case PushDest.feedback:
        push(SupportPage(session: s));
        return true;
      case PushDest.signOut:
      case PushDest.notifications:
        return false;
    }
  }
}
