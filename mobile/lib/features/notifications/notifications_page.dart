import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../core/push/push_router.dart';
import '../../core/push/push_targets.dart';
import '../../core/push/notification_presentation.dart';
import '../follow/follow_requests_api.dart';
import '../follow/follow_requests_entry.dart';
import '../news/news_tile.dart' show newsLocalDate, newsMonthName;
import 'notif_row.dart';

/// Uygulama içi bildirim listesi (design/P-Notifications).
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required this.session});

  final Session session;

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
        'type': n['type'],
        if (n['subtype'] != null) 'subtype': n['subtype'],
        if (n['category'] != null) 'category': n['category'],
      };

  int get _unread => _items.where((n) => n['read'] != true).length;

  void _snack(String m) => BuToast.show(context, m, kind: BuToastKind.error);

  Future<void> _markAll() async {
    try {
      await _s.api.post('/notifications/read', {'all': true});
      if (!mounted) return;
      setState(() {
        for (final n in _items) {
          n['read'] = true;
        }
      });
      _s.badges.notifications.value = 0;
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
    _markOne(n);
    // Tek yönlendirme tablosu: push dokunuşu ile aynı (core/push/push_targets.dart).
    final d = _data(n);
    final t = resolvePushTarget(d);
    if (t.dest == PushDest.notifications || t.dest == PushDest.signOut) {
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
                      color: context.bu.pr),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(_typeLabel(n['type'] as String?),
                          style: BuType.caption)),
                  IconButton(
                      tooltip: context.l10n.commonClose,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
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

  String _group(String? iso) {
    final l = context.l10n;
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return l.notifGroupOlder;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
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
      case 'POST_LIKE':
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

  /// Sağ hizalı kısa zaman: şimdi / 5 dk / 2 sa / Dün / 3 g; bir haftadan eskide tarih.
  String _ago(String? iso) {
    final l = context.l10n;
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return l.notifNow;
    if (diff.inMinutes < 60) {
      return l.bildirimShortMin(diff.inMinutes.toString());
    }
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    if (days <= 0) return l.bildirimShortHour(diff.inHours.toString());
    if (days == 1) return l.bildirimYesterday;
    if (days < 7) return l.p03NotifShortDay(days.toString());
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

  void _resetFilters() {
    if (_category == null && !_unreadOnly) return;
    setState(() {
      _category = null;
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
                    selected: _category == null && !_unreadOnly,
                    onTap: _resetFilters)),
            Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: _NotifFilterChip(
                    key: const ValueKey('notif-seg-unread'),
                    label: context.l10n.bildirimFilterUnread,
                    selected: _unreadOnly,
                    onTap: () => _selectUnread(!_unreadOnly))),
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
    // Geniş ekranda "Tümünü okundu yap" başlık satırının sağında; dar ekran / büyük yazıda başlığın altında.
    final bigText = MediaQuery.textScalerOf(context).scale(10) > 11.5 ||
        MediaQuery.sizeOf(context).width < 380;
    final pill = _unread > 0 || _s.badges.notifications.value > 0
        ? ConstrainedBox(
            // Başlığı ezmesin: genişliğin sınırlı bölümü, metin kısalır.
            constraints: BoxConstraints(
                maxWidth:
                    MediaQuery.sizeOf(context).width * (bigText ? .9 : .5)),
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
                        fontWeight: FontWeight.w600,
                        color: t.pr)),
              ),
            ),
          )
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
        onRefresh: () => _load(silent: true),
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
                        unreadEmpty ? l.bildirimEmptyUnread : l.notifEmpty,
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
      for (final n in shown) {
        final g = _group(n['createdAt'] as String?);
        if (g != last) {
          last = g;
          children.add(Padding(
            padding:
                EdgeInsetsDirectional.fromSTEB(20, row == 0 ? 8 : 16, 20, 6),
            child: Semantics(
              header: true,
              child: Text(trUpper(g),
                  style: BuType.caption.copyWith(
                      fontSize: 13,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .6,
                      color: t.mut)),
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
        onRefresh: () => _load(silent: true),
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
          title: l.notifTitle,
          onBack: () => Navigator.pop(context),
          actions: [if (pill != null && !bigText) pill],
        ),
        if (pill != null && bigText)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child:
                Align(alignment: AlignmentDirectional.centerEnd, child: pill),
          ),
        FollowRequestsEntry(session: _s, refresh: _reqRefresh),
        _categories(),
        Expanded(child: body),
      ]),
    );
  }

  Widget _tile(BuTokens t, Map<String, dynamic> n) {
    final un = n['read'] != true;
    final type = n['type'] as String?;
    final data = _presentationData(n);
    final category = notificationCategory(data);
    final destination = resolvePushTarget(data).dest;
    final requester =
        int.tryParse((data['userId'] ?? data['requesterId'] ?? '').toString());
    final followRequest = type == 'FOLLOW_REQUEST' &&
        n['read'] != true &&
        n['actionResolved'] != true &&
        requester != null &&
        requester > 0;
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
        child: Text(context.l10n.bildirimDelete,
            style: BuType.caption.copyWith(
                fontSize: 14, fontWeight: FontWeight.w600, color: t.onMedia)),
      ),
      child: NotifRow(
        title: (n['title'] as String?) ?? '',
        typeLabel: category == NotificationCategory.academic ||
                category == NotificationCategory.system
            ? notificationCategoryLabel(context, category)
            : _typeLabel(type),
        icon: notificationIcon(data),
        critical: data['severity'] == 'critical',
        actions: [
          if (followRequest) ...[
            FilledButton(
              style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16)),
              onPressed: _acting.contains(n['id'])
                  ? null
                  : () => _decide(n, requester, true),
              child: Text(context.l10n.frqReqAccept),
            ),
            TextButton(
              style: TextButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16)),
              onPressed: _acting.contains(n['id'])
                  ? null
                  : () => _decide(n, requester, false),
              child: Text(context.l10n.frqReqDecline),
            ),
          ],
          if (!followRequest &&
              destination != PushDest.notifications &&
              destination != PushDest.followRequests)
            TextButton.icon(
                onPressed: () => _open(n),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text(context.l10n.p14Detail)),
        ],
        body: (n['body'] as String?) ?? '',
        time: _ago(n['createdAt'] as String?),
        unread: un,
        unreadLabel: context.l10n.notifUnread,
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
                    fontWeight: FontWeight.w500,
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
                    fontSize: 14, fontWeight: FontWeight.w600, color: t.pr)),
          ),
        ),
      ]),
    );
  }
}
