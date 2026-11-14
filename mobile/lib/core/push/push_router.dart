import 'dart:collection';

import '../analytics.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/academic/exams_page.dart';
import '../../features/academic/timetable_page.dart';
import '../../features/chat/chat_detail_page.dart';
import '../../features/courses/my_course_detail_page.dart';
import '../../features/clubs/club_detail_page.dart';
import '../../features/events/event_detail_page.dart';
import '../../features/follow/follow_requests_page.dart';
import '../../features/forum/forum_routes.dart' show ForumApi, openTopicDetail;
import '../../features/news/news_detail_page.dart';
import '../../features/notifications/notifications_page.dart';
import '../../features/notifications/notification_exam_detail.dart';
import '../../features/polls/poll_detail_page.dart';
import '../../features/posts/post_routes.dart';
import '../../features/profile/user_profile_page.dart';
import '../../features/profile/account_security_page.dart';
import '../../features/profile/devices_page.dart';
import '../../features/menu/menu_page.dart';
import '../../features/support/support_page.dart';
import '../../features/support/support_ticket_page.dart';
import '../api.dart';
import '../closed_conversations.dart';
import '../../widgets/bu_overlays.dart';
import '../locale_controller.dart';
import '../../l10n/app_localizations.dart';
import '../nav.dart';
import '../session.dart';
import 'push_targets.dart';
import 'notification_presentation.dart';

/// Push / yerel hatırlatma `data` yüküne göre sayfa açar (MOBILE_API_GUIDE bölüm 6).
/// Eşleme saf fonksiyonda ([resolvePushTarget]); burada yalnız gezinme vardır.
/// Çözülemeyen/hatalı hedef Bildirimler listesine düşer; hiçbir koşulda exception sızmaz.
class PushRouter {
  PushRouter._();

  /// PushService tarafından atanır.
  static Session? session;

  /// Oturum yokken dokunulan bildirimin yükü: güvenle saklanır, oturum açılınca [flushPending] açar.
  /// Tek kayıt tutulur (son dokunuş kazanır); [pendingTtl] sonra bayatlar ve atılır.
  static Map<String, dynamic>? _pending;
  static bool _pendingLocal = false;
  static DateTime? _pendingAt;
  static const pendingTtl = Duration(minutes: 30);

  /// Aynı bildirimin iki kez işlenmemesi: son [_maxSeen] benzersiz kimlik (LRU) ve işleme zamanı.
  static final LinkedHashMap<String, DateTime> _seen = LinkedHashMap<String, DateTime>();
  static const _maxSeen = 50;

  /// Aynı kimlikli bildirimin yinelenen dokunuşu bu süre içinde yok sayılır (FCM + yerel köprü çift yolu, çift dokunuş).
  static const dedupeWindow = Duration(seconds: 8);

  /// Testte saat enjekte edilir.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  /// Testler arasında statik durumu sıfırlar.
  @visibleForTesting
  static void resetForTest() {
    _pending = null;
    _pendingLocal = false;
    _pendingAt = null;
    _seen.clear();
    _navRetries = 0;
    clock = DateTime.now;
    session = null;
  }

  static int _navRetries = 0;

  /// Saklanan (oturum yokken dokunulan) yük var mı (test).
  @visibleForTesting
  static bool get hasPending => _pending != null;

  /// Bildirimi benzersiz kılan kimlik: sohbet `messageId`, ileride genel `nid`/`notificationId`. Kimliksiz yük
  /// (`conversationId`, `postId` vb.) tekilleştirilmez: aynı hedefe bilinçli ikinci dokunuş geçerlidir.
  static String? _dedupeKey(Map<String, dynamic> d, {required bool compose}) {
    for (final k in const ['messageId', 'nid', 'notificationId']) {
      final v = '${d[k] ?? ''}'.trim();
      if (v.isNotEmpty) return '$k:$v${compose ? ':c' : ''}';
    }
    return null;
  }

  /// true = aynı bildirim az önce işlendi (yok sayılmalı). Yeni ise kimliği kaydeder.
  static bool _isDuplicate(String? key) {
    if (key == null) return false;
    final now = clock();
    final prev = _seen.remove(key);
    _seen[key] = now; // en sona (LRU)
    while (_seen.length > _maxSeen) {
      _seen.remove(_seen.keys.first);
    }
    return prev != null && now.difference(prev) < dedupeWindow;
  }

  /// Oturum açılınca çağrılır: oturum yokken dokunulan bildirim (süresi dolmadıysa) şimdi açılır.
  static Future<bool> flushPending() async {
    final d = _pending;
    final at = _pendingAt;
    final local = _pendingLocal;
    _pending = null;
    _pendingAt = null;
    _pendingLocal = false;
    if (d == null || at == null || clock().difference(at) > pendingTtl) return false;
    return open(d, localReminder: local);
  }

  /// Yük başka bir hesaba mı ait (cihazda hesap değişti; sunucu yüküne `recipientId` koyar).
  static bool isForeignRecipient(Map<String, dynamic> d, Session s) => _foreignRecipient(d, s);

