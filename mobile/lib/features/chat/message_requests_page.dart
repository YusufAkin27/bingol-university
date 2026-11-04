import '../../core/analytics.dart';
import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/requests_entry_row.dart';
import '../follow/follow_widgets.dart';
import 'chat_detail_page.dart';
import 'chatlist_widgets.dart';
import 'message_placeholder.dart';

/// Mesaj istekleri uçları (W2-D): ortak bağlamı olmayan göndericinin sohbeti alıcıda PENDING kalır.
/// `GET /conversations/requests` (imleç = konuşma kimliği), `.../requests/count`, `POST /{id}/accept`, `POST /{id}/decline`.
class MessageRequestsApi {
  MessageRequestsApi(this.session);

  final Session session;

  Future<({List<Map<String, dynamic>> items, int? next})> list({int? cursor, int size = 30}) async {
    final res = await session.api.get('/conversations/requests?size=$size${cursor == null ? '' : '&cursor=$cursor'}', force: true);
    final map = res is Map ? res : const {};
    final raw = map['items'];
    final next = map['nextCursor'];
    return (
      items: <Map<String, dynamic>>[
        if (raw is List)
          for (final e in raw)
            if (e is Map) Map<String, dynamic>.from(e),
      ],
      next: next is num ? next.toInt() : null,
    );
  }

  /// `{count}`; alınamazsa null.
  Future<int?> count() async {
    final r = await session.api.get('/conversations/requests/count', force: true);
    final c = r is Map ? r['count'] : null;
    return c is num ? c.toInt() : null;
  }

  Future<void> accept(int id) async {
    await session.api.post('/conversations/$id/accept');
  }

  Future<void> decline(int id) async {
    await session.api.post('/conversations/$id/decline');
  }
}

/// Sohbet listesinin üstündeki "Mesaj istekleri (n)" satırı. Sayıyı [count] verir (sohbet sekmesi yükler); 0 ise çizilmez.
class MessageRequestsEntry extends StatelessWidget {
  const MessageRequestsEntry({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: RequestsEntryRow(
        key: const ValueKey('message-requests-entry'),
        icon: BuIcons.inbox,
        label: context.l10n.frqMsgReqRow('$count'),
        onTap: onTap,
      ),
    );
  }
}

/// "Mesaj istekleri" ekranı: bekleyen (PENDING) birebir istekleri ve grup davetleri. Satıra dokunmak sohbeti okumaya açar
/// (okundu bilgisi gitmez; yanıt yazınca istek kendiliğinden kabul edilir). "Kabul et" listeye taşır, "Sil" gizler
/// (grup davetinde gruptan ayrılır).
class MessageRequestsPage extends StatefulWidget {
  const MessageRequestsPage({super.key, required this.session});

  final Session session;

  @override
  State<MessageRequestsPage> createState() => _MessageRequestsPageState();
}

class _MessageRequestsPageState extends State<MessageRequestsPage> {
  final _items = <Map<String, dynamic>>[];
  final _leaving = <int>{};
  final _scroll = ScrollController();
  int? _cursor;
  bool _loading = true;
  bool _more = false;
  Object? _error;
  int _gen = 0;

  MessageRequestsApi get _api => MessageRequestsApi(widget.session);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  static int _id(Map<String, dynamic> c) => (c['id'] as num?)?.toInt() ?? 0;

