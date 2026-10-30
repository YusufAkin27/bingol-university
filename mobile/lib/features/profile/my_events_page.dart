import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../events/etkinlik_parts.dart';
import '../events/event_cover.dart';
import '../events/event_detail_page.dart';
import '../events/event_parts.dart';
import '../events/events_page.dart';

/// Etkinliklerim: Katıldıklarım (yaklaşan + geçmiş) / Oluşturduklarım (GET /me/events?mode=...).
/// Katılımdan ayrılma etkinlik ayrıntı sayfasındadır.
class MyEventsPage extends StatefulWidget {
  const MyEventsPage({super.key, required this.session});

  final Session session;

  @override
  State<MyEventsPage> createState() => _MyEventsPageState();
}

class _Feed {
  List<Map<String, dynamic>> items = [];
  int? next;
  bool loading = false;
  bool loaded = false;
  bool more = false;
  Object? error;
  int gen = 0;
}

class _MyEventsPageState extends State<MyEventsPage> {
  int _tab = 0;
  int _sub = 0; // Katıldıklarım: 0 Yaklaşan, 1 Geçmiş
  final _scroll = ScrollController();
  final Map<String, _Feed> _feeds = {'up': _Feed(), 'past': _Feed(), 'created': _Feed()};

  List<String> get _keys => _tab == 0 ? const ['up', 'past'] : const ['created'];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _loadTab();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _loadTab({bool silent = false}) {
    for (final k in _keys) {
      _load(k, silent: silent);
    }
  }

  String _path(String key, {int? cursor}) {
    final mode = switch (key) {
      'created' => 'organizing',
      'past' => 'past',
      _ => 'attending',
    };
    return '/me/events?mode=$mode&size=20${cursor == null ? '' : '&cursor=$cursor'}';
  }

  DateTime? _start(Map<String, dynamic> e) => DateTime.tryParse('${e['startsAt'] ?? ''}')?.toLocal();
  DateTime? _end(Map<String, dynamic> e) => DateTime.tryParse('${e['endsAt'] ?? ''}')?.toLocal();

  bool _isPast(Map<String, dynamic> e) {
    final end = _end(e) ?? _start(e);
    return end != null && end.isBefore(DateTime.now());
  }

  /// Sunucu modu desteklemese bile Yaklaşan/Geçmiş ayrımı istemcide doğrulanır.
  List<Map<String, dynamic>> _parse(String key, dynamic res) {
    final list = res is Map ? res['items'] : res;
    if (list is! List) return [];
    final all = [
      for (final e in list)
        if (e is Map) e.cast<String, dynamic>()
    ];
    return switch (key) {
      'up' => all.where((e) => !_isPast(e)).toList(),
      'past' => all.where(_isPast).toList(),
      _ => all,
    };
  }

  int? _next(dynamic res) => (res is Map ? res['nextCursor'] : null) is num ? (res['nextCursor'] as num).toInt() : null;

