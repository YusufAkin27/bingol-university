import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../../core/push/push_router.dart';
import '../../core/push/push_targets.dart';
import '../../core/typography.dart';
import '../news/news_tile.dart' show newsLocalDate;
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
  Object? _error;

  Session get _s => widget.session;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = _items.isEmpty);
    try {
      final r = await _s.api.get('/notifications') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(((r['items'] as List?) ?? []).cast<Map<String, dynamic>>());
        _cursor = (r['nextCursor'] as num?)?.toInt();
        _error = null;
        _loading = false;
      });
      final u = (r['unreadCount'] as num?)?.toInt();
      if (u != null) _s.badges.notifications.value = u;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_cursor == null || _more || _loading) return;
    setState(() => _more = true);
    try {
      final r = await _s.api.get('/notifications?cursor=$_cursor') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _items.addAll(((r['items'] as List?) ?? []).cast<Map<String, dynamic>>());
        _cursor = (r['nextCursor'] as num?)?.toInt();
        _more = false;
      });
    } catch (_) {
      if (mounted) setState(() => _more = false);
    }
  }

  int get _unread => _items.where((n) => n['read'] != true).length;

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

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
    if (t.dest == PushDest.notifications || t.dest == PushDest.signOut) return;
    await PushRouter.open(d);
  }

  IconData _icon(String? type) {
    switch (type) {
      case 'NEWS':
        return LucideIcons.newspaper;
      case 'ANNOUNCEMENT':
        return LucideIcons.megaphone;
      case 'EVENT':
        return LucideIcons.calendarDays;
      case 'MESSAGE':
        return LucideIcons.messageCircle;
      case 'COMMUNITY':
        return LucideIcons.users;
      case 'POLL':
      case 'POLL_CLOSED':
      case 'POLL_NEW':
        return LucideIcons.vote;
      case 'POST_LIKE':
        return LucideIcons.heart;
      case 'POST_COMMENT':
        return LucideIcons.messageSquare;
      case 'COMMENT_REPLY':
        return LucideIcons.reply;
      default:
        return LucideIcons.bell;
    }
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

  NotifTone _tone(String? type) {
    switch (type) {
      case 'NEWS':
      case 'EVENT':
        return NotifTone.blue;
      case 'ANNOUNCEMENT':
      case 'MESSAGE':
      case 'POST_LIKE':
        return NotifTone.red;
      case 'COMMUNITY':
      case 'POST_COMMENT':
      case 'COMMENT_REPLY':
        return NotifTone.green;
      default:
        return NotifTone.amber;
    }
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
      case 'MESSAGE':
        return l.bildirimTypeMessage;
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
    if (diff.inMinutes < 60) return l.bildirimShortMin(diff.inMinutes.toString());
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
    if (days <= 0) return l.bildirimShortHour(diff.inHours.toString());
    if (days == 1) return l.bildirimYesterday;
    if (days < 7) return l.bildirimShortDay(days.toString());
    return newsLocalDate(context, iso);
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

  Widget _segment(BuTokens t) {
    final l = context.l10n;
    final unread = _unread > 0 ? _unread : _s.badges.notifications.value;
    Widget seg(Key k, String label, bool on, VoidCallback tap, {int badge = 0}) => Expanded(
          child: Semantics(
            button: true,
            selected: on,
            child: Material(
              color: on ? t.sf : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              elevation: on ? 1 : 0,
              shadowColor: const Color(0x33171E33),
              child: InkWell(
                key: k,
                borderRadius: BorderRadius.circular(12),
                onTap: tap,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(
                      child: Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BuType.bodyStrong.copyWith(
                              fontSize: 14, color: on ? t.ink : t.mut, fontWeight: on ? FontWeight.w700 : FontWeight.w600)),
                    ),
                    if (badge > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: t.pr, borderRadius: BorderRadius.circular(10)),
                        child: Text(badge > 99 ? '99+' : '$badge',
                            style: BuType.label.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: t.onPr)),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        seg(const ValueKey('notif-seg-all'), l.bildirimFilterAll, !_unreadOnly, () => setState(() => _unreadOnly = false)),
        const SizedBox(width: 4),
        seg(const ValueKey('notif-seg-unread'), l.bildirimFilterUnread, _unreadOnly, () => setState(() => _unreadOnly = true),
            badge: unread),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    // Büyük yazı ölçeğinde başlığı ezmesin diye düğme başlığın altına iner.
    final bigText = MediaQuery.textScalerOf(context).scale(10) > 11.5 || MediaQuery.sizeOf(context).width < 340;
    final pill = _unread > 0 || _s.badges.notifications.value > 0
        ? ConstrainedBox(
            // Dar ekran/büyük yazıda başlığı ezmesin: genişliğin sınırlı bölümü, metin kısalır.
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * (bigText ? .9 : .4)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _markAll,
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: AlignmentDirectional.centerEnd,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(l.notifMarkAll,
                    maxLines: 2,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: BuType.label.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: t.pr)),
              ),
            ),
          )
        : null;

    final shown = _unreadOnly ? _items.where((n) => n['read'] != true).toList() : _items;

    Widget body;
    if (_loading) {
      body = const LoadingView();
    } else if (_error != null && _items.isEmpty) {
      body = ErrorView(error: _error!, onRetry: _load);
    } else if (shown.isEmpty) {
      body = RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
          const SizedBox(height: 120),
          EmptyView(icon: LucideIcons.bellOff, text: _unreadOnly && _items.isNotEmpty ? l.bildirimEmptyUnread : l.notifEmpty),
        ]),
      );
    } else {
      final children = <Widget>[];
      String? last;
      for (final n in shown) {
        final g = _group(n['createdAt'] as String?);
        if (g != last) {
          last = g;
          children.add(Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 20, 24, 8),
            child: Semantics(
              header: true,
              child: Text(g, style: BuType.label.copyWith(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .5, color: t.mut)),
            ),
          ));
        }
        children.add(Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8), child: _tile(t, n)));
      }
      if (_more) {
        children.add(const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())));
      } else if (_cursor == null) {
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 28, height: 1, color: t.bd),
              const SizedBox(width: 8),
              Flexible(
                child: Text(l.bildirimAllCaughtUp,
                    textAlign: TextAlign.center,
                    style: BuType.label.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: t.mut)),
              ),
              const SizedBox(width: 8),
              Container(width: 28, height: 1, color: t.bd),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(buDirIcon(context, LucideIcons.chevronLeft), size: 14, color: t.mut),
              const SizedBox(width: 6),
              Flexible(
                child: Text(l.bildirimSwipeHint,
                    textAlign: TextAlign.center, style: BuType.caption.copyWith(fontSize: 12, color: t.mut)),
              ),
            ]),
          ]),
        ));
      }
      body = RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(0, 0, 0, MediaQuery.of(context).padding.bottom + 24),
          children: children,
        ),
      );
    }

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
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Align(alignment: AlignmentDirectional.centerEnd, child: pill),
          ),
        if (!_loading && !(_error != null && _items.isEmpty)) _segment(t),
        Expanded(child: body),
      ]),
    );
  }

  Widget _tile(BuTokens t, Map<String, dynamic> n) {
    final un = n['read'] != true;
    final type = n['type'] as String?;
    return Dismissible(
      key: ValueKey('notif-${n['id']}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _delete(n),
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 22),
        decoration: BoxDecoration(color: t.danger, borderRadius: BorderRadius.circular(20)),
        child: Semantics(label: context.l10n.bildirimDelete, child: const Icon(LucideIcons.trash2, size: 20, color: Colors.white)),
      ),
      child: NotifRow(
        icon: _icon(type),
        tone: _tone(type),
        title: (n['title'] as String?) ?? '',
        typeLabel: _typeLabel(type),
        body: (n['body'] as String?) ?? '',
        time: _ago(n['createdAt'] as String?),
        unread: un,
        unreadLabel: context.l10n.notifUnread,
        onTap: () => _open(n),
      ),
    );
  }
}
