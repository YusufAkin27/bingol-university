import '../../core/analytics.dart';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../core/push/notification_push_card.dart';
import '../../core/push/push_actions.dart';
import '../../core/push/push_card_parts.dart';
import '../../core/push/push_router.dart';
import '../../core/push/push_targets.dart';
import '../../core/push/notification_presentation.dart';
import '../chat/chatlist_widgets.dart' show ChatlistAvatar;
import '../follow/follow_requests_api.dart';
import '../follow/follow_requests_entry.dart';
import '../academic/academic_models.dart' show istanbulWall;
import '../news/news_tile.dart' show newsLocalDate, newsMonthName;
import 'notif_row.dart';

/// Uygulama içi bildirim listesi (design/P-Notifications).
class NotificationsPage extends StatefulWidget {
  const NotificationsPage(
      {super.key, required this.session, this.socialOnly = false});

  final Session session;

  /// Ana sayfadaki kalp: yalnız sosyal etkileşimler (takip isteği, yeni takipçi, beğeni); kategori çipleri gizlenir.
  final bool socialOnly;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _items = <Map<String, dynamic>>[];
  final _scroll = ScrollController();
  int? _cursor;
  bool _loading = true;
  bool _more = false;
  bool _unreadOnly = false;
  NotificationCategory? _category;
  int _generation = 0;
  final _acting = <Object?>{};
  Object? _error;

  /// Yenilemede artar: üstteki "Takip istekleri" satırı sayısını yeniden yükler.
  int _reqRefresh = 0;

  Session get _s => widget.session;