  Future<void> _load(String key, {bool silent = false}) async {
    final f = _feeds[key]!;
    final gen = ++f.gen;
    if (!silent || !f.loaded) {
      setState(() {
        f.loading = true;
        f.error = null;
      });
    }
    try {
      final res = await widget.session.api.get(_path(key));
      if (!mounted || gen != f.gen) return;
      setState(() {
        f.items = _parse(key, res);
        f.next = _next(res);
        f.loading = false;
        f.loaded = true;
        f.error = null;
      });
    } catch (e) {
      if (!mounted || gen != f.gen) return;
      setState(() {
        f.error = e;
        f.loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    for (final key in _keys) {
      final f = _feeds[key]!;
      if (f.more || f.loading || f.next == null) continue;
      final gen = f.gen;
      setState(() => f.more = true);
      try {
        final res = await widget.session.api.get(_path(key, cursor: f.next));
        if (!mounted || gen != f.gen) return;
        setState(() {
          final seen = f.items.map((e) => e['id']).toSet();
          f.items = [...f.items, ..._parse(key, res).where((e) => seen.add(e['id']))];
          f.next = _next(res);
          f.more = false;
        });
      } catch (_) {
        if (mounted) setState(() => f.more = false);
      }
      return;
    }
  }

  Future<void> _open(Map<String, dynamic> e) async {
    final id = (e['id'] as num?)?.toInt();
    if (id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDetailPage(session: widget.session, eventId: id)),
    );
    if (mounted) _loadTab(silent: true);
  }

  void _discover() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => EventsPage(session: widget.session)));
  }

  void _setSub(int i) {
    if (i == _sub) return;
    setState(() => _sub = i);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _switch(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    for (final k in _keys) {
      if (!_feeds[k]!.loaded) _load(k);
    }
  }

  /// İstek ya da katılım geri çekilir (DELETE /events/{id}/rsvp), onaydan sonra.
  Future<void> _withdraw(Map<String, dynamic> e, {required bool request}) async {
    final l = context.l10n;
    final id = (e['id'] as num?)?.toInt();
    if (id == null) return;
    final ok = await confirmEventDialog(
      context,
      title: request ? l.etkinlik2WithdrawTitle : l.eventListLeaveTitle,
      message: request ? l.etkinlik2WithdrawMessage : l.eventListLeaveMsg,
      confirmLabel: request ? l.etkinlik2Withdraw : l.eventListLeave,
      danger: true,
      icon: LucideIcons.calendarX,
    );
    if (!ok || !mounted) return;
    try {
      await widget.session.api.delete('/events/$id/rsvp');
      if (!mounted) return;
      BuToast.show(context, request ? l.etkinlik2WithdrawnToast : l.eventListLeft, kind: BuToastKind.success);
      _loadTab(silent: true);
    } catch (err) {
      if (mounted) BuToast.show(context, errorText(err), kind: BuToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final key = _tab == 0 ? (_sub == 1 ? 'past' : 'up') : 'created';
    final f = _feeds[key]!;
    final loading = f.loading && !f.loaded;
    final failed = f.error != null && !f.loaded;

    return BuStaggerScope(
      child: BuPageScaffold(
        title: l.profileMyEvents,
        large: false,
        controller: _scroll,
        onRefresh: () async => _loadTab(silent: true),
        bottomInset: 32,
        state: loading ? BuViewState.loading : (failed ? BuViewState.error : BuViewState.ready),
        error: f.error,
        onRetry: () => _loadTab(),
        loading: const BuSkeletonList(variant: BuSkeletonVariant.card, itemCount: 3, shrinkWrap: true),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.15,
              child: BuSegmented(
                items: [l.profilyardEventsAttended, l.profilyardEventsCreated],
                index: _tab,
                onChanged: _switch,
              ),
            ),
          ),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: SliverList.list(children: [
              if (_tab == 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: EtkinlikSubChips(
                    labels: [l.profilyardEventsUpcoming, l.profilyardEventsPast],
                    selected: _sub,
                    onSelected: _setSub,
                  ),
                ),
              if (f.items.isEmpty)
                _tab == 0
                    ? EtkinlikEmptyCard(
                        icon: LucideIcons.calendarX,
                        title: l.profilyardEventsEmptyTitle,
                        body: l.profilyardEventsEmptyBody,
                        action: BuButton(label: l.eventListDiscover, icon: LucideIcons.compass, onPressed: _discover),
                      )
                    : EtkinlikEmptyCard(
                        icon: LucideIcons.calendarPlus,
                        title: l.eventListEmptyCreated,
                        body: l.p14EmptyCreatedBody2,
                      ),
            ]),
          ),
          if (f.items.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.builder(
                itemCount: f.items.length,
                itemBuilder: (_, i) => BuStaggerItem(
                  index: i,
                  child: Padding(padding: const EdgeInsets.only(bottom: 12), child: _row(f.items[i])),
                ),
              ),
            ),
          if (f.more)
            const SliverToBoxAdapter(child: BuSkeletonList(variant: BuSkeletonVariant.row, itemCount: 1, shrinkWrap: true)),
        ],
      ),
    );
  }

  /// Durum etiketi (katılım türü / bekleyen istek / iptal).
  Widget? _tag(Map<String, dynamic> e) {
    final l = context.l10n;
    if (e['status'] == 'CANCELLED') {
      return EventStatusTag(l.eventListCancelled, tone: EventTone.danger, icon: LucideIcons.calendarX);
    }
    if (_tab == 1) {
      final n = [e['pendingRequestCount'], e['pendingRequests'], e['pendingCount']].whereType<num>().firstOrNull?.toInt();
      return (n != null && n > 0)
          ? EventStatusTag(l.profilyardEventPendingCount('$n'), tone: EventTone.warn, icon: LucideIcons.userPlus)
          : null;
    }
    return switch (e['myRsvp']) {
      'GOING' => _GoingPill(l.profilyardEventGoing),
      'INTERESTED' => EventStatusTag(l.profilyardEventInterested, tone: EventTone.brand, icon: LucideIcons.star),
      'REQUESTED' || 'PENDING' => EventStatusTag(l.profilyardEventRequested, tone: EventTone.neutral, icon: LucideIcons.hourglass),
      _ => null,
    };
  }

  Widget _row(Map<String, dynamic> e) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final start = _start(e);
    final end = _end(e);
    final place = (e['location'] as String?)?.trim();
    final org = (e['communityName'] as String?)?.trim();
    final cover = fileUrl(e['coverUrl'] as String?);
    final time = start == null ? '' : (end != null ? '‎${eventHm(start)} – ${eventHm(end)}' : eventHm(start));
    final tag = _tag(e);
    final id = (e['id'] as num?)?.toInt() ?? 0;
    final cancelled = e['status'] == 'CANCELLED';
    final past = _isPast(e) || cancelled;
    final my = e['myRsvp'];
    final requested = _tab == 0 && (my == 'REQUESTED' || my == 'PENDING');
    final canLeave = _tab == 0 && !past && (my == 'GOING' || my == 'INTERESTED');

    final meta = <Widget>[
      if (time.isNotEmpty) _line(LucideIcons.clock, time),
      if (place != null && place.isNotEmpty) _line(LucideIcons.mapPin, place),
    ];

    return BuCard(
      key: ValueKey('my-ev-$id'),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 10, 12),
      radius: 20,
      onTap: () => _open(e),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          start == null
              ? Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(14)),
                  child: Icon(LucideIcons.calendar, size: 22, color: t.mut),
                )
              : EtkinlikDateBlock(
                  month: eventMonthShortOf(context, start.month),
                  day: '${start.day}',
                  tone: past ? EtkinlikBlockTone.grey : EtkinlikBlockTone.blue,
                  size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (org != null && org.isNotEmpty)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    ExcludeSemantics(child: Icon(LucideIcons.users, size: 13, color: past ? t.mut : t.pr)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(org,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: past ? t.mut : t.pr)),
                    ),
                  ]),
                const SizedBox(height: 2),
                Text('${e['title'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tx.titleMedium!.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: past ? t.mut : t.ink,
                        decoration: cancelled ? TextDecoration.lineThrough : null)),
              ]),
            ),
          ),
          if (canLeave)
            PopupMenuButton<String>(
              tooltip: l.eventListOptions,
              icon: Icon(LucideIcons.ellipsisVertical, size: 20, color: t.ink),
              onSelected: (_) => _withdraw(e, request: false),
              itemBuilder: (_) => [
                PopupMenuItem(
                    value: 'leave',
                    child: Row(children: [
                      Icon(LucideIcons.logOut, size: 18, color: t.danger),
                      const SizedBox(width: 10),
                      Text(l.eventListLeaveTitle),
                    ])),
              ],
            )
          else
            const SizedBox(width: 8),
        ]),
        if (cover != null) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 7,
                child: Stack(fit: StackFit.expand, children: [
                  EventCoverImage(url: cover),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, t.scrim.withValues(alpha: .65)],
                          stops: const [.4, 1],
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: 12,
                    end: 12,
                    bottom: 10,
                    child: Row(children: [
                      Icon(LucideIcons.clock, size: 14, color: t.onMedia),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          [if (time.isNotEmpty) time, if (place != null && place.isNotEmpty) place].join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tx.labelMedium!.copyWith(color: t.onMedia, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ] else if (meta.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Wrap(spacing: 14, runSpacing: 4, children: meta),
          ),
        ],
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8, top: 6),
          child: Row(children: [
            if (tag != null) Flexible(child: tag),
            const Spacer(),
            if (requested)
              EtkinlikDetailLink(label: l.p14WithdrawRequest, onTap: () => _withdraw(e, request: true), muted: false)
            else
              EtkinlikDetailLink(label: l.p14Detail, onTap: () => _open(e), muted: true),
          ]),
        ),
      ]),
    );
  }

  Widget _line(IconData icon, String text) {
    final t = context.bu;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      ExcludeSemantics(child: Icon(icon, size: 14, color: t.mut)),
      const SizedBox(width: 6),
      Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.mut))),
    ]);
  }
}

/// "Katılıyorum" hapı: açık mavi zemin + yeşil nokta.
class _GoingPill extends StatelessWidget {
  const _GoingPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: t.tint(1).bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: t.ok, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
        ),
      ]),
    );
  }
}
