import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/realtime/chat_realtime.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'chat_detail_page.dart';
import 'new_chat_page.dart';

/// Sohbet sekmesi: konuşma listesi (birebir, grup, kulüp, etkinlik).
/// Liste STOMP akışıyla yerinde güncellenir; bağlantı yoksa çekerek yenileme geçerlidir.
class ChatTab extends StatefulWidget {
  const ChatTab({super.key, required this.session, @visibleForTesting this.connectRealtime = true});

  final Session session;

  /// Testlerde false: gerçek WebSocket bağlantısı kurulmaz.
  final bool connectRealtime;

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  static const _filters = ['Tümü', 'Kişiler', 'Kulüpler', 'Etkinlikler'];

  final _scroll = ScrollController();
  final _items = <Map<String, dynamic>>[];
  late final ChatRealtime _rt;
  final _subs = <StreamSubscription<dynamic>>[];
  Timer? _badgeTimer;
  Timer? _reloadTimer;
  int _filter = 0;
  String _query = '';
  bool _archived = false;
  int? _cursor;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _rt = ChatRealtime(widget.session);
    if (widget.connectRealtime) _rt.start();
    _subs
      ..add(_rt.messages.listen(_onMessage))
      ..add(_rt.readReceipts.listen(_onRead))
      ..add(_rt.resync.listen((_) => _scheduleReload()));
    _load();
    _refreshBadge();
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    _reloadTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _rt.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_cursor != null && !_loadingMore && !_loading && _scroll.position.extentAfter < 300) {
      _loadMore();
    }
  }

  String get _path => '/conversations?size=30${_archived ? '&archived=true' : ''}';

  Future<void> _load({bool silent = false}) async {
    final my = ++_seq;
    if (!silent) setState(() => _loading = true);
    try {
      final res = await widget.session.api.get(_path);
      final page = _parse(res);
      if (!mounted || my != _seq) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.$1);
        _cursor = page.$2;
        _error = null;
        _loading = false;
      });
      _refreshBadge();
    } catch (e) {
      if (!mounted || my != _seq) return;
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
    final my = _seq;
    setState(() => _loadingMore = true);
    try {
      final res = await widget.session.api.get('$_path&cursor=$cursor');
      final page = _parse(res);
      if (!mounted || my != _seq) return;
      setState(() {
        final known = _items.map((c) => c['id']).toSet();
        _items.addAll(page.$1.where((c) => !known.contains(c['id'])));
        _cursor = page.$2;
        _loadingMore = false;
      });
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

  // ---- rozet ----

  void _scheduleBadge() {
    _badgeTimer?.cancel();
    _badgeTimer = Timer(const Duration(milliseconds: 600), _refreshBadge);
  }

  Future<void> _refreshBadge() async {
    try {
      final res = await widget.session.api.get('/conversations/unread-count');
      final total = res is Map ? res['total'] : null; // UnreadSummary: total (sessiz olmayanlar)
      if (total is num && mounted) widget.session.badges.chat.value = total.toInt();
    } catch (_) {
      // Rozet yedek olarak eldeki listeden hesaplanır.
      if (!_archived && mounted) _syncBadgeLocal();
    }
  }

  void _syncBadgeLocal() {
    var total = 0;
    for (final c in _items) {
      if (c['muted'] == true) continue;
      final n = c['unreadCount'];
      if (n is num) total += n.toInt();
    }
    widget.session.badges.chat.value = total;
  }

  // ---- canlı akış ----

  void _scheduleReload() {
    _reloadTimer?.cancel();
    _reloadTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _load(silent: true);
    });
  }

  void _onMessage(Map<String, dynamic> m) {
    if (!mounted || _archived) return;
    final cid = (m['conversationId'] as num?)?.toInt();
    if (cid == null) return;
    final i = _items.indexWhere((c) => (c['id'] as num?)?.toInt() == cid);
    if (i < 0) {
      _scheduleReload(); // yeni konuşma: satırı sunucudan al
      return;
    }
    final mine = (m['senderId'] as num?)?.toInt() == widget.session.userId;
    final row = Map<String, dynamic>.from(_items[i]);
    row['lastMessage'] = m;
    if (!mine) row['unreadCount'] = ((row['unreadCount'] as num?)?.toInt() ?? 0) + 1;
    setState(() {
      _items
        ..removeAt(i)
        ..insert(0, row);
    });
    _scheduleBadge();
  }

  void _onRead(ReadReceipt r) {
    if (!mounted || r.userId != widget.session.userId) return;
    final i = _items.indexWhere((c) => (c['id'] as num?)?.toInt() == r.conversationId);
    if (i < 0) return;
    setState(() => _items[i] = {..._items[i], 'unreadCount': 0});
    _scheduleBadge();
  }

  // ---- gezinme ----

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

  void _setArchiveView(bool on) {
    if (_archived == on) return;
    setState(() {
      _archived = on;
      _items.clear();
      _cursor = null;
      _error = null;
    });
    _load();
  }

  // ---- satır aksiyonları ----

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _replaceRow(Map<String, dynamic> updated) {
    final i = _items.indexWhere((c) => c['id'] == updated['id']);
    if (i < 0 || !mounted) return;
    setState(() => _items[i] = {..._items[i], ...updated});
  }

  Future<void> _mute(Map<String, dynamic> c, {int? minutes, bool forever = false}) async {
    try {
      final res = await widget.session.api.put(
        '/conversations/${c['id']}/mute',
        forever ? {'forever': true} : {'durationMinutes': minutes},
      );
      if (res is Map) _replaceRow(Map<String, dynamic>.from(res));
      _scheduleBadge();
    } catch (e) {
      _toast(errorText(e));
    }
  }

  Future<void> _unmute(Map<String, dynamic> c) async {
    try {
      final res = await widget.session.api.delete('/conversations/${c['id']}/mute');
      if (res is Map) {
        _replaceRow(Map<String, dynamic>.from(res));
      } else {
        _replaceRow({'id': c['id'], 'muted': false, 'mutedForever': false});
      }
      _scheduleBadge();
    } catch (e) {
      _toast(errorText(e));
    }
  }

  Future<void> _toggleArchive(Map<String, dynamic> c) async {
    final archive = !_archived;
    try {
      if (archive) {
        await widget.session.api.put('/conversations/${c['id']}/archive', {'keepArchived': false});
      } else {
        await widget.session.api.delete('/conversations/${c['id']}/archive');
      }
      if (!mounted) return;
      setState(() => _items.removeWhere((x) => x['id'] == c['id']));
      _toast(archive ? 'Sohbet arşivlendi' : 'Sohbet arşivden çıkarıldı');
    } catch (e) {
      _toast(errorText(e));
    }
  }

  Future<void> _showActions(Map<String, dynamic> c) async {
    final muted = c['muted'] == true;
    final t = context.bu;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.sf,
      showDragHandle: true,
      builder: (ctx) {
        Widget tile(IconData icon, String label, VoidCallback run) => ListTile(
              leading: Icon(icon, color: t.ink),
              title: Text(label, style: TextStyle(color: t.ink, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                run();
              },
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(_title(c),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: t.ink)),
                ),
              ),
              if (muted)
                tile(LucideIcons.bell, 'Sessizden çıkar', () => _unmute(c))
              else ...[
                tile(LucideIcons.bellOff, '8 saat sessize al', () => _mute(c, minutes: 480)),
                tile(LucideIcons.bellOff, '1 hafta sessize al', () => _mute(c, minutes: 10080)),
                tile(LucideIcons.bellOff, 'Süresiz sessize al', () => _mute(c, forever: true)),
              ],
              tile(LucideIcons.archive, _archived ? 'Arşivden çıkar' : 'Arşivle', () => _toggleArchive(c)),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
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

  // Sunucuda tür süzgeci belgelenmemiş: çipler yerel süzer.
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
          if (_archived)
            BuHeader(title: 'Arşiv', onBack: () => _setArchiveView(false))
          else
            BuHeader(
              title: 'Sohbet',
              actions: [BuIconButton(icon: LucideIcons.plus, filled: true, tooltip: 'Yeni sohbet', onTap: _openNew)],
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: BuSearchField(hint: 'Kişi veya grup ara', onChanged: (v) => setState(() => _query = v)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: SizedBox(
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
            ),
          ),
          Expanded(child: _body(t)),
        ],
      ),
    );
  }

  Widget _body(BuTokens t) {
    if (_loading) return const _SkeletonList();
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

  Widget _archiveEntry(BuTokens t) {
    return InkWell(
      onTap: () => _setArchiveView(true),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(LucideIcons.archive, size: 18, color: t.mut),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Arşiv', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.mut)),
            ),
            Icon(LucideIcons.chevronRight, size: 18, color: t.mut),
          ],
        ),
      ),
    );
  }

  Widget _empty(BuTokens t) {
    final searching = _query.trim().isNotEmpty || _filter != 0;
    final text = _archived
        ? 'Arşivde sohbet yok'
        : (_items.isNotEmpty && searching)
            ? 'Eşleşen sohbet bulunamadı'
            : 'Henüz sohbetiniz yok';
    return ListView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, kNavInset),
      children: [
        if (!_archived) _archiveEntry(t),
        const SizedBox(height: 32),
        EmptyView(icon: LucideIcons.messageCircle, text: text),
        if (_items.isEmpty && !_archived)
          Center(
            child: BuButton(label: 'Yeni sohbet', icon: LucideIcons.plus, compact: true, onPressed: _openNew),
          ),
      ],
    );
  }

  Widget _list(List<Map<String, dynamic>> list) {
    final t = context.bu;
    final head = _archived ? 0 : 1;
    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, kNavInset),
      itemCount: head + list.length + (_loadingMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i < head) return _archiveEntry(t);
        final k = i - head;
        if (k >= list.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
          );
        }
        final c = list[k];
        return Dismissible(
          key: ValueKey('conv-${c['id']}'),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) async {
            await _toggleArchive(c);
            return false; // satırı _toggleArchive kendisi kaldırır
          },
          background: Container(
            alignment: AlignmentDirectional.centerEnd,
            padding: const EdgeInsetsDirectional.only(end: 20),
            color: t.pr,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.archive, color: t.onPr),
                Text(_archived ? 'Çıkar' : 'Arşivle',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: t.onPr)),
              ],
            ),
          ),
          child: _ConversationRow(
            title: _title(c),
            conversation: c,
            onTap: () => _openChat(c),
            onLongPress: () => _showActions(c),
          ),
        );
      },
    );
  }
}

/// İlk yükleme iskeleti: animasyonsuz, hafif kartlar.
class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(6)),
        );
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      itemCount: 7,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(width: 52, height: 52, decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [bar(140, 14), const SizedBox(height: 8), bar(220, 12)],
              ),
            ),
            bar(28, 10),
          ],
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.title,
    required this.conversation,
    required this.onTap,
    required this.onLongPress,
  });

  final String title;
  final Map<String, dynamic> conversation;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

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

    return Material(
      color: t.bg,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
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