  @override
  void initState() {
    super.initState();
    if (widget.socialOnly) _category = NotificationCategory.social;
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        _loadMore();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final generation = ++_generation;
    if (!silent) setState(() => _loading = _items.isEmpty);
    if (silent) _reqRefresh++;
    try {
      final r = await _s.api.get(_listPath()) as Map<String, dynamic>;
      if (!mounted || generation != _generation) return;
      setState(() {
        _items
          ..clear()
          ..addAll(_inbox(r['items']));
        _cursor = (r['nextCursor'] as num?)?.toInt();
        _error = null;
        _more = false;
        _loading = false;
      });
      final u = (r['unreadCount'] as num?)?.toInt();
      if (u != null) _s.badges.notifications.value = u;
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e;
        _more = false;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_cursor == null || _more || _loading) return;
    final generation = _generation;
    setState(() => _more = true);
    try {
      final r =
          await _s.api.get(_listPath(cursor: _cursor)) as Map<String, dynamic>;
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(_inbox(r['items']));
        _cursor = (r['nextCursor'] as num?)?.toInt();
        _more = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _more = false);
    }
  }

  /// Sohbet mesajları Bildirimler'e düşmez (sohbet kendi sekmesindedir; push yine gider ve sohbeti açar). Sunucu
  /// artık `MESSAGE` döndürmez; eski sürüm/önbellekten gelen satır istemcide de gizlenir.
  static List<Map<String, dynamic>> _inbox(Object? items) => [
        for (final e in (items as List?) ?? const [])
          if (e is Map<String, dynamic> &&
              '${e['type'] ?? ''}'.toUpperCase() != 'MESSAGE')
            e,
      ];

  String _listPath({int? cursor}) {
    final query = <String, String>{
      if (cursor != null) 'cursor': cursor.toString(),
      if (_category != null) 'category': _category!.name.toUpperCase(),
      if (_unreadOnly) 'unread': 'true',
    };
    return Uri(
            path: '/notifications',
            queryParameters: query.isEmpty ? null : query)
        .toString();
  }

  void _selectUnread(bool unread) {
    if (_unreadOnly == unread) return;
    setState(() {
      _unreadOnly = unread;
      _items.clear();
      _cursor = null;
      _more = false;
      _error = null;
    });
    _load();
  }

  void _selectCategory(NotificationCategory? category) {
    if (_category == category) return;
    setState(() {
      _category = category;
      _items.clear();
      _cursor = null;
      _more = false;
      _error = null;
    });
    _load();
  }

  Map<String, dynamic> _presentationData(Map<String, dynamic> n) => {
        ..._data(n),
        // İstek anı projeksiyonları (sunucu kalıcı `data`'ya yazmaz).
        if (n['actorAvatarUrl'] != null) 'actorAvatarUrl': n['actorAvatarUrl'],
        if (n['sourceName'] != null) 'sourceName': n['sourceName'],
        'type': n['type'],
        if (n['subtype'] != null) 'subtype': n['subtype'],
        if (n['category'] != null) 'category': n['category'],
      };

  int get _unread => _items.where((n) => n['read'] != true).length;

  void _snack(String m) => BuToast.show(context, m, kind: BuToastKind.error);

  Future<void> _markAll() async {
    try {
      final unreadIds = [
        for (final n in _items)
          if (n['read'] != true) n['id']
      ];
      // Kalp ekranında yalnız görünen sosyal bildirimler okundu olur; zil sayacı kalanı gösterir.
      if (widget.socialOnly) {
        if (unreadIds.isNotEmpty) {
          await _s.api.post('/notifications/read', {'ids': unreadIds});
        }
      } else {
        await _s.api.post('/notifications/read', {'all': true});
      }
      if (!mounted) return;
      setState(() {
        for (final n in _items) {
          n['read'] = true;
        }
      });
      final cur = _s.badges.notifications.value;
      _s.badges.notifications.value =
          widget.socialOnly ? (cur - unreadIds.length).clamp(0, cur) : 0;
    } catch (e) {
      if (mounted) _snack(errorText(e));
    }
  }

  Future<void> _markOne(Map<String, dynamic> n) async {
    if (n['read'] == true) return;
    setState(() => n['read'] = true);
    final cur = _s.badges.notifications.value;
    _s.badges.notifications.value = cur > 0 ? cur - 1 : 0;
    try {
      await _s.api.post('/notifications/read', {
        'ids': [n['id']],
      });
    } catch (_) {
      // Sessiz: bir sonraki yüklemede sayaç sunucudan eşitlenir.
    }
  }

  Map<String, dynamic> _data(Map<String, dynamic> n) {
    final d = n['data'];
    try {
      if (d is String && d.isNotEmpty) {
        final m = jsonDecode(d);
        if (m is Map) return m.cast<String, dynamic>();
      } else if (d is Map) {
        return d.cast<String, dynamic>();
      }
    } catch (_) {}
    return {};
  }

  Future<void> _open(Map<String, dynamic> n) async {
    Analytics.instance.action('notif_open');
    _markOne(n);
    // Tek yönlendirme tablosu: push dokunuşu ile aynı (core/push/push_targets.dart).
    final d = _data(n);
    final t = resolvePushTarget(d);
    if (t.dest == PushDest.notifications) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => SafeArea(
            child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Icon(notificationIcon(_presentationData(n)),
                      color: context.bu.ink),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(_typeLabel(n['type'] as String?),
                          style: BuType.caption)),
                  IconButton(
                      tooltip: context.l10n.commonClose,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(BuIcons.x)),
                ]),
                const SizedBox(height: 12),
                Text(n['title'] as String? ?? '',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(n['body'] as String? ?? '',
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 16),
                Text(_ago(n['createdAt'] as String?), style: BuType.caption),
              ]),
        )),
      );
      return;
    }
    // Hedef açılamazsa ikinci bir Bildirimler sayfası yığma; kullanıcıya nedenini söyle.
    final opened = await PushRouter.open(d, listFallback: false);
    if (!opened && mounted) _snack(context.l10n.notifTargetOpenFailed);
  }

  String _group(String? iso, [DateTime? nowOverride]) {
    final l = context.l10n;
    final inst = iso == null ? null : DateTime.tryParse(iso);
    if (inst == null) return l.notifGroupOlder;
    // Gün sınırı Europe/Istanbul takvimine göre (cihaz saat diliminden bağımsız).
    final d = istanbulWall(inst);
    final now = istanbulWall(nowOverride ?? DateTime.now());
    final diff = DateTime.utc(now.year, now.month, now.day).difference(DateTime.utc(d.year, d.month, d.day)).inDays;
    if (diff <= 0) return l.notifGroupToday;
    if (diff == 1) return l.notifGroupYesterday;
    return l.notifGroupOlder;
  }

  String _typeLabel(String? type) {
    final l = context.l10n;
    switch (type) {
      case 'NEWS':
        return l.bildirimTypeNews;
      case 'ANNOUNCEMENT':
        return l.bildirimTypeAnnouncement;
      case 'EVENT':
        return l.bildirimTypeEvent;
      case 'COMMUNITY':
        return l.bildirimTypeCommunity;
      case 'POLL':
      case 'POLL_CLOSED':
      case 'POLL_NEW':
        return l.bildirimTypePoll;
      case 'FORUM_TOPIC_COMMENT':
      case 'FORUM_COMMENT_REPLY':
      case 'FORUM_COMMENT_LIKE':
      case 'FORUM_TOPIC_LIKE':
      case 'FORUM_FOLLOWED_TOPIC_COMMENT':
      case 'FORUM_MODERATION':
        return l.forumPrefsNotifLabel;
      case 'POST_LIKE':
      case 'POST_MENTION':
      case 'POST_COMMENT':
      case 'COMMENT_REPLY':
        return l.bildirimTypePost;
      case 'USER_FOLLOW':
      case 'FOLLOW':
      case 'FOLLOW_REQUEST':
      case 'FOLLOW_ACCEPTED':
        return l.frqNotifTypeFollow;
      default:
        return l.bildirimTypeOther;
    }
  }

  /// Sağ hizalı zaman (tasarım 08): şimdi / 12 dk önce / 2 sa önce / Dün 11:30 / 3 gün önce; bir haftadan eskide tarih.
  String _ago(String? iso) {
    final l = context.l10n;
    final inst = iso == null ? null : DateTime.tryParse(iso);
    if (inst == null) return '';
    final nowI = DateTime.now();
    final diff = nowI.difference(inst);
    if (diff.inMinutes < 1) return l.notifNow;
    if (diff.inMinutes < 60) {
      return l.notifAgoMin(diff.inMinutes.toString());
    }
    final d = istanbulWall(inst);
    final now = istanbulWall(nowI);
    final days = DateTime.utc(now.year, now.month, now.day).difference(DateTime.utc(d.year, d.month, d.day)).inDays;
    if (days <= 0) return l.notifAgoHour(diff.inHours.toString());
    if (days == 1) {
      return l.notifYesterdayAt(
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}');
    }
    if (days < 7) return l.notifAgoDay(days.toString());
    // Aynı yıl: "22 Ekim"; daha eski: yıllı tam tarih.
    return d.year == now.year
        ? '${d.day} ${newsMonthName(context, d.month)}'
        : newsLocalDate(context, iso);
  }

  Future<void> _delete(Map<String, dynamic> n) async {
    final wasUnread = n['read'] != true;
    setState(() => _items.remove(n));
    if (wasUnread) {
      final cur = _s.badges.notifications.value;
      _s.badges.notifications.value = cur > 0 ? cur - 1 : 0;
    }
    try {
      await _s.api.delete('/notifications/${n['id']}');
    } catch (e) {
      if (!mounted) return;
      _snack(errorText(e));
      _load(silent: true);
    }
  }

  Future<void> _decide(Map<String, dynamic> n, int userId, bool accept) async {
    if (!_acting.add(n['id'])) return;
    setState(() {});
    try {
      final api = FollowRequestsApi(_s);
      if (accept) {
        await api.accept(userId);
      } else {
        await api.decline(userId);
      }
      if (!mounted) return;
      setState(() => n['actionResolved'] = true);
      await _markOne(n);
      if (mounted) setState(() => _reqRefresh++);
    } catch (e) {
      if (mounted) _snack(errorText(e));
    } finally {
      _acting.remove(n['id']);
      if (mounted) setState(() {});
    }
  }

  /// Satır içi aksiyon: kartla aynı tablo (`pushCardActions`); işlev `PushActions` içindedir. Sonra bildirim okundu sayılır.
  Future<void> _run(Map<String, dynamic> n, String action) async {
    final key = '${n['id']}:$action';
    if (!_acting.add(key)) return;
    setState(() {});
    try {
      final ok = await PushActions(_s).perform({
        ..._data(n),
        'type': n['type'],
        'notificationAction': action,
        'actionId': 'inbox-$key-${DateTime.now().microsecondsSinceEpoch}',
      });
      if (!mounted) return;
      if (!ok) {
        _snack(context.l10n.notifTargetOpenFailed);
      } else {
        if (action == 'follow') setState(() => n['actionResolved'] = true);
        await _markOne(n);
      }
    } catch (e) {
      if (mounted) _snack(errorText(e));
    } finally {
      _acting.remove(key);
      if (mounted) setState(() {});
    }
  }

  void _resetFilters() {
    final base = widget.socialOnly ? NotificationCategory.social : null;
    if (_category == base && !_unreadOnly) return;
    setState(() {
      _category = base;
      _unreadOnly = false;
      _items.clear();
      _cursor = null;
      _more = false;
      _error = null;
    });
    _load();
  }

  Widget _categories() => SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: _NotifFilterChip(
                    key: const ValueKey('notif-seg-all'),
                    label: context.l10n.bildirimFilterAll,
                    selected: (widget.socialOnly
                            ? _category == NotificationCategory.social
                            : _category == null) &&
                        !_unreadOnly,
                    onTap: _resetFilters)),
            Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: _NotifFilterChip(
                    key: const ValueKey('notif-seg-unread'),
                    label: context.l10n.bildirimFilterUnread,
                    selected: _unreadOnly,
                    onTap: () => _selectUnread(!_unreadOnly))),
            if (!widget.socialOnly)
              for (final category in NotificationCategory.values)
              Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: _NotifFilterChip(
                      key: ValueKey('notif-category-${category.name}'),
                      label: notificationCategoryLabel(context, category),
                      selected: _category == category,
                      onTap: () => _selectCategory(category))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    // "N Yeni" rozeti solda, "Tümünü okundu yap" sağda (tasarım 08); dar ekran / büyük yazıda metin 2 satıra iner.
    final bigText = MediaQuery.textScalerOf(context).scale(10) > 11.5 ||
        MediaQuery.sizeOf(context).width < 380;
    final newCount = _s.badges.notifications.value > 0
        ? _s.badges.notifications.value
        : _unread;
    final pill = newCount > 0
        ? Row(children: [
            Container(
              key: const ValueKey('notif-new-badge'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: t.sf2,
                  border: Border.all(color: t.bd),
                  borderRadius: BorderRadius.circular(BuRadius.pill)),
              child: Text(l.notifNewCount(newCount.toString()),
                  style: BuType.caption.copyWith(
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: FontWeight.w400,
                      color: t.ink)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: BuPressable(
                  onTap: _markAll,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(l.notifMarkAll,
                        maxLines: bigText ? 2 : 1,
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: BuType.caption.copyWith(
                            fontSize: 14,
                            height: 1.3,
                            fontWeight: FontWeight.w400,
                            color: t.ink)),
                  ),
                ),
              ),
            ),
          ])
        : null;

    final shown =
        _unreadOnly ? _items.where((n) => n['read'] != true).toList() : _items;
    final failed = _error != null;

    Widget body;
    if (failed && _items.isEmpty) {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [_ErrorCard(onRetry: _load)],
      );
    } else if (shown.isEmpty) {
      final unreadEmpty = _unreadOnly && _items.isNotEmpty;
      // Boş: ortada soluk tek cümle (illüstrasyon yok).
      body = RefreshIndicator(
        onRefresh: Analytics.pullRefresh(() => _load(silent: true)),
        child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              SizedBox(
                height: 360,
                child: Center(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                        unreadEmpty
                            ? l.bildirimEmptyUnread
                            : (widget.socialOnly
                                ? l.activityEmpty
                                : l.notifEmpty),
                        textAlign: TextAlign.center,
                        style: BuType.caption
                            .copyWith(fontSize: 16, height: 1.5, color: t.mut)),
                  ),
                ),
              ),
            ]),
      );
    } else {
      final children = <Widget>[];
      if (failed) {
        children.add(Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: _ErrorCard(onRetry: _load)));
      }
      String? last;
      var row = 0;
      final groupUnread = <String, int>{};
      for (final n in shown) {
        if (n['read'] != true) {
          final g = _group(n['createdAt'] as String?);
          groupUnread[g] = (groupUnread[g] ?? 0) + 1;
        }
      }
      for (final n in shown) {
        final g = _group(n['createdAt'] as String?);
        if (g != last) {
          last = g;
          children.add(Padding(
            padding:
                EdgeInsetsDirectional.fromSTEB(20, row == 0 ? 8 : 16, 20, 6),
            child: Semantics(
              header: true,
              child: Row(children: [
                Expanded(
                  child: Text(trUpper(g),
                      style: BuType.caption.copyWith(
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: FontWeight.w400,
                          letterSpacing: .6,
                          color: t.mut)),
                ),
                if ((groupUnread[g] ?? 0) > 0)
                  Text(l.notifGroupUnread('${groupUnread[g]}'),
                      key: ValueKey('notif-group-unread-$g'),
                      style: BuType.caption.copyWith(
                          fontSize: 13, height: 1.3, color: t.mut)),
              ]),
            ),
          ));
        }
        // İlk görünürde ilk 8 satır sırayla belirir; kaydırınca ya da süzünce yeniden oynamaz.
        children.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: BuStaggerItem(index: row++, child: _tile(t, n))));
      }
      if (_more) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Center(
            child: Semantics(
              label: l.p03NotifLoadingMore,
              liveRegion: true,
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: t.mut)),
            ),
          ),
        ));
      } else if (_cursor != null) {
        children.add(Center(
            child: TextButton(
          key: const ValueKey('notif-load-more'),
          onPressed: _loadMore,
          child: Text(l.eventFormShowMore),
        )));
      } else {
        // Liste sonu: tek sakin satır.
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(l.bildirimAllCaughtUp,
                textAlign: TextAlign.center,
                style: BuType.caption
                    .copyWith(fontSize: 13, height: 1.4, color: t.mut)),
          ),
        ));
      }
      body = RefreshIndicator(
        onRefresh: Analytics.pullRefresh(() => _load(silent: true)),
        child: BuStaggerScope(
          child: ListView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
                0, 0, 0, MediaQuery.of(context).padding.bottom),
            children: children,
          ),
        ),
      );
    }

    // İskelet -> içerik: yalnız opaklık geçişi (düzen kayması yok).
    body = BuSwapIn(
      loading: _loading,
      skeleton: const BuSkeletonList(
          itemCount: 6, padding: EdgeInsets.fromLTRB(20, 12, 20, 24)),
      child: body,
    );

    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(
          title: widget.socialOnly ? l.activityTitle : l.notifTitle,
          onBack: () => Navigator.pop(context),
        ),
        if (pill != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 0),
            child: pill,
          ),
        FollowRequestsEntry(session: _s, refresh: _reqRefresh),
        _categories(),
        Expanded(child: body),
      ]),
    );
  }

  Widget _tile(BuTokens t, Map<String, dynamic> n) {
    final l = context.l10n;
    final un = n['read'] != true;
    final type = n['type'] as String?;
    final data = _presentationData(n);
    final category = notificationCategory(data);
    final style = pushCardStyle(data);
    final person =
        style.startsWith('FOLLOW') || style == 'SOCIAL' || style == 'LIKE' || style == 'MENTION';
    final avatarUrl = pushImageUrl(
        (n['actorAvatarUrl'] ?? data['senderAvatarUrl']) as String?);
    final title = (n['title'] as String?) ?? '';
    final requester =
        int.tryParse((data['userId'] ?? data['requesterId'] ?? '').toString());
    final destination = resolvePushTarget(data).dest;
    final canAct = un && n['actionResolved'] != true;
    // Satır içi aksiyonlar: kartla AYNI tablo; sohbet/dokunuşla açılan genel aksiyonlar satır dokunuşuyla zaten var.
    const rowOnly = {'open', 'open_all', 'reply', 'mark_read', 'mute_hour', 'ack'};
    final inline = !canAct
        ? const <String>[]
        : [
            for (final a in pushCardActions(data))
              if (!rowOnly.contains(a) &&
                  switch (a) {
                    'follow_accept' || 'follow_decline' =>
                      type == 'FOLLOW_REQUEST' &&
                          requester != null &&
                          requester > 0,
                    'follow' => requester != null && requester > 0,
                    'calendar' || 'map' => destination == PushDest.event,
                    _ => true,
                  })
                a,
          ];
    final securityKind =
        data['securityKind'] is String ? data['securityKind'] as String : null;
    final busy = _acting.any(
        (k) => '$k' == '${n['id']}' || '$k'.startsWith('${n['id']}:'));
    return Dismissible(
      key: ValueKey('notif-${n['id']}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        buHaptic(BuHaptic.light);
        _delete(n);
      },
      // Sola kaydırınca sağdan `danger` zeminli "Sil" levhası (köşe 0, satırın yüksekliğinde).
      background: Container(
        color: t.danger,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 24),
        child: Text(l.bildirimDelete,
            style: BuType.caption.copyWith(
                fontSize: 14, fontWeight: FontWeight.w400, color: t.onMedia)),
      ),
      child: NotifRow(
        title: title,
        typeLabel: category == NotificationCategory.academic ||
                category == NotificationCategory.system
            ? notificationCategoryLabel(context, category)
            : _typeLabel(type),
        style: style,
        avatar: person
            ? PushAvatar(
                name: title,
                url: avatarUrl,
                role: pushAvatarRole(data),
                headers: ChatlistAvatar.authHeadersFor(avatarUrl))
            : null,
        source:
            data['sourceName'] is String ? data['sourceName'] as String : null,
        badge: data['badgeText'] is String ? data['badgeText'] as String : null,
        badgeTone: pushBadgeTone(data),
        chips: pushInfoChips(l, data, style),
        critical: data['severity'] == 'critical',
        actions: [
          for (final a in inline)
            PushActionButton(
              label: pushActionLabel(context, a, style,
                  securityKind: securityKind),
              icon: pushActionIcon(a, style),
              kind: pushActionKind(a, style),
              onPressed: busy
                  ? null
                  : switch (a) {
                      'follow_accept' => () => _decide(n, requester!, true),
                      'follow_decline' => () => _decide(n, requester!, false),
                      _ => () => _run(n, a),
                    },
            ),
        ],
        body: (n['body'] as String?) ?? '',
        time: _ago(n['createdAt'] as String?),
        unread: un,
        unreadLabel: l.notifUnread,
        onTap: () => _open(n),
      ),
    );
  }
}

