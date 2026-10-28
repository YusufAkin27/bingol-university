import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale_controller.dart';
import '../../core/realtime/chat_realtime.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'chat_detail_page.dart';
import 'chat_media.dart';
import 'chatlist_widgets.dart';
import 'conversation_actions.dart';
import 'message_bubble.dart' show OnceBadge;
import 'new_chat_page.dart';
import '../../core/typography.dart';

/// Sohbet sekmesi: konuşma listesi (birebir, grup, kulüp, etkinlik).
/// Liste STOMP akışıyla yerinde güncellenir; bağlantı yoksa çekerek yenileme geçerlidir.
class ChatTab extends StatefulWidget {
  const ChatTab(
      {super.key,
      required this.session,
      @visibleForTesting this.connectRealtime = true});

  final Session session;

  /// Testlerde false: gerçek WebSocket bağlantısı kurulmaz.
  final bool connectRealtime;

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  List<String> _filterLabels(BuildContext context) {
    final l = context.l10n;
    return [
      l.chatMiscFilterAll,
      l.chatMiscFilterPeople,
      l.chatMiscFilterClubs,
      l.chatMiscFilterEvents
    ];
  }

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
  final _removing = <int>{};

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // Kulüpten ayrılma/silme gibi işlemler listeyi geçersiz kılar.
    widget.session.badges.conversationsDirty.addListener(_scheduleReload);
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
    widget.session.badges.conversationsDirty.removeListener(_scheduleReload);
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
    if (_cursor != null &&
        !_loadingMore &&
        !_loading &&
        _scroll.position.extentAfter < 300) {
      _loadMore();
    }
  }

  String get _path =>
      '/conversations?size=30${_archived ? '&archived=true' : ''}';

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
      final total = res is Map
          ? res['total']
          : null; // UnreadSummary: total (sessiz olmayanlar)
      if (total is num && mounted) {
        widget.session.badges.chat.value = total.toInt();
      }
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
    if (!mine) {
      row['unreadCount'] = ((row['unreadCount'] as num?)?.toInt() ?? 0) + 1;
    }
    setState(() {
      _items
        ..removeAt(i)
        ..insert(0, row);
    });
    _scheduleBadge();
  }

  void _onRead(ReadReceipt r) {
    if (!mounted || r.userId != widget.session.userId) return;
    final i = _items
        .indexWhere((c) => (c['id'] as num?)?.toInt() == r.conversationId);
    if (i < 0) return;
    setState(() => _items[i] = {..._items[i], 'unreadCount': 0});
    _scheduleBadge();
  }

  // ---- gezinme ----

  Future<void> _openNew() async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => NewChatPage(session: widget.session)));
    if (mounted) _load(silent: true);
  }

  Future<void> _openChat(Map<String, dynamic> c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              ChatDetailPage(session: widget.session, conversation: c)),
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

  /// Satırı iyimser günceller; hata olursa eski haline döndürür.
  Map<String, dynamic>? _patchRow(int id, Map<String, dynamic> patch) {
    final i = _items.indexWhere((c) => c['id'] == id);
    if (i < 0 || !mounted) return null;
    final old = _items[i];
    setState(() => _items[i] = {...old, ...patch});
    return old;
  }

  void _restoreRow(int id, Map<String, dynamic>? old) {
    if (old == null || !mounted) return;
    final i = _items.indexWhere((c) => c['id'] == id);
    if (i >= 0) setState(() => _items[i] = old);
  }

  Future<void> _mute(Map<String, dynamic> c,
      {int? minutes, bool forever = false}) async {
    final id = (c['id'] as num).toInt();
    final old = _patchRow(id, {'muted': true, 'mutedForever': forever});
    try {
      final res = await widget.session.api.put(
        '/conversations/$id/mute',
        forever ? {'forever': true} : {'durationMinutes': minutes},
      );
      if (res is Map && res.isNotEmpty) {
        _replaceRow({...Map<String, dynamic>.from(res), 'muted': true});
      }
      _scheduleBadge();
    } catch (e) {
      _restoreRow(id, old);
      _toast(errorText(e));
    }
  }

  Future<void> _unmute(Map<String, dynamic> c) async {
    final id = (c['id'] as num).toInt();
    final old = _patchRow(
        id, {'muted': false, 'mutedForever': false, 'mutedUntil': null});
    try {
      await widget.session.api.delete('/conversations/$id/mute');
      _scheduleBadge();
    } catch (e) {
      _restoreRow(id, old);
      _toast(errorText(e));
    }
  }

  Future<void> _toggleArchive(Map<String, dynamic> c) async {
    final archive = !_archived;
    final i = _items.indexWhere((x) => x['id'] == c['id']);
    if (i < 0) return;
    final row = _items[i];
    setState(() => _items.removeAt(i)); // iyimser: satır hemen kalkar
    try {
      if (archive) {
        await widget.session.api
            .put('/conversations/${c['id']}/archive', {'keepArchived': false});
      } else {
        await widget.session.api.delete('/conversations/${c['id']}/archive');
      }
      _scheduleBadge();
      _toast(archive
          ? context.l10n.chatMiscArchived
          : context.l10n.chatMiscUnarchived);
    } catch (e) {
      if (mounted) {
        setState(() => _items.insert(i.clamp(0, _items.length), row));
      }
      _toast(errorText(e));
    }
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    final id = (c['id'] as num).toInt();
    final group = _type(c) == 'GROUP';
    if (!await confirmDeleteConversation(context, group: group)) return;
    if (!mounted) return;
    setState(() => _removing.add(id)); // satır animasyonla daralır
    try {
      await widget.session.api.delete('/conversations/$id');
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 240));
      if (!mounted) return;
      setState(() {
        _items.removeWhere((x) => x['id'] == id);
        _removing.remove(id);
      });
      _syncBadgeLocal();
      _scheduleBadge();
    } catch (e) {
      if (!mounted) return;
      setState(() => _removing.remove(id)); // geri koy
      _toast(errorText(e));
    }
  }

  Future<void> _showActions(Map<String, dynamic> c, BuildContext rowCtx) async {
    final box = rowCtx.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    final t = context.bu;
    final muted = c['muted'] == true || c['mutedForever'] == true;
    final type = _type(c);
    final choice = await showConversationMenu(
      context,
      anchor: anchor,
      preview: ColoredBox(
        color: t.bg,
        child: _ConversationRow(
            title: _title(context, c),
            conversation: c,
            onTap: () {},
            onLongPress: () {}),
      ),
      muted: muted,
      archived: _archived,
      canDelete: type != 'CLUB' && type != 'EVENT',
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'mute':
        final pick = await pickMuteDuration(context);
        if (pick == null || !mounted) return;
        if (pick == 'forever') {
          await _mute(c, forever: true);
        } else {
          await _mute(c, minutes: int.parse(pick));
        }
      case 'unmute':
        await _unmute(c);
      case 'archive' || 'unarchive':
        await _toggleArchive(c);
      case 'delete':
        await _delete(c);
    }
  }

  static String _type(Map<String, dynamic> c) =>
      (c['type'] as String?)?.toUpperCase() ?? 'DIRECT';

  static String _title(BuildContext context, Map<String, dynamic> c) {
    final type = _type(c);
    final peer = c['peer'];
    if (type == 'DIRECT' &&
        peer is Map &&
        (peer['displayName'] as String?)?.isNotEmpty == true) {
      return peer['displayName'] as String;
    }
    final t = c['title'] as String?;
    return (t != null && t.isNotEmpty) ? t : context.l10n.chatMiscChat;
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
      return ok && (q.isEmpty || _title(context, c).toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: RefreshIndicator(
        color: t.pr,
        onRefresh: () => _load(silent: true),
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Başlık kaydıkça gizlenir; arama + segment aşağıda sabit kalır.
            SliverToBoxAdapter(
              child: _archived
                  ? BuHeader(
                      title: context.l10n.chatMiscArchive,
                      onBack: () => _setArchiveView(false))
                  : Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(context.l10n.chatMiscChat,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: BuType.display.copyWith(
                                      color: t.ink,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -.5)),
                            ),
                          ),
                          ChatlistNewButton(
                              tooltip: context.l10n.chatMiscNewChat,
                              onTap: _openNew),
                        ],
                      ),
                    ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _PinnedFilterDelegate(
                filters: _filterLabels(context),
                selected: _filter,
                onQuery: (v) => setState(() => _query = v),
                onSelect: (i) => setState(() => _filter = i),
              ),
            ),
            ..._bodySlivers(t),
          ],
        ),
      ),
    );
  }

  List<Widget> _bodySlivers(BuTokens t) {
    if (_loading) {
      return [const SliverToBoxAdapter(child: _SkeletonList())];
    }
    if (_error != null && _items.isEmpty) {
      return [
        // hasScrollBody:false alt çocuğun doğal boyutunu ister; ErrorView sınırlı yüksekliğe ihtiyaç duyar.
        SliverFillRemaining(
            hasScrollBody: true,
            child: ErrorView(error: _error!, onRetry: _load)),
      ];
    }
    final list = _visible;
    if (list.isEmpty) return [_empty(t)];
    return [_list(list)];
  }

  Widget _archiveEntry(BuTokens t) {
    return InkWell(
      onTap: () => _setArchiveView(true),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(LucideIcons.archive, size: 16, color: t.mut),
            const SizedBox(width: 12),
            Expanded(
              child: Text(context.l10n.chatMiscArchive,
                  style: BuType.bodyStrong.copyWith(color: t.mut)),
            ),
            Icon(buDirIcon(context, LucideIcons.chevronRight), size: 16, color: t.mut),
          ],
        ),
      ),
    );
  }

  Widget _empty(BuTokens t) {
    final searching = _query.trim().isNotEmpty || _filter != 0;
    final text = _archived
        ? context.l10n.chatMiscEmptyArchive
        : (_items.isNotEmpty && searching)
            ? context.l10n.chatMiscEmptyNoMatch
            : context.l10n.chatMiscEmptyNone;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, kNavInset),
      sliver: SliverToBoxAdapter(
        child: Column(
          children: [
            if (!_archived) _archiveEntry(t),
            const SizedBox(height: 32),
            EmptyView(icon: LucideIcons.messageCircle, text: text),
            if (_items.isEmpty && !_archived)
              Center(
                child: BuButton(
                    label: context.l10n.chatMiscNewChat,
                    icon: LucideIcons.plus,
                    compact: true,
                    onPressed: _openNew),
              ),
          ],
        ),
      ),
    );
  }

  Widget _list(List<Map<String, dynamic>> list) {
    final t = context.bu;
    final head = _archived ? 0 : 1;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, kNavInset),
      sliver: SliverList.builder(
        itemCount: head + list.length + (_loadingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i < head) return _archiveEntry(t);
          final k = i - head;
          if (k >= list.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4))),
            );
          }
          final c = list[k];
          final row = Dismissible(
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
                  Text(
                      _archived
                          ? context.l10n.chatMiscUnarchiveAction
                          : context.l10n.chatMiscArchiveAction,
                      style: BuType.micro.copyWith(color: t.onPr)),
                ],
              ),
            ),
            child: Builder(
              builder: (rowCtx) => _ConversationRow(
                title: _title(context, c),
                conversation: c,
                onTap: () => _openChat(c),
                onLongPress: () {
                  HapticFeedback.selectionClick();
                  _showActions(c, rowCtx);
                },
              ),
            ),
          );
          final removing = _removing.contains((c['id'] as num?)?.toInt());
          return ClipRect(
            key: ValueKey('wrap-${c['id']}'),
            child: IgnorePointer(
              ignoring: removing,
              child: AnimatedAlign(
                alignment: Alignment.topCenter,
                heightFactor: removing ? 0 : 1,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: row,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Sabit (pinned) segment + arama alanı.
class _PinnedFilterDelegate extends SliverPersistentHeaderDelegate {
  _PinnedFilterDelegate({
    required this.filters,
    required this.selected,
    required this.onQuery,
    required this.onSelect,
  });

  final List<String> filters;
  final int selected;
  final ValueChanged<String> onQuery;
  final ValueChanged<int> onSelect;

  static const double _height = 128;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(covariant _PinnedFilterDelegate old) =>
      old.selected != selected || old.filters != filters;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final t = context.bu;
    return Container(
      height: _height,
      color: t.bg,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Column(
        children: [
          ChatlistSegment(
              labels: filters, selected: selected, onSelect: onSelect),
          const SizedBox(height: 12),
          ChatlistSearch(hint: context.l10n.chatlistSearchHint, onChanged: onQuery),
        ],
      ),
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
          decoration: BoxDecoration(
              color: t.sf2, borderRadius: BorderRadius.circular(6)),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        children: List.generate(7, (_) => _skeletonRow(t, bar)),
      ),
    );
  }

  Widget _skeletonRow(BuTokens t, Widget Function(double, double) bar) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle)),
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
    final l = context.l10n;
    final type = (conversation['type'] as String?)?.toUpperCase() ?? 'DIRECT';
    final peer = conversation['peer'];
    final last = conversation['lastMessage'];
    final unread = (conversation['unreadCount'] as num?)?.toInt() ?? 0;
    final muted = conversation['muted'] == true;
    final hot = unread > 0 && !muted;

    final tag = switch (type) {
      'CLUB' => l.chatMiscTagClub,
      'EVENT' => l.chatMiscTagEvent,
      _ => null
    };
    final isDirect = type == 'DIRECT';
    final avatarUrl = isDirect
        ? (peer is Map ? peer['avatarUrl'] as String? : null)
        : conversation['avatarUrl'] as String?;

    String preview = '';
    IconData? kindIcon;
    var once = false;
    String? when;
    String? status;
    if (last is Map) {
      final s = last['status'];
      if (s is String) status = s.toUpperCase();
      final removed = last['removed'] == true || last['deleted'] == true;
      if (removed) {
        preview = l.chatMiscMessageDeleted;
      } else {
        final p = _preview(context, last);
        preview = p.$1;
        kindIcon = p.$2;
        once = p.$3;
      }
      when = last['createdAt'] as String?;
    }

    final tick = switch (status) {
      'SENT' => (LucideIcons.check, t.mut),
      'DELIVERED' => (LucideIcons.checkCheck, t.mut),
      'READ' => (LucideIcons.checkCheck, t.ok),
      _ => null,
    };
    final bodyColor = hot ? t.ink : t.mut;

    return Material(
      color: t.bg,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              ChatlistAvatar(name: title, url: avatarUrl, group: !isDirect),
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
                              style: BuType.bodyStrong.copyWith(
                                  color: t.ink,
                                  fontSize: 15,
                                  fontWeight:
                                      hot ? FontWeight.w800 : FontWeight.w700)),
                        ),
                        if (tag != null) ...[
                          const SizedBox(width: 6),
                          BuBadge(tag, soft: true)
                        ],
                        if (muted) ...[
                          const SizedBox(width: 6),
                          Icon(LucideIcons.bellOff, size: 12, color: t.mut),
                        ],
                        const Spacer(),
                        const SizedBox(width: 8),
                        Text(_stamp(context, when),
                            style: BuType.micro.copyWith(
                                fontSize: 12,
                                fontWeight:
                                    hot ? FontWeight.w600 : FontWeight.w400,
                                color: hot ? t.pr : t.mut)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(children: [
                      Expanded(
                        child: Row(children: [
                          if (tick != null) ...[
                            Icon(tick.$1, size: 16, color: tick.$2),
                            const SizedBox(width: 6),
                          ],
                          if (once) ...[
                            OnceBadge(color: bodyColor, size: 16),
                            const SizedBox(width: 6),
                          ] else if (kindIcon != null) ...[
                            Icon(kindIcon, size: 16, color: bodyColor),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: BuType.body
                                    .copyWith(fontSize: 14, color: bodyColor)),
                          ),
                        ]),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          constraints: const BoxConstraints(minWidth: 22),
                          height: 22,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: muted ? t.mut : t.pr,
                              borderRadius: BorderRadius.circular(11)),
                          child: Text(unread > 99 ? '99+' : '$unread',
                              style: BuType.micro.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: muted ? t.bg : t.onPr)),
                        ),
                      ],
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// (metin, ikon, tek gösterimlik mi): metin yoksa ekten türetilir (fotoğraf/video + süre).
  static (String, IconData?, bool) _preview(BuildContext context, Map last) {
    final l = context.l10n;
    final text = (last['text'] as String?)?.trim() ?? '';
    if (text.isNotEmpty) {
      return (text.replaceAll(RegExp(r'\s+'), ' '), null, false);
    }
    final att = last['attachments'];
    if (att is List && att.isNotEmpty) {
      if (viewOnceAttachment(last) != null) {
        return (l.chatMiscOnceText, null, true);
      }
      final first = att.whereType<Map>().first;
      if (isVideoAttachment(first)) {
        final ms = first['durationMs'];
        final label = ms is num && ms > 0
            ? '${l.chatMiscVideo} ${formatMediaDuration(ms.toInt())}'
            : l.chatMiscVideo;
        return (label, LucideIcons.video, false);
      }
      return (l.chatMiscPhoto, LucideIcons.image, false);
    }
    return ('', null, false);
  }

  static String _stamp(BuildContext context, String? iso) {
    final l = context.l10n;
    final days = [
      l.chatMiscDayMon,
      l.chatMiscDayTue,
      l.chatMiscDayWed,
      l.chatMiscDayThu,
      l.chatMiscDayFri,
      l.chatMiscDaySat,
      l.chatMiscDaySun
    ];
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    String two(int n) => n.toString().padLeft(2, '0');
    if (diff <= 0) return '${two(d.hour)}:${two(d.minute)}';
    if (diff == 1) return l.chatMiscYesterday;
    if (diff < 7) return days[d.weekday - 1];
    return '${two(d.day)}.${two(d.month)}';
  }
}
