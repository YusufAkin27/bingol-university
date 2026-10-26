import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'chat_detail_page.dart';
import 'new_chat_page.dart';

/// Sohbet sekmesi: konuşma listesi (birebir, grup, kulüp, etkinlik).
class ChatTab extends StatefulWidget {
  const ChatTab({super.key, required this.session});

  final Session session;

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  static const _filters = ['Tümü', 'Kişiler', 'Kulüpler', 'Etkinlikler'];

  final _scroll = ScrollController();
  final _items = <Map<String, dynamic>>[];
  int _filter = 0;
  String _query = '';
  int? _cursor;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_cursor != null && !_loadingMore && !_loading && _scroll.position.extentAfter < 300) {
      _loadMore();
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final res = await widget.session.api.get('/conversations?size=30');
      final page = _parse(res);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.$1);
        _cursor = page.$2;
        _error = null;
        _loading = false;
      });
      _syncBadge();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Yenilemede eldeki liste korunur; yalnızca boşken hata ekranı gösterilir.
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final cursor = _cursor;
    if (cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final res = await widget.session.api.get('/conversations?size=30&cursor=$cursor');
      final page = _parse(res);
      if (!mounted) return;
      setState(() {
        final known = _items.map((c) => c['id']).toSet();
        _items.addAll(page.$1.where((c) => !known.contains(c['id'])));
        _cursor = page.$2;
        _loadingMore = false;
      });
      _syncBadge();
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  (List<Map<String, dynamic>>, int?) _parse(dynamic res) {
    final map = res is Map ? res : const {};
    final raw = map['items'];
    final list = <Map<String, dynamic>>[
      if (raw is List)
        for (final e in raw)
          if (e is Map) Map<String, dynamic>.from(e),
    ];
    final next = map['nextCursor'];
    return (list, next is num ? next.toInt() : null);
  }

  void _syncBadge() {
    var total = 0;
    for (final c in _items) {
      if (c['muted'] == true) continue;
      final n = c['unreadCount'];
      if (n is num) total += n.toInt();
    }
    widget.session.badges.chat.value = total;
  }

  Future<void> _openNew() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => NewChatPage(session: widget.session)));
    if (mounted) _load(silent: true);
  }

  Future<void> _openChat(Map<String, dynamic> c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatDetailPage(session: widget.session, conversation: c)),
    );
    if (mounted) _load(silent: true);
  }

  static String _type(Map<String, dynamic> c) => (c['type'] as String?)?.toUpperCase() ?? 'DIRECT';

  static String _title(Map<String, dynamic> c) {
    final type = _type(c);
    final peer = c['peer'];
    if (type == 'DIRECT' && peer is Map && (peer['displayName'] as String?)?.isNotEmpty == true) {
      return peer['displayName'] as String;
    }
    final t = c['title'] as String?;
    return (t != null && t.isNotEmpty) ? t : 'Sohbet';
  }

  List<Map<String, dynamic>> get _visible {
    final q = _query.trim().toLowerCase();
    return _items.where((c) {
      final type = _type(c);
      final ok = switch (_filter) {
        1 => type == 'DIRECT' || type == 'GROUP',
        2 => type == 'CLUB',
        3 => type == 'EVENT',
        _ => true,
      };
      return ok && (q.isEmpty || _title(c).toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(
            title: 'Sohbet',
            actions: [BuIconButton(icon: LucideIcons.plus, filled: true, tooltip: 'Yeni sohbet', onTap: _openNew)],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: BuSearchField(hint: 'Kişi veya grup ara', onChanged: (v) => setState(() => _query = v)),
          ),
          SizedBox(
            height: 36,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => BuChip(
                label: _filters[i],
                selected: i == _filter,
                onTap: () => setState(() => _filter = i),
              ),
            ),
          ).paddedTop(14),
          Expanded(child: _body(t)),
        ],
      ),
    );
  }

  Widget _body(BuTokens t) {
    if (_loading) return const LoadingView();
    if (_error != null && _items.isEmpty) {
      return ErrorView(error: _error!, onRetry: _load);
    }
    final list = _visible;
    return RefreshIndicator(
      color: t.pr,
      onRefresh: () => _load(silent: true),
      child: list.isEmpty ? _empty(t) : _list(list),
    );
  }

  Widget _empty(BuTokens t) {
    final searching = _query.trim().isNotEmpty || _filter != 0;
    final text = _items.isEmpty
        ? 'Henüz sohbetiniz yok'
        : searching
            ? 'Eşleşen sohbet bulunamadı'
            : 'Henüz sohbetiniz yok';
    return ListView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 40, 20, kNavInset),
      children: [
        EmptyView(icon: LucideIcons.messageCircle, text: text),
        if (_items.isEmpty)
          Center(
            child: BuButton(label: 'Yeni sohbet', icon: LucideIcons.plus, compact: true, onPressed: _openNew),
          ),
      ],
    );
  }

  Widget _list(List<Map<String, dynamic>> list) {
    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, kNavInset),
      itemCount: list.length + (_loadingMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= list.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
          );
        }
        final c = list[i];
        return _ConversationRow(
          title: _title(c),
          conversation: c,
          onTap: () => _openChat(c),
        );
      },
    );
  }
}