  Future<void> _load({bool silent = false}) async {
    final gen = ++_gen;
    if (!silent) setState(() => _loading = _items.isEmpty);
    try {
      final r = await _api.list();
      if (!mounted || gen != _gen) return;
      setState(() {
        _items
          ..clear()
          ..addAll(r.items);
        _leaving.clear();
        _cursor = r.next;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = _items.isEmpty ? e : null;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final cursor = _cursor;
    if (cursor == null || _more || _loading) return;
    setState(() => _more = true);
    try {
      final r = await _api.list(cursor: cursor);
      if (!mounted) return;
      setState(() {
        final seen = _items.map(_id).toSet();
        _items.addAll(r.items.where((c) => seen.add(_id(c))));
        _cursor = r.next;
        _more = false;
      });
    } catch (_) {
      if (mounted) setState(() => _more = false);
    }
  }

  static bool _isDirect(Map<String, dynamic> c) => ((c['type'] as String?) ?? 'DIRECT').toUpperCase() == 'DIRECT';

  /// Kabul/Sil: satır hemen kayar; hata olursa geri gelir. Başarıda sohbet listesi/rozet yenilenir.
  Future<void> _decide(Map<String, dynamic> c, {required bool accept}) async {
    final id = _id(c);
    if (id == 0 || _leaving.contains(id)) return;
    if (!accept && !_isDirect(c)) {
      // Grup daveti silinince gruptan ayrılınır ve davet eden bir daha ekleyemez: onay iste.
      final l = context.l10n;
      final ok = await BuConfirmSheet.show(
        context,
        title: l.frqMsgReqDeclineGroupTitle,
        message: l.frqMsgReqDeclineGroupBody,
        confirmLabel: l.frqMsgReqDeclineGroupConfirm,
        destructive: true,
        icon: BuIcons.logOut,
      );
      if (!ok || !mounted) return;
    }
    buHaptic(accept ? BuHaptic.light : BuHaptic.selection);
    setState(() => _leaving.add(id));
    try {
      await (accept ? _api.accept(id) : _api.decline(id));
      if (!mounted) return;
      await Future<void>.delayed(BuMotion.of(context, const Duration(milliseconds: 220)));
      if (!mounted) return;
      setState(() {
        _items.removeWhere((x) => _id(x) == id);
        _leaving.remove(id);
      });
      // Kabul edilen sohbet ana listeye düşer: sohbet sekmesi yeniden yüklensin.
      widget.session.badges.conversationsDirty.value++;
    } catch (e) {
      if (!mounted) return;
      setState(() => _leaving.remove(id));
      BuToast.show(context, errorText(e), kind: BuToastKind.error);
    }
  }

  Future<void> _open(Map<String, dynamic> c) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(settings: const RouteSettings(name: 'chat_detail'), builder: (_) => ChatDetailPage(session: widget.session, conversation: c)),
    );
    // Sohbette yanıt yazılmış olabilir (istek kabul edilmiş sayılır): liste yeniden alınır.
    if (mounted) {
      widget.session.badges.conversationsDirty.value++;
      _load(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final Widget body;
    if (_loading) {
      body = const FollowSkeletonCard(count: 4);
    } else if (_error != null && _items.isEmpty) {
      body = FollowStatusCard(
        error: true,
        icon: BuIcons.wifiOff,
        title: l.p18FollowErrorTitle,
        message: errorText(_error!),
        onRetry: _load,
      );
    } else if (_items.isEmpty) {
      body = FollowStatusCard(
        key: const ValueKey('message-requests-empty'),
        icon: BuIcons.inbox,
        title: l.frqMsgReqEmpty,
      );
    } else {
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FollowCard(dividerIndent: 76, children: [
          for (final c in _items)
            _RequestTile(
              key: ValueKey('message-request-${_id(c)}'),
              session: widget.session,
              conversation: c,
              leaving: _leaving.contains(_id(c)),
              onOpen: () => _open(c),
              onAccept: () => _decide(c, accept: true),
              onDecline: () => _decide(c, accept: false),
            ),
        ]),
        if (_more) const Padding(padding: EdgeInsets.only(top: 12), child: FollowSkeletonCard(count: 2)),
      ]);
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(title: l.frqMsgReqTitle, onBack: () => Navigator.maybePop(context)),
        Expanded(
          child: RefreshIndicator(
            onRefresh: Analytics.pullRefresh(() => _load(silent: true)),
            child: ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.paddingOf(context).bottom + 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
                  child: Text(l.frqMsgReqInfo,
                      key: const ValueKey('message-requests-info'),
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: 14, color: t.mut, height: 1.45)),
                ),
                body,
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

/// İstek satırı: avatar, ad (+ "Grup daveti" etiketi), son mesaj önizlemesi; altında Kabul et (birincil) / Sil (çizgili).
class _RequestTile extends StatelessWidget {
  const _RequestTile({
    super.key,
    required this.session,
    required this.conversation,
    required this.leaving,
    required this.onOpen,
    required this.onAccept,
    required this.onDecline,
  });

  final Session session;
  final Map<String, dynamic> conversation;
  final bool leaving;
  final VoidCallback onOpen;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  String _title(BuildContext context) {
    final c = conversation;
    final peer = c['peer'];
    if (_MessageRequestsPageState._isDirect(c) && peer is Map && (peer['displayName'] as String?)?.isNotEmpty == true) {
      return peer['displayName'] as String;
    }
    final t = c['title'] as String?;
    return (t != null && t.isNotEmpty) ? t : context.l10n.chatMiscChat;
  }

  String _preview(BuildContext context) {
    final l = context.l10n;
    final last = conversation['lastMessage'];
    if (last is! Map) return '';
    final byKind = placeholderKindText(context, last['placeholderKind']);
    if (byKind != null) return byKind;
    final text = (last['text'] as String?)?.trim() ?? '';
    if (text.isNotEmpty) return text.replaceAll(RegExp(r'\s+'), ' ');
    final att = last['attachments'];
    if (att is List && att.isNotEmpty) {
      final first = att.whereType<Map>().first;
      return first['kind'] == 'VIDEO' ? l.chatMiscVideo : l.chatMiscPhoto;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final c = conversation;
    final direct = _MessageRequestsPageState._isDirect(c);
    final peer = c['peer'];
    final title = _title(context);
    final avatar = direct ? (peer is Map ? peer['avatarUrl'] as String? : null) : c['avatarUrl'] as String?;
    final preview = _preview(context);

    final head = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ChatlistAvatar(name: title, url: avatar, group: !direct, size: 48, preview: true),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: t.ink)),
          if (!direct)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(l.frqMsgReqGroupInvite,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w600, color: t.pr)),
            ),
          if (preview.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(fontSize: 14, color: t.mut)),
            ),
        ]),
      ),
    ]);

    final row = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Satıra dokunmak sohbeti açar (yalnız başlık bloğu; düğmeler ayrı hedef).
        Semantics(
          button: true,
          label: [title, if (!direct) l.frqMsgReqGroupInvite, preview].where((e) => e.isNotEmpty).join(', '),
          excludeSemantics: true,
          onTap: onOpen,
          child: InkWell(
            key: ValueKey('message-request-open-${(c['id'] as num?)?.toInt()}'),
            borderRadius: BorderRadius.circular(8),
            onTap: onOpen,
            child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48), child: head),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 60),
          child: Row(children: [
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: BuButton(
                  key: ValueKey('message-request-accept-${(c['id'] as num?)?.toInt()}'),
                  label: l.frqMsgReqAccept,
                  compact: true,
                  onPressed: leaving ? null : onAccept,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: BuButton(
                  key: ValueKey('message-request-decline-${(c['id'] as num?)?.toInt()}'),
                  label: l.frqMsgReqDecline,
                  kind: BuButtonKind.outline,
                  compact: true,
                  onPressed: leaving ? null : onDecline,
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
    return ClipRect(
      child: IgnorePointer(
        ignoring: leaving,
        child: AnimatedAlign(
          alignment: Alignment.topCenter,
          heightFactor: leaving ? 0 : 1,
          duration: BuMotion.of(context, const Duration(milliseconds: 220)),
          curve: Curves.easeOutCubic,
          child: row,
        ),
      ),
    );
  }
}
