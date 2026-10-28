import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
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
    return Column(
      children: [
        if (widget.canCreate)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: BuButton(label: context.l10n.pollCreate, icon: LucideIcons.plus, kind: BuButtonKind.soft, compact: true, onPressed: _create),
            ),
          ),
        if (_error != null && items == null)
          SizedBox(height: 240, child: ErrorView(error: _error!, onRetry: _load))
        else if (items == null)
          const SizedBox(height: 200, child: LoadingView())
        else if (items.isEmpty)
          SizedBox(height: 220, child: EmptyView(icon: LucideIcons.vote, text: context.l10n.pollClubEmpty))
        else ...[
          for (final p in items)
            Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 12), child: PollCard(poll: p, onTap: () => _open(p))),
          if (_more)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextButton(
                onPressed: () => openPollList(context, widget.session,
                    communityId: widget.communityId, title: context.l10n.pollClubPolls),
                child: Text(context.l10n.pollSeeAll),
              ),
            ),
        ],
      ],
    );
  }
}
