import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/cache/message_cache.dart';
import '../../core/locale_controller.dart';
import '../../core/realtime/chat_realtime.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'chat_detail_page.dart';
import 'chat_info_parts.dart' show ChatConfirmLayout, showChatInfoConfirm;
import 'chat_media.dart';
import 'chat_sheet_parts.dart' show showChatMuteSheet;
import 'chatlist_widgets.dart';
import 'conversation_actions.dart';
import 'message_bubble.dart' show OnceBadge;
import 'message_placeholder.dart';
import 'new_chat_page.dart';

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
  final _search = TextEditingController();
  final _items = <Map<String, dynamic>>[];
  /// Tek soket kuralı (T-095): oturumun paylaşılan [Session.realtime]'ı (kabuk başlatır/durdurur; bu sekme yalnız abone
  /// olur, dispose etmez). Oturumda yoksa yedek olarak kendi örneği.
  late final ChatRealtime _rt;
  ChatRealtime? _ownRt;
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
    ChatlistAvatar.bindSession(widget.session);
    // Kulüpten ayrılma/silme gibi işlemler listeyi geçersiz kılar.
    widget.session.badges.conversationsDirty.addListener(_scheduleReload);
    _rt = widget.session.realtime ?? (_ownRt = ChatRealtime(widget.session));
    if (widget.connectRealtime && _ownRt != null) _rt.start();
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
    _ownRt?.dispose();
    _scroll.dispose();
    _search.dispose();
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

  /// Liste önce cihazdaki kayıttan (anlık), sonra sunucudan yüklenir (stale-while-revalidate). Sunucuya
  /// ulaşılamazsa kayıtlı liste SESSİZCE kalır; hata ekranı yalnız gösterilecek hiçbir şey yokken çıkar.
  Future<void> _load({bool silent = false}) async {
    final my = ++_seq;
    if (!silent && _items.isEmpty && !_archived) {
      final cached = await MessageCache.instance.readConversations();
      if (!mounted || my != _seq) return;
      if (cached.isNotEmpty && _items.isEmpty) {
        setState(() {
          _items.addAll(cached);
          _loading = false;
        });
      }
    }
    if (!silent && _items.isEmpty) setState(() => _loading = true);
    try {
      final res = await widget.session.api.get(_path, force: silent);
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
      _persistList();
      _refreshBadge();
    } catch (e) {
      if (!mounted || my != _seq) return;
      setState(() {
        // Eldeki (kayıtlı) liste korunur; yalnızca boşken hata ekranı gösterilir.
        _error = _items.isEmpty ? e : null;
        _loading = false;
      });
    }
  }

  /// İlk 50 sohbet cihaza yazılır (yazma MessageCache'te geciktirilir/toplanır); arşiv görünümü yazılmaz.
  void _persistList() {
    if (_archived) return;
    MessageCache.instance.saveConversations(_items);
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
    _persistList();
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
    BuToast.show(context, text);
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
      if (!mounted) return;
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
    final l = context.l10n;
    // Silme onayı (referans 22-2): üstte simge, ortalı başlık ve gövde, yan yana iki düğme.
    final ok = await showChatInfoConfirm(
      context,
      icon: LucideIcons.trash2,
      title: l.chatInfoDeleteConvTitle,
      body: group ? l.chatInfoDeleteConvGroup : l.chatInfoDeleteConvDirect,
      confirmLabel: l.chatInfoDelete,
      confirmIcon: LucideIcons.trash2,
      cancelLabel: l.chatInfoCancel,
      layout: ChatConfirmLayout.iconAbove,
    );
    if (!ok) return;
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
      unawaited(MessageCache.instance.removeConversation(id));
      _persistList();
      _syncBadgeLocal();
      _scheduleBadge();
    } catch (e) {
      if (!mounted) return;
      setState(() => _removing.remove(id)); // geri koy
      _toast(errorText(e));
    }
  }

  Future<void> _showActions(Map<String, dynamic> c) async {
    final muted = c['muted'] == true || c['mutedForever'] == true;
    final type = _type(c);
    final peer = c['peer'];
    final choice = await showConversationMenu(
      context,
      title: _title(context, c),
      avatarUrl: type == 'DIRECT' ? (peer is Map ? peer['avatarUrl'] as String? : null) : c['avatarUrl'] as String?,
      group: type != 'DIRECT',
      muted: muted,
      archived: _archived,
      canDelete: type != 'CLUB' && type != 'EVENT',
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'mute':
        final pick = await showChatMuteSheet(context, chatName: _title(context, c));
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
    final tx = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: t.bg,
      body: RefreshIndicator(
        color: t.pr,
        onRefresh: () => _load(silent: true),
        // Satırların kademeli girişi: her indeks yalnız bir kez oynar (kaydırma/yenileme/süzme tekrar oynatmaz).
        child: BuStaggerScope(
          child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Başlık kaydıkça gizlenir; arama + süzgeç çipleri aşağıda sabit kalır.
            SliverToBoxAdapter(
              child: _archived
                  ? BuHeader(title: context.l10n.chatMiscArchive, onBack: () => _setArchiveView(false))
                  : Padding(
                      // Üst güvenli alan (durum çubuğu) eklenir: Android 15 edge-to-edge'de başlık saat/simgelere binmesin (BuHeader ile aynı 12 dp).
                      padding: EdgeInsetsDirectional.fromSTEB(20, MediaQuery.paddingOf(context).top + 12, 20, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(context.l10n.chatMiscChat,
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.headlineMedium!.copyWith(color: t.ink)),
                            ),
                          ),
                          ChatlistRoundButton(
                              icon: LucideIcons.archive, tooltip: context.l10n.chatMiscArchive, onTap: () => _setArchiveView(true)),
                          const SizedBox(width: 4),
                          // Boş durumda birincil eylem sayfadaki tek düğmedir; başlıktaki "+" sakinleşir.
                          ChatlistNewButton(
                              tooltip: context.l10n.chatMiscNewChat, onTap: _openNew, quiet: !_loading && _error == null && _visible.isEmpty),
                        ],
                      ),
                    ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _PinnedFilterDelegate(
                filters: _filterLabels(context),
                selected: _filter,
                controller: _search,
                showChips: !_archived,
                showSearch: !_archived,
                onQuery: (v) => setState(() => _query = v),
                onSelect: (i) => setState(() => _filter = i),
              ),
            ),
            ..._bodySlivers(t),
          ],
        ),
        ),
      ),
    );
  }

  List<Widget> _bodySlivers(BuTokens t) {
    final l = context.l10n;
    if (_loading) {
      return [const SliverToBoxAdapter(child: _SkeletonList())];
    }
    if (_error != null && _items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: true,
          child: BuErrorState(
            error: _error,
            title: l.p06LoadFailedTitle,
            message: l.p06LoadFailedBody,
            onRetry: _load,
          ),
        ),
      ];
    }
    final list = _visible;
    if (list.isEmpty) return [_empty(t)];
    return [_list(list)];
  }

  void _resetSearch() {
    _search.clear();
    setState(() {
      _query = '';
      _filter = 0;
    });
  }

  Widget _empty(BuTokens t) {
    final l = context.l10n;
    final searching = _query.trim().isNotEmpty || _filter != 0;
    final Widget view;
    if (_archived) {
      view = BuEmptyState(
        illustration: BuIllustration.box,
        title: l.chatMiscEmptyArchive,
        actionLabel: l.p06BackToChats,
        onAction: () => _setArchiveView(false),
      );
    } else if (_items.isNotEmpty && searching) {
      view = BuEmptyState(
        illustration: BuIllustration.search,
        title: l.chatMiscEmptyNoMatch,
        actionLabel: l.p06ResetSearch,
        onAction: _resetSearch,
      );
    } else {
      view = BuEmptyState(
        illustration: BuIllustration.message,
        title: l.chatMiscEmptyNone,
        actionLabel: l.chatMiscNewChat,
        onAction: _openNew,
      );
    }
    return SliverFillRemaining(
      hasScrollBody: true,
      child: Padding(padding: const EdgeInsets.only(bottom: kNavInset), child: view),
    );
  }

  Widget _list(List<Map<String, dynamic>> list) {
    final t = context.bu;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, kNavInset),
      sliver: SliverList.builder(
        itemCount: list.length + (_loadingMore ? 1 : 0),
        itemBuilder: (_, k) {
          if (k >= list.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
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
            // Kaydırma eylemi sakin: nötr zemin, tek simge + kısa etiket (kırmızı/lacivert dolgu yok).
            background: Container(
              alignment: AlignmentDirectional.centerEnd,
              padding: const EdgeInsetsDirectional.only(end: 20),
              decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bMd),
              child: SizedBox(
                width: 88,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_archived ? LucideIcons.archiveRestore : LucideIcons.archive, size: 22, color: t.ink),
                    const SizedBox(height: 4),
                    Text(_archived ? context.l10n.chatMiscUnarchiveAction : context.l10n.chatMiscArchiveAction,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium!.copyWith(color: t.mut, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            child: Builder(
              builder: (rowCtx) => _ConversationRow(
                title: _title(context, c),
                conversation: c,
                myId: widget.session.userId,
                onTap: () => _openChat(c),
                onLongPress: () {
                  HapticFeedback.selectionClick();
                  _showActions(c);
                },
              ),
            ),
          );
          final removing = _removing.contains((c['id'] as num?)?.toInt());
          return BuStaggerItem(
            key: ValueKey('stagger-${c['id']}'),
            index: k,
            child: ClipRect(
              key: ValueKey('wrap-${c['id']}'),
              child: IgnorePointer(
                ignoring: removing,
                child: AnimatedAlign(
                  alignment: Alignment.topCenter,
                  heightFactor: removing ? 0 : 1,
                  duration: BuMotion.of(context, const Duration(milliseconds: 220)),
                  curve: Curves.easeOutCubic,
                  child: row,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Sabit (pinned) arama alanı + süzgeç çipleri.
class _PinnedFilterDelegate extends SliverPersistentHeaderDelegate {
  _PinnedFilterDelegate({
    required this.filters,
    required this.selected,
    required this.controller,
    required this.showChips,
    required this.showSearch,
    required this.onQuery,
    required this.onSelect,
  });

  final List<String> filters;
  final int selected;
  final TextEditingController controller;
  final bool showChips;
  final bool showSearch;
  final ValueChanged<String> onQuery;
  final ValueChanged<int> onSelect;

  double get _height => !showSearch ? 0 : (showChips ? 12 + BuSize.search + 4 + 52 + 4 : 12 + BuSize.search + 8);

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(covariant _PinnedFilterDelegate old) =>
      old.selected != selected || old.filters != filters || old.showChips != showChips || old.showSearch != showSearch;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    if (!showSearch) return const SizedBox.shrink();
    final t = context.bu;
    return Container(
      height: _height,
      color: t.bg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 0),
            child: ChatlistSearch(hint: context.l10n.chatlistSearchHint, controller: controller, onChanged: onQuery),
          ),
          if (showChips)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: KeyedSubtree(key: const ValueKey('chat-segment'), child: BuChipRow(labels: filters, selected: selected, onSelected: onSelect)),
            ),
        ],
      ),
    );
  }
}

/// İlk yükleme iskeleti: kart içinde 7 satır (daire/kare avatar + iki çubuk + zaman).
class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    // Satır iskeleti gerçek satırla aynı: sayfa zemininde, kartsız.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: ExcludeSemantics(
        child: BuSkeletonScope(
          child: Column(
            children: [
              for (var i = 0; i < 7; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(children: [
                    const BuSkeleton(width: 52, height: 52, radius: 18),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        BuSkeleton.line(width: 130 + (i % 3) * 20, height: 14),
                        const SizedBox(height: 10),
                        BuSkeleton.line(width: 210 - (i % 2) * 40, height: 12),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    const BuSkeleton(width: 30, height: 10),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sohbet satırı (referans 18): avatar, ad (+ Kulüp/Etkinlik etiketi), son mesaj, saat, rozet.
class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.title,
    required this.conversation,
    required this.onTap,
    required this.onLongPress,
    this.myId,
  });

  final String title;
  final Map<String, dynamic> conversation;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final int? myId;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final type = (conversation['type'] as String?)?.toUpperCase() ?? 'DIRECT';
    final peer = conversation['peer'];
    final lastMsg = conversation['lastMessage'];
    final unread = (conversation['unreadCount'] as num?)?.toInt() ?? 0;
    final muted = conversation['muted'] == true || conversation['mutedForever'] == true;
    final hot = unread > 0 && !muted;

    final tag = switch (type) {
      'CLUB' => l.chatMiscTagClub,
      'EVENT' => l.chatMiscTagEvent,
      _ => null
    };
    final isDirect = type == 'DIRECT';
    final avatarUrl = isDirect ? (peer is Map ? peer['avatarUrl'] as String? : null) : conversation['avatarUrl'] as String?;
    // `online` yalnız sunucu alanı gelirse çizilir (BACKEND-ISTEK: ConversationView.peer.online).
    final online = isDirect && peer is Map && peer['online'] == true;

    String preview = '';
    IconData? kindIcon;
    var once = false;
    var removedMsg = false;
    String? when;
    String? status;
    String? prefix;
    if (lastMsg is Map) {
      final s = lastMsg['status'];
      if (s is String) status = s.toUpperCase();
      final removed = lastMsg['removed'] == true || lastMsg['deleted'] == true;
      if (removed) {
        removedMsg = true;
        preview = isAdminRemovedText(lastMsg['text'] as String?) ? l.chatAdminRemovedMsg : l.chatMiscMessageDeleted;
      } else {
        final p = _preview(context, lastMsg);
        preview = p.$1;
        kindIcon = p.$2;
        once = p.$3;
        final sid = (lastMsg['senderId'] as num?)?.toInt();
        if (myId != null && sid == myId) {
          prefix = l.chatDetailYou;
        } else if (!isDirect && lastMsg['senderName'] is String && (lastMsg['senderName'] as String).isNotEmpty) {
          // Grup/kulüp/etkinlik: gönderen adı (sunucu alanı gelirse).
          prefix = (lastMsg['senderName'] as String).split(' ').first;
        }
      }
      when = lastMsg['createdAt'] as String?;
    }

    final tick = switch (status) {
      'SENT' => (LucideIcons.check, t.mut),
      'DELIVERED' => (LucideIcons.checkCheck, t.mut),
      'READ' => (LucideIcons.checkCheck, t.mut), // okundu: çift tik yeter; marka vurgusu yalnız okunmamış rozetinde
      _ => null,
    };
    final bodyColor = hot ? t.ink : t.mut;

    // Basılınca hafifçe küçülür (bitişik satırlar arasında boşluk açılmasın diye çok hafif: .99).
    return BuPressable(
      scale: .99,
      child: Semantics(
      container: true,
      // Kartsız satır: sayfa zemininde, ayırıcı çizgi yok (boşlukla ayrılır); basılınca yumuşak dalga.
      child: Material(
        color: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BuRadius.bMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(0, 12, 0, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ChatlistAvatar(
                      name: title,
                      url: avatarUrl,
                      group: !isDirect,
                      online: online,
                      // Tür adı yanındaki nötr etiketle (ya da ekran okuyucuyla) söylenir; avatarda ikinci işaret yok.
                      heroTag: 'chat-avatar-${conversation['id']}',
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: LayoutBuilder(builder: (context, box) {
                        // Dar ekran / büyük yazıda tür çipi başlığı 3 harfe sıkıştırır (T-114): çip kalkar (avatar
                        // rozeti türü zaten gösterir; ekran okuyucuya başlıkla birlikte okunur), her tür başlık 2 satıra açılır.
                        final narrow = box.maxWidth < 250 || MediaQuery.textScalerOf(context).scale(16) > 19;
                        final showTag = tag != null && !narrow;
                        return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Row(children: [
                                  Flexible(
                                    child: Text(title,
                                        maxLines: narrow ? 2 : 1,
                                        overflow: TextOverflow.ellipsis,
                                        semanticsLabel: narrow && tag != null ? '$title, $tag' : null,
                                        style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
                                  ),
                                  if (showTag) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bPill), // nötr yüzey tonu (renk vurgusu yok)
                                      child: Text(tag, maxLines: 1, style: tx.labelSmall!.copyWith(color: t.mut, fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ]),
                              ),
                              const SizedBox(width: 8),
                              if (muted) ...[
                                Icon(LucideIcons.bellOff, size: 13, color: t.mut),
                                const SizedBox(width: 4),
                              ],
                              Text(_stamp(context, when),
                                  style: tx.labelMedium!.copyWith(
                                      color: t.mut, // zaman metni hep nötr; vurgu yalnız okunmamış rozetinde
                                      fontWeight: FontWeight.w400,
                                      fontFeatures: const [FontFeature.tabularFigures()])),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(children: [
                            Expanded(
                              child: Row(children: [
                                if (tick != null) ...[
                                  Icon(tick.$1, size: 16, color: tick.$2),
                                  const SizedBox(width: 6),
                                ],
                                if (removedMsg) ...[
                                  Icon(LucideIcons.ban, size: 15, color: t.mut),
                                  const SizedBox(width: 6),
                                ] else if (once) ...[
                                  OnceBadge(color: t.pr, dashed: true, size: 18),
                                  const SizedBox(width: 6),
                                ] else if (kindIcon != null) ...[
                                  Icon(kindIcon, size: 16, color: bodyColor),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(children: [
                                      if (prefix != null) TextSpan(text: '$prefix: ', style: tx.bodyMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w500)),
                                      TextSpan(text: preview),
                                    ]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: tx.bodyMedium!.copyWith(
                                        color: bodyColor, // okunmamış: yalnız renk koyulaşır (kalın yazı yok)
                                        fontWeight: FontWeight.w400,
                                        fontStyle: removedMsg ? FontStyle.italic : FontStyle.normal),
                                  ),
                                ),
                              ]),
                            ),
                            if (unread > 0) ...[
                              const SizedBox(width: 8),
                              // Sayı değişince rozet bir kez "pop" yapar (ilk çizimde oynamaz).
                              BuPop(
                                trigger: unread,
                                child: Container(
                                  constraints: const BoxConstraints(minWidth: 22),
                                  height: 22,
                                  padding: const EdgeInsets.symmetric(horizontal: 7),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(color: muted ? t.sf2 : t.pr, borderRadius: BorderRadius.circular(11)),
                                  child: Text(unread > 99 ? '99+' : '$unread',
                                      style: tx.labelSmall!.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: muted ? t.mut : t.onPr,
                                          fontFeatures: const [FontFeature.tabularFigures()])),
                                ),
                              ),
                            ],
                          ]),
                        ],
                      );
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  /// (metin, ikon, tek gösterimlik mi): metin yoksa ekten türetilir (fotoğraf/video + süre).
  static (String, IconData?, bool) _preview(BuildContext context, Map last) {
    final l = context.l10n;
    // Engelli gönderen / çözülemeyen mesaj: sunucunun Türkçe sabit metni yerine uygulama dilinde yer tutucu.
    final byKind = placeholderKindText(context, last['placeholderKind']);
    if (byKind != null) return (byKind, null, false);
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
        final label = ms is num && ms > 0 ? '${l.chatMiscVideo} ${formatMediaDuration(ms.toInt())}' : l.chatMiscVideo;
        return (label, LucideIcons.video, false);
      }
      return (l.chatMiscPhoto, LucideIcons.camera, false);
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