  static bool _foreignRecipient(Map<String, dynamic> d, Session s) {
    final r = int.tryParse('${d['recipientId'] ?? ''}');
    final me = s.userId;
    return r != null && r > 0 && me != null && r != me;
  }

  /// Başka hesaba ait bildirim: hesap cihazda kayıtlı ve oturumu açıksa o hesaba geçilir ve hedef orada açılır
  /// (yük [_pending] olarak saklanır, geçişle tetiklenen `onSignedIn` -> [flushPending] açar). Oturumu dolmuş hesapta
  /// yük bekletilir ve bilgi verilir; cihazda kayıtlı olmayan hesapta yük atılır. Bu ekranda hiçbir içerik açılmaz.
  static Future<bool> _openForeign(Map<String, dynamic> d, Session s,
      {required bool compose, required bool listFallback}) async {
    final r = int.tryParse('${d['recipientId'] ?? ''}')!;
    void say(String Function(AppLocalizations l) f) {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null) return;
      try {
        BuToast.show(ctx, f(ctx.l10n));
      } catch (_) {
        /* ekran yok */
      }
    }

    if (!s.accounts.has(r)) {
      say((l) => l.pushForeignMissing);
      return false;
    }
    _pending = Map<String, dynamic>.from(d);
    _pendingLocal = false;
    _pendingAt = clock();
    final res = await s.switchAccount(r);
    switch (res) {
      case SwitchResult.switched:
        say((l) => l.pushForeignSwitched);
        return true;
      case SwitchResult.same:
        _pending = null;
        _pendingAt = null;
        return open(d, compose: compose, listFallback: listFallback);
      case SwitchResult.needsLogin:
        say((l) => l.pushForeignExpired);
        return false;
      case SwitchResult.busy:
        return false;
    }
  }

  /// [localReminder] = yük yerel hatırlatma dokunuşundan geldi (Android intent ekstrası dışarıdan sahte
  /// basılabilir): yalnız hedef anahtarları beyaz listeden geçer, sohbet durumu (kapandı/yeniden açıldı) ASLA
  /// işlenmez. Durum değiştiren anahtarlar (`event`...) yalnız sunucudan gelen FCM yükünde etkilidir.
  ///
  /// Dönüş: hedef açıldı mı. [listFallback] false ise açılamayan hedef Bildirimler listesine DÜŞMEZ (zaten o
  /// listenin içindeyken ikinci bir liste yığılmasın; çağıran hatayı kendi gösterir).
  static Future<bool> open(Map<String, dynamic> data,
      {bool localReminder = false, bool compose = false, bool listFallback = true}) async {
    final s = session;
    final payload = localReminder ? sanitizeLocalReminderPayload(data) : data;
    if (!localReminder && s != null && s.state == SessionState.signedIn && _foreignRecipient(payload, s)) {
      return _openForeign(payload, s, compose: compose, listFallback: listFallback);
    }
    // Sohbet kapatıldı/yeniden açıldı bildirimi: durum, hedef ekran açılmadan önce işlenir (bantlı açılsın).
    if (!localReminder) ClosedConversations.instance.applyPushData(payload);
    final target = resolvePushTarget(payload);
    final nav = rootNavigatorKey.currentState;
    if (s == null || s.state != SessionState.signedIn) {
      // Oturum yok: yük atılmaz, giriş sonrası [flushPending] ile açılır.
      if (payload.isNotEmpty) {
        _pending = Map<String, dynamic>.from(data);
        _pendingLocal = localReminder;
        _pendingAt = clock();
      }
      return false;
    }
    if (nav == null) {
      // Gezgin henüz kurulmadı (soğuk açılış): birkaç kare sonra yeniden dene.
      if (_navRetries < 3) {
        _navRetries++;
        try {
          WidgetsBinding.instance.addPostFrameCallback((_) => open(data, localReminder: localReminder, compose: compose, listFallback: listFallback));
          WidgetsBinding.instance.scheduleFrame();
        } catch (_) {
          /* çerçeve altyapısı yok (saf birim testi) */
        }
      }
      return false;
    }
    _navRetries = 0;
    if (_isDuplicate(_dedupeKey(payload, compose: compose))) return true; // aynı bildirim zaten işlendi
    Analytics.instance.action('push_open', target: localReminder ? 'reminder' : 'push');
    try {
      if (await _go(nav, s, target, compose: !localReminder && compose)) return true;
    } on ApiError catch (e) {
      if (e.status == 404 || e.status == 403 || e.status == 410) {
        // Silinmiş/erişilemeyen hedef: alakasız listeye düşmek yerine açıklama (sohbette Sohbet sekmesi).
        if (target.dest == PushDest.conversation && nav.mounted) {
          nav.popUntil((r) => r.isFirst);
          shellTabRequest.value = 2;
        }
        if (nav.mounted) BuToast.show(nav.context, nav.context.l10n.pushContentGone);
        return false;
      }
    } catch (_) {
      // Açılamayan hedef: bildirim listesine düş.
    }
    if (listFallback && nav.mounted) {
      // Doğru merkez: sosyal bildirim Hareketler'e (kalp), diğerleri Bildirimler'e (zil).
      final social = notificationCategory(payload) == NotificationCategory.social;
      nav.push(MaterialPageRoute<void>(
          settings: RouteSettings(name: social ? 'activity' : 'notifications'),
          builder: (_) => NotificationsPage(session: s, socialOnly: social)));
    }
    return false;
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
  static Future<bool> _go(NavigatorState nav, Session s, PushTarget t, {bool compose = false}) async {
    final id = t.id;
    final ctx = nav.context;
    void push(Widget page, [String? screen]) =>
        nav.push(MaterialPageRoute<void>(settings: RouteSettings(name: screen), builder: (_) => page));
    switch (t.dest) {
      case PushDest.conversation:
        // 404/403: [open] "içerik yok" bilgisi + Sohbet sekmesi gösterir; ağ hatası listeye düşer.
        final conv = conversationFromDetail(await s.api.get('/conversations/$id'));
        if (conv == null) return false; // beklenmeyen biçim: Bildirimler listesine düş
        push(ChatDetailPage(session: s, conversation: conv, focusComposer: compose), 'chat_detail');
        return true;
      case PushDest.chatList:
        // Sohbet sekmesi: açık rotaları kapatıp kabukta Sohbet'e geç.
        nav.popUntil((r) => r.isFirst);
        shellTabRequest.value = 2;
        return true;
      case PushDest.event:
        showModalBottomSheet<void>(
            context: ctx,
            useRootNavigator: true,
            useSafeArea: true,
            isScrollControlled: true,
            showDragHandle: true,
            clipBehavior: Clip.antiAlias,
            builder: (_) => FractionallySizedBox(
                heightFactor: .94,
                child: EventDetailPage(session: s, eventId: id!, autoScan: compose)));
        return true;
      case PushDest.community:
        push(ClubDetailPage(session: s, communityId: id!), 'club_detail');
        return true;
      case PushDest.news:
        push(NewsDetailPage(session: s, item: <String, dynamic>{'id': id}), 'news_detail');
        return true;
      case PushDest.post:
        // Push/derin bağlantı: gönderi ilk sırada, altında akış sürer (alınamazsa yalnız o gönderi).
        await openPostDetail(ctx, s, id!, stream: const PostStreamSeed.fresh(), openCommentId: t.commentId);
        return true;
      case PushDest.poll:
        showModalBottomSheet<void>(
            context: ctx,
            useRootNavigator: true,
            useSafeArea: true,
            isScrollControlled: true,
            showDragHandle: true,
            clipBehavior: Clip.antiAlias,
            builder: (_) => FractionallySizedBox(
                heightFactor: .9,
                child: PollDetailPage(session: s, pollId: id!)));
        return true;
      case PushDest.user:
        await openUserProfile(ctx, s, userId: id!);
        return true;
      case PushDest.forumTopic:
        // Konu (+ varsa yorum) doğrudan açılır; silinmiş/erişilemeyen içerik bildirim listesine düşer (üstteki catch).
        await openTopicDetail(ctx, s, id!, commentId: t.commentId);
        return true;
      case PushDest.forumComment:
        // Yalnız yorum kimliği geldi: konu `GET /forum/comments/{id}` ile çözülür.
        final c = await ForumApi(s).comment(id!);
        if (c.topicId <= 0) return false;
        await openTopicDetail(ctx, s, c.topicId, commentId: id);
        return true;
      case PushDest.followRequests:
        push(FollowRequestsPage(session: s), 'follow_requests');
        return true;
      case PushDest.timetable:
        push(TimetablePage(session: s), 'timetable');
        return true;
      case PushDest.exams:
        if (id != null) {
          showModalBottomSheet<void>(
              context: ctx,
              useRootNavigator: true,
              useSafeArea: true,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(ctx).height * .9),
                  child: NotificationExamDetail(session: s, examId: id)));
        } else {
          push(ExamsPage(session: s), 'exams');
        }
        return true;
      case PushDest.course:
        push(MyCourseDetailPage(session: s, courseId: id!), 'my_course_detail');
        return true;
      case PushDest.ticket:
        push(SupportTicketPage(session: s, ticketId: id!), 'support_ticket');
        return true;
      case PushDest.meal:
        push(MenuPage(session: s), 'menu');
        return true;
      case PushDest.accountSecurity:
        push(AccountSecurityPage(session: s), 'account_security');
        return true;
      case PushDest.devices:
        push(DevicesPage(session: s), DevicesPage.routeName);
        return true;
      case PushDest.feedback:
        push(SupportPage(session: s), 'support');
        return true;
      case PushDest.url:
        // Kampanya bağlantısı (yalnız https; resolvePushTarget doğruladı): dış tarayıcıda açılır.
        final u = t.url == null ? null : Uri.tryParse(t.url!);
        if (u == null || u.scheme != 'https') return false;
        return launchUrl(u, mode: LaunchMode.externalApplication);
      case PushDest.notifications:
        return false;
    }
  }
}
