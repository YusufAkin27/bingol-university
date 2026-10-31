import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'anket_flat.dart';
import 'poll_api.dart';
import 'poll_models.dart';
import 'poll_parts.dart';
import 'poll_routes.dart';

/// Kulüp detayındaki "Anketler" bölümü (Stitch v3 kartsız satırlar): başlık + (yönetici ise) `pr` "+ Yeni", altında
/// kulübün anketleri satır olarak. [canCreate] false ise oluşturma düğmesi hiç gösterilmez.
class PollClubSection extends StatefulWidget {
  const PollClubSection({super.key, required this.session, required this.communityId, required this.canCreate, this.hideWhenEmpty = false});

  final Session session;
  final int communityId;
  final bool canCreate;

  /// true: anket yoksa (ve oluşturma yetkisi yoksa) bölüm hiç çizilmez (Kulüp detayı "Hakkında" sekmesi).
  final bool hideWhenEmpty;

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
    if (widget.hideWhenEmpty && !widget.canCreate && (items == null ? _error == null : items.isEmpty)) return const SizedBox.shrink();
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    void seeAll() =>
        openPollList(context, widget.session, communityId: widget.communityId, title: l.pollClubPolls, canCreate: widget.canCreate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l.pollClubPolls, style: tx.titleMedium!.copyWith(color: t.ink, fontSize: 18, fontWeight: FontWeight.w600)),
                ),
              ),
              if (widget.canCreate)
                Semantics(
                  button: true,
                  label: l.pollCreate,
                  excludeSemantics: true,
                  onTap: _create,
                  child: TextButton(
                    style: TextButton.styleFrom(foregroundColor: t.pr, minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 12)),
                    onPressed: _create,
                    child: Text('+ ${l.p68New}', style: tx.titleSmall!.copyWith(color: t.pr, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const AnketRule(),
        if (_error != null && items == null)
          AnketStateLine(text: l.pollLoadFailedRetry, actionLabel: l.commonRetry, onAction: _load)
        else if (items == null)
          const BuSkeletonScope(child: Column(children: [AnketSkeletonRow(titleWidth: 230), AnketSkeletonRow(titleWidth: 190)]))
        else if (items.isEmpty)
          AnketStateLine(text: l.pollClubEmpty, actionLabel: l.pollSeeAll, onAction: () => openPollList(context, widget.session))
        else ...[
          BuStaggerScope(
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  BuStaggerItem(index: i, child: PollCard(poll: items[i], first: i == 0, onTap: () => _open(items[i]))),
              ],
            ),
          ),
          if (_more)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: kAnketPad),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  style: TextButton.styleFrom(foregroundColor: t.pr, minimumSize: const Size(48, 48), padding: EdgeInsets.zero),
                  onPressed: seeAll,
                  child: Text(l.pollSeeAll, style: tx.titleSmall!.copyWith(color: t.pr, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
