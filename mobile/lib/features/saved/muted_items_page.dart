import 'package:flutter/material.dart';

import '../../core/analytics.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart' show LoadingView;
import '../profile/profil_widgets.dart' show ProfilSection;
import 'saved_api.dart';

/// Ayarlar > Bildirimler > "Sessize alınanlar": sessize alınan kulüp ve etkinlikler, tek dokunuşla açma.
/// Veri: `GET /me/notification-mutes`, ad için `GET /communities/{id}` / `GET /events/{id}`,
/// açma `PUT .../notification-mute {"muted":false}`.
class MutedItemsPage extends StatefulWidget {
  const MutedItemsPage({super.key, required this.session});

  final Session session;

  @override
  State<MutedItemsPage> createState() => _MutedItemsPageState();
}

class _MutedItemsPageState extends State<MutedItemsPage> {
  late final MuteApi _api = MuteApi(widget.session);
  List<int>? _clubs;
  List<int>? _events;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final m = await _api.mine();
      if (!mounted) return;
      setState(() {
        _clubs = [...m.communities];
        _events = [...m.events];
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _unmute(String scope, int id) async {
    final list = scope == 'communities' ? _clubs! : _events!;
    final idx = list.indexOf(id);
    if (idx < 0) return;
    setState(() => list.removeAt(idx));
    try {
      await _api.setMuted(scope, id, false);
      if (mounted) BuToast.show(context, context.l10n.muteOffToast, kind: BuToastKind.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => list.insert(idx.clamp(0, list.length), id));
      BuToast.show(context, errorText(e), kind: BuToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    Widget body;
    if (_error != null && _clubs == null) {
      body = BuErrorState(error: _error!, onRetry: _load);
    } else if (_clubs == null) {
      body = const LoadingView();
    } else if (_clubs!.isEmpty && _events!.isEmpty) {
      body = RefreshIndicator(
        onRefresh: Analytics.pullRefresh(_load),
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: BuEmptyState(
                key: const ValueKey('muted-empty'),
                icon: BuIcons.bellOff,
                title: l.mutedEmptyTitle,
                message: l.mutedEmptyBody,
              ),
            ),
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: Analytics.pullRefresh(_load),
        child: ListView(
          key: const ValueKey('muted-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.paddingOf(context).bottom + 24),
          children: [
            Text(l.muteCriticalNote, style: tx.bodyMedium!.copyWith(fontSize: 13, height: 1.5, color: t.mut)),
            if (_clubs!.isNotEmpty) ProfilSection(l.mutedClubs, top: 16),
            for (final id in _clubs!)
              _MutedRow(
                key: ValueKey('muted-club-$id'),
                id: 'muted-club-$id',
                session: widget.session,
                path: '/communities/$id',
                nameKey: 'name',
                fallback: l.mutedClubFallback('$id'),
                onUnmute: () => _unmute('communities', id),
              ),
            if (_events!.isNotEmpty) ProfilSection(l.mutedEvents, top: 16),
            for (final id in _events!)
              _MutedRow(
                key: ValueKey('muted-event-$id'),
                id: 'muted-event-$id',
                session: widget.session,
                path: '/events/$id',
                nameKey: 'title',
                fallback: l.mutedEventFallback('$id'),
                onUnmute: () => _unmute('events', id),
              ),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(title: l.mutedRowTitle, visibleTitle: true, onBack: () => Navigator.maybePop(context)),
        Expanded(child: body),
      ]),
    );
  }
}

/// Tek satır: adı tembel çeker (alınamazsa "Kulüp 12" gibi yedek ad), sağda "Aç" düğmesi.
class _MutedRow extends StatefulWidget {
  const _MutedRow({super.key, required this.id, required this.session, required this.path, required this.nameKey, required this.fallback, required this.onUnmute});

  final String id;
  final Session session;
  final String path;
  final String nameKey;
  final String fallback;
  final VoidCallback onUnmute;

  @override
  State<_MutedRow> createState() => _MutedRowState();
}

class _MutedRowState extends State<_MutedRow> {
  String? _name;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final r = await widget.session.api.get(widget.path);
      final n = r is Map ? r[widget.nameKey]?.toString() : null;
      if (mounted && n != null && n.isNotEmpty) setState(() => _name = n);
    } catch (_) {
      // Ad alınamazsa yedek ad kalır.
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(children: [
        Expanded(child: Text(_name ?? widget.fallback, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodyLarge!.copyWith(fontSize: 16, color: t.ink))),
        const SizedBox(width: 12),
        BuButton(
          key: ValueKey('${widget.id}-unmute'),
          label: context.l10n.mutedUnmute,
          compact: true,
          kind: BuButtonKind.outline,
          onPressed: widget.onUnmute,
        ),
      ]),
    );
  }
}