extension on Widget {
  Widget paddedTop(double v) => Padding(padding: EdgeInsets.only(top: v), child: this);
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.title, required this.conversation, required this.onTap});

  final String title;
  final Map<String, dynamic> conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final type = (conversation['type'] as String?)?.toUpperCase() ?? 'DIRECT';
    final peer = conversation['peer'];
    final last = conversation['lastMessage'];
    final unread = (conversation['unreadCount'] as num?)?.toInt() ?? 0;
    final muted = conversation['muted'] == true;

    final tag = switch (type) { 'CLUB' => 'Kulüp', 'EVENT' => 'Etkinlik', _ => null };
    final isDirect = type == 'DIRECT';
    final avatarUrl = isDirect && peer is Map ? peer['avatarUrl'] as String? : null;

    Widget avatar;
    if (type == 'EVENT') {
      avatar = Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: t.pr, borderRadius: BorderRadius.circular(18)),
        child: Text(initialsOf(title),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: t.onPr)),
      );
    } else {
      avatar = BuAvatar(name: title, url: avatarUrl, size: 52, square: !isDirect, dark: !isDirect);
    }

    String preview = '';
    String? when;
    if (last is Map) {
      final removed = last['removed'] == true || last['deleted'] == true;
      preview = removed ? 'Mesaj silindi' : _preview(last);
      when = last['createdAt'] as String?;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: t.ink)),
                      ),
                      if (tag != null) ...[const SizedBox(width: 6), BuBadge(tag, soft: true)],
                      if (muted) ...[
                        const SizedBox(width: 6),
                        Icon(LucideIcons.bellOff, size: 13, color: t.mut),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: unread > 0 && !muted ? t.ink : t.mut,
                        fontWeight: unread > 0 && !muted ? FontWeight.w600 : FontWeight.w400,
                      )),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_stamp(when), style: TextStyle(fontSize: 11, color: t.mut)),
                if (unread > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: muted ? t.mut : t.pr, borderRadius: BorderRadius.circular(10)),
                    child: Text(unread > 99 ? '99+' : '$unread',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: muted ? t.bg : t.onPr)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _preview(Map last) {
    final text = (last['text'] as String?)?.trim() ?? '';
    if (text.isNotEmpty) return text.replaceAll(RegExp(r'\s+'), ' ');
    final att = last['attachments'];
    if (att is List && att.isNotEmpty) return 'Görsel';
    return '';
  }

  static const _days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  static String _stamp(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    String two(int n) => n.toString().padLeft(2, '0');
    if (diff <= 0) return '${two(d.hour)}:${two(d.minute)}';
    if (diff == 1) return 'Dün';
    if (diff < 7) return _days[d.weekday - 1];
    return '${two(d.day)}.${two(d.month)}';
  }
}
