import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../chat/chat_detail_page.dart';
import '../clubs/club_detail_page.dart';
import '../events/event_detail_page.dart';
import '../news/news_detail_page.dart';
import '../posts/post_routes.dart';
import '../support/support_page.dart';
import '../support/support_ticket_page.dart';
import '../../core/typography.dart';

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

  int? _id(Object? v) => v == null ? null : int.tryParse(v.toString());

  Future<void> _open(Map<String, dynamic> n) async {
    _markOne(n);
    final d = _data(n);
    // Yeni yük: targetType + targetId; eski yük: target + value veya doğrudan anahtarlar.
    final target = (d['targetType'] ?? d['target'])?.toString().toUpperCase();
    final value = d['targetId'] ?? d['value'];
    final newsId = _id(d['newsId'] ?? (target == 'NEWS' || target == 'ANNOUNCEMENT' ? value : null));
    final eventId = _id(d['eventId'] ?? (target == 'EVENT' ? value : null));
    final communityId = _id(d['communityId'] ?? (target == 'COMMUNITY' ? value : null));
    final convId = _id(d['conversationId'] ?? (target == 'CONVERSATION' || target == 'MESSAGE' ? value : null));
    final ticketId = _id(d['ticketId'] ?? (target == 'TICKET' ? value : null));
    final feedbackId = _id(d['feedbackId'] ?? (target == 'FEEDBACK' ? value : null));

    final postId = _id(d['postId'] ?? (target == 'POST' ? value : null));
    if (postId != null) {
      await openPostDetail(context, _s, postId, focusCommentId: _id(d['commentId']));
      return;
    }

    Widget? page;
    if (convId != null) {
      try {
        final c = await _s.api.get('/conversations/$convId') as Map<String, dynamic>;
        if (!mounted) return;
        page = ChatDetailPage(session: _s, conversation: c);
      } catch (e) {
        if (mounted) _snack(errorText(e));
        return;
      }
    } else if (eventId != null) {
      page = EventDetailPage(session: _s, eventId: eventId);
    } else if (communityId != null) {
      page = ClubDetailPage(session: _s, communityId: communityId);
    } else if (ticketId != null) {
      page = SupportTicketPage(session: _s, ticketId: ticketId);
    } else if (feedbackId != null) {
      page = SupportPage(session: _s);
    } else if (newsId != null) {
      page = NewsDetailPage(session: _s, item: {'id': newsId, 'title': n['title']});
    }
    if (page == null || !mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page!));
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
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return 'DAHA ESKİ';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'BUGÜN';
    if (diff == 1) return 'DÜN';
    return 'DAHA ESKİ';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final pill = _unread > 0 || _s.badges.notifications.value > 0
        ? GestureDetector(
            onTap: _markAll,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(18)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(LucideIcons.checkCheck, size: 14.5, color: t.onSoft),
                const SizedBox(width: 6),
                Text('Tümünü okundu yap',
                    style: BuType.label.copyWith(color: t.onSoft)),
              ]),
            ),
          )
        : null;

    Widget body;
    if (_loading) {
      body = const LoadingView();
    } else if (_error != null && _items.isEmpty) {
      body = ErrorView(error: _error!, onRetry: _load);
    } else if (_items.isEmpty) {
      body = RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: ListView(children: const [
          SizedBox(height: 120),
          EmptyView(icon: LucideIcons.bellOff, text: 'Henüz bildiriminiz yok'),
        ]),
      );
    } else {
      final children = <Widget>[];
      String? last;
      for (final n in _items) {
        final g = _group(n['createdAt'] as String?);
        if (g != last) {
          last = g;
          children.add(Padding(
            padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
            child: Text(g,
                style: BuType.label.copyWith(letterSpacing: .5, color: t.mut)),
          ));
        }
        children.add(Padding(padding: const EdgeInsets.only(bottom: 8), child: _tile(t, n)));
      }
      if (_more) {
        children.add(const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())));
      }
      body = RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 24),
          children: children,
        ),
      );
    }

    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(
          title: 'Bildirimler',
          onBack: () => Navigator.pop(context),
          actions: [if (pill != null) pill],
        ),
        Expanded(child: body),
      ]),
    );
  }

  Widget _tile(BuTokens t, Map<String, dynamic> n) {
    final un = n['read'] != true;
    final body = (n['body'] as String?) ?? '';
    return Material(
      color: un ? t.soft : t.sf,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _open(n),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: un ? Colors.transparent : t.bd),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: un ? t.pr : t.sf2, borderRadius: BorderRadius.circular(14)),
              child: Icon(_icon(n['type'] as String?), size: 18, color: un ? t.onPr : t.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: un ? 14 : 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text((n['title'] as String?) ?? '',
                      style: BuType.bodyStrong.copyWith(height: 1.3, color: t.ink)),
                  if (body.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: BuType.caption.copyWith(height: 1.4, color: un ? t.onSoft : t.mut)),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(relativeTime(n['createdAt'] as String?),
                        style: BuType.micro.copyWith(color: t.mut)),
                  ),
                ]),
              ),
            ),
            if (un)
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle),
              ),
          ]),
        ),
      ),
    );
  }
}
