import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'anket_style.dart';
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
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: Text(l.pollClubPolls, style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w800))),
                    Text(l.p11PollsSub, style: tx.bodySmall!.copyWith(color: t.mut)),
                  ],
                ),
              ),
              if (widget.canCreate) ...[
                const SizedBox(width: 12),
                BuButton(label: l.pollCreate, icon: LucideIcons.chartColumn, compact: true, onPressed: _create),
              ],
            ],
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
                      child: items[i].isClosed()
                          ? _ClubClosedCard(poll: items[i], onTap: () => _open(items[i]))
                          : _ClubOpenCard(poll: items[i], onTap: () => _open(items[i])),
                    ),
                  ),
              ],
            ),
          ),
          if (_more)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: AnketLinkButton(label: l.pollSeeAll, onTap: seeAll))
          else
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
              child: BuCard(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(children: [
                    const AnketRoundIcon(LucideIcons.listChecks, size: 52),
                    const SizedBox(height: 12),
                    Semantics(
                      header: true,
                      child: Text(l.p13PollNoMoreActive, textAlign: TextAlign.center, style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 6),
                    Text(l.p13PollNoMoreBody, textAlign: TextAlign.center, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.45)),
                    const SizedBox(height: 6),
                    AnketLinkButton(label: l.pollSeeAll, onTap: seeAll),
                  ]),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Kulüp sekmesindeki açık anket kartı: "Açık anket" hapı, kalan süre, katılım, başlık, açıklama, not + "Oyla".
class _ClubOpenCard extends StatelessWidget {
  const _ClubOpenCard({required this.poll, required this.onTap});

  final Poll poll;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final rem = pollRemaining(poll.closesAt, null, l);
    final count = poll.totalVotes ?? poll.turnoutVoted;
    final canAct = !poll.voted && poll.canVote && !poll.notOpenYet;
    final notes = [if (!poll.allowChangeVote) l.p13PollOneVote, if (!poll.resultsVisible) l.p13PollHiddenResults];
    return Semantics(
      button: true,
      label: l.pollSemPoll(poll.title),
      excludeSemantics: true,
      onTap: onTap,
      child: BuCard(
        onTap: onTap,
        padding: const EdgeInsetsDirectional.all(16),
        child: SizedBox(
          width: double.infinity,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 6, children: [
              Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                _DotBadge(label: l.p13PollOpenBadge, bg: t.soft, fg: t.onSoft, dot: t.pr),
                if (rem != null) AnketPill(rem, bg: t.sf2, fg: t.ink, icon: LucideIcons.timer, small: true),
              ]),
              if (count != null)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.users, size: 15, color: t.mut),
                  const SizedBox(width: 4),
                  Text(l.pollParticipants('$count'), maxLines: 1, style: tx.labelMedium!.copyWith(color: t.mut, fontWeight: FontWeight.w600)),
                ]),
            ]),
            const SizedBox(height: 12),
            Text(poll.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w800, fontSize: 17, height: 1.3)),
            if (poll.description != null) ...[
              const SizedBox(height: 6),
              Text(poll.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.45)),
            ],
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: notes.isEmpty
                    ? const SizedBox.shrink()
                    : Row(children: [
                        ExcludeSemantics(child: Icon(LucideIcons.lock, size: 15, color: t.mut)),
                        const SizedBox(width: 6),
                        Flexible(child: Text(notes.join(' · '), style: tx.labelMedium!.copyWith(color: t.mut, height: 1.3))),
                      ]),
              ),
              if (canAct) ...[
                const SizedBox(width: 12),
                ExcludeSemantics(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsetsDirectional.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(color: t.pr, borderRadius: BorderRadius.circular(14)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(l.p13PollVoteCta, style: tx.labelLarge!.copyWith(color: t.onPr, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Icon(LucideIcons.circleCheck, size: 16, color: t.onPr),
                    ]),
                  ),
                ),
              ] else if (poll.voted) ...[
                const SizedBox(width: 12),
                AnketPill(l.pollVotedBadge, bg: t.sf2, fg: t.ink, icon: LucideIcons.circleCheck),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Kulüp sekmesindeki kapanan anket kartı: "Kapanan anket" etiketi, "Tamamlandı · N oy", başlık, kazanan.
class _ClubClosedCard extends StatelessWidget {
  const _ClubClosedCard({required this.poll, required this.onTap});

  final Poll poll;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final count = poll.totalVotes ?? poll.turnoutVoted;
    final sum = PollResultSummary.of(poll);
    final winner = sum?.topText == null ? null : l.p13PollWinner(sum!.topText!, '${sum.topPercent!.round()}');
    final kicker = Localizations.localeOf(context).languageCode == 'tr' ? trUpper(l.p13PollClosedKicker) : l.p13PollClosedKicker.toUpperCase();
    return Semantics(
      button: true,
      label: l.pollSemPoll(poll.title),
      excludeSemantics: true,
      onTap: onTap,
      child: BuCard(
        onTap: onTap,
        padding: const EdgeInsetsDirectional.all(16),
        child: SizedBox(
          width: double.infinity,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: t.mut.withValues(alpha: .6), shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(kicker, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(color: t.mut, fontWeight: FontWeight.w800, letterSpacing: .4))),
              const SizedBox(width: 8),
              Flexible(
                child: AnketPill(count == null ? l.pollEnded : l.p13PollDone('$count'), bg: t.sf2, fg: t.ink, small: true),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(poll.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w800, height: 1.3)),
                  if (winner != null) ...[
                    const SizedBox(height: 2),
                    Text(winner, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.4)),
                  ],
                ]),
              ),
              const SizedBox(width: 12),
              AnketIconTile(LucideIcons.award, bg: t.sf2, fg: t.mut, size: 44),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Noktalı hap ("● Açık anket").
class _DotBadge extends StatelessWidget {
  const _DotBadge({required this.label, required this.bg, required this.fg, required this.dot});

  final String label;
  final Color bg;
  final Color fg;
  final Color dot;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BuRadius.bPill),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: fg, fontWeight: FontWeight.w700)),
        ]),
      );
}
