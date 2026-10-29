import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'anket_widgets.dart';
import 'poll_api.dart';
import 'poll_models.dart';
import 'poll_parts.dart';
import 'poll_routes.dart';

/// Kulüp detayındaki "Anketler" sekmesi içeriği: kulübün anketleri + (yönetici ise) anket oluştur.
/// [canCreate] false ise oluşturma düğmesi hiç gösterilmez.
class PollClubSection extends StatefulWidget {
  const PollClubSection({super.key, required this.session, required this.communityId, required this.canCreate});

  final Session session;
  final int communityId;
  final bool canCreate;

  @override
  State<PollClubSection> createState() => _PollClubSectionState();
}

class _PollClubSectionState extends State<PollClubSection> {
  late final PollApi _api = PollApi(widget.session);
  List<Poll>? _items;
  bool _more = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await _api.list(scope: 'community:${widget.communityId}', size: 5);
      if (mounted) {
        setState(() {
          _items = r.items;
          _more = r.hasMore;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _create() async {
    final p = await openPollForm(context, widget.session, communityId: widget.communityId);
    if (p != null && mounted) _load();
  }

  Future<void> _open(Poll p) async {
    await openPollDetail(context, widget.session, p.id, initial: p);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    void seeAll() =>
        openPollList(context, widget.session, communityId: widget.communityId, title: l.pollClubPolls, canCreate: widget.canCreate);
    return Column(
      children: [
        if (widget.canCreate)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
            child: BuCard(
              onTap: _create,
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    ExcludeSemantics(child: Icon(LucideIcons.circlePlus, size: 20, color: t.pr)),
                    const SizedBox(width: 10),
                    Flexible(child: Text(l.pollCreate, style: tx.titleSmall!.copyWith(color: t.pr, fontWeight: FontWeight.w800))),
                  ]),
                ),
              ),
            ),
          ),
        if (_error != null && items == null)
          SizedBox(height: 300, child: BuErrorState(error: _error, compact: true, onRetry: _load))
        else if (items == null)
          const BuSkeletonList(variant: BuSkeletonVariant.card, itemCount: 2, shrinkWrap: true)
        else if (items.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 0),
            child: BuCard(
              padding: const EdgeInsetsDirectional.all(12),
              child: AnketClubEmpty(
                title: l.pollClubEmpty,
                body: l.p13PollClubEmptyBody,
                linkLabel: l.pollSeeAll,
                onLink: () => openPollList(context, widget.session),
              ),
            ),
          )
        else ...[
          BuStaggerScope(
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  BuStaggerItem(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
                      child: PollCard(poll: items[i], onTap: () => _open(items[i])),
                    ),
                  ),
              ],
            ),
          ),
          if (_more) Padding(padding: const EdgeInsets.only(bottom: 12), child: AnketLinkButton(label: l.pollSeeAll, onTap: seeAll)),
        ],
      ],
    );
  }
}