/// Süzgeç hapı (Stitch v3): seçili = `soft` zemin + `pr` metin (çerçevesiz); seçili değil = 1 dp `bd` çerçeve +
/// ink metin. Görünür yükseklik 34 dp, dokunma alanı 48 dp; sayaç rozeti yok.
class _NotifFilterChip extends StatelessWidget {
  const _NotifFilterChip(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      selected: selected,
      child: BuPressable(
        onTap: onTap,
        child: BuTouchTarget(
          child: AnimatedContainer(
            duration: BuMotion.of(context, BuMotion.short),
            constraints: const BoxConstraints(minHeight: 34),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            decoration: BoxDecoration(
              color: selected ? t.ink : t.sf2,
              borderRadius: BorderRadius.circular(BuRadius.pill),
            ),
            child: Text(label,
                style: BuType.caption.copyWith(
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: BuType.emphasisWeight,
                    color: selected ? t.bg : t.ink)),
          ),
        ),
      ),
    );
  }
}

/// Yükleme hatası: soluk tek cümle + `pr` metin eylemi.
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Semantics(
          liveRegion: true,
          child: Text(l.p03NotifLoadFailed,
              textAlign: TextAlign.center,
              style: BuType.caption
                  .copyWith(fontSize: 16, height: 1.5, color: t.mut)),
        ),
        const SizedBox(height: 8),
        BuPressable(
          onTap: onRetry,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l.commonRetry,
                style: BuType.caption.copyWith(
                    fontSize: 14, fontWeight: FontWeight.w400, color: t.ink)),
          ),
        ),
      ]),
    );
  }
}
