import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import 'anket_style.dart';
import 'poll_models.dart';

/// 1-5 yıldız seçici. [value] null ise boş; [onChanged] null ise salt okunur.
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.value, this.onChanged, this.size = 36});

  final int? value;
  final ValueChanged<int>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Semantics(
            button: onChanged != null,
            selected: value == i,
            label: context.l10n.pollStars('$i'),
            excludeSemantics: true,
            onTap: onChanged == null ? null : () => onChanged!(i),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onChanged == null ? null : () => onChanged!(i),
              child: SizedBox(
                width: size + 8,
                height: size + 8,
                child: Icon(LucideIcons.star,
                    size: size,
                    fill: (value ?? 0) >= i ? 1 : 0,
                    color: (value ?? 0) >= i ? anketGold : t.mut.withValues(alpha: .6)),
              ),
            ),
          ),
      ],
    );
  }
}

/// Seçenek sonuç satırı (tasarım An3): ad, yüzde, çubuk, oy sayısı; [mine] ise "Seçiminiz" rozeti.
/// [top] en çok oy alan seçenektir (koyu kırmızı çubuk).
class ResultBar extends StatelessWidget {
  const ResultBar(
      {super.key, required this.text, required this.percent, required this.votes, this.mine = false, this.showVotes = true, this.score, this.top = false});

  final String text;
  final double percent;
  final int votes;
  final bool mine;
  final bool showVotes;
  final bool top;

  /// Sıralı seçimde Borda puanı.
  final int? score;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final pct = percent.round();
    final fill = top ? t.pr : (mine ? t.pr.withValues(alpha: .62) : t.pr.withValues(alpha: .28));
    return Semantics(
      label: [
        context.l10n.pollSemPercent(text, '$pct'),
        if (showVotes) context.l10n.pollVotes('$votes'),
        if (mine) context.l10n.pollSemMine,
      ].join(', '),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            if (mine) ...[Icon(LucideIcons.check, size: 15, color: t.pr), const SizedBox(width: 6)],
            Expanded(
              child: Wrap(spacing: 6, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(text, style: anketText(13, FontWeight.w600, mine ? t.pr : t.ink, height: 1.3)),
                if (mine)
                  AnketPill(context.l10n.anketMineBadge, bg: t.soft, fg: t.pr, small: true),
              ]),
            ),
            const SizedBox(width: 8),
            Text('%$pct', style: anketText(13.5, FontWeight.w800, mine ? t.pr : t.ink)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 12,
              color: t.sf2,
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: (percent / 100).clamp(0, 1).toDouble(),
                child: Container(decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(6))),
              ),
            ),
          ),
          if (showVotes) ...[
            const SizedBox(height: 4),
            Text(
                score != null
                    ? context.l10n.pollVotesWithScore('$votes', '$score')
                    : context.l10n.pollVotes('$votes'),
                style: anketText(11.5, FontWeight.w500, t.mut)),
          ],
        ],
      ),
    );
  }
}

/// Liste kartı (tasarım An1): kapsam rozeti, "Gizli oy", durum hapı, başlık, kalan süre · oy.
class PollCard extends StatelessWidget {
  const PollCard({super.key, required this.poll, required this.onTap});

  final Poll poll;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final closed = poll.isClosed();
    final rem = pollRemaining(poll.closesAt, null, l);
    final (scopeLabel, tone) = switch (poll.scope.toUpperCase()) {
      'COMMUNITY' => (l.anketScopeClub, AnketTone.club(context)),
      'MENU' => (l.anketScopeMenu, AnketTone.meal(context)),
      _ => (l.anketScopeGlobal, AnketTone.general(context)),
    };
    final (statusLabel, sBg, sFg) = closed
        ? (l.pollClosedBadge, t.sf2, t.mut)
        : poll.voted
            ? (l.pollVotedBadge, t.okSoft, t.ok)
            : (l.pollVote, t.soft, t.pr);
    final meta = <String>[
      if (closed) l.pollParticipants('${poll.participants}') else ...[if (rem != null) rem, l.pollVotes('${poll.participants}')],
    ];
    return Semantics(
      button: true,
      label: l.pollSemPoll(poll.title),
      child: Opacity(
        opacity: closed ? .92 : 1,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: anketCardDeco(t),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: Wrap(spacing: 6, runSpacing: 6, children: [
                            AnketPill(scopeLabel, bg: tone.bg, fg: tone.fg),
                            if (poll.anonymous) AnketPill(l.pollAnonymous, bg: t.sf2, fg: t.ink, icon: LucideIcons.lock),
                          ]),
                        ),
                        const SizedBox(width: 6),
                        AnketPill(statusLabel, bg: sBg, fg: sFg),
                      ]),
                      if (poll.communityName != null) ...[
                        const SizedBox(height: 8),
                        Text(poll.communityName!,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: anketText(12, FontWeight.w600, t.mut)),
                      ],
                      const SizedBox(height: 10),
                      Text(poll.title,
                          maxLines: 3, overflow: TextOverflow.ellipsis, style: anketText(15, FontWeight.w700, t.ink, height: 1.35)),
                      const SizedBox(height: 8),
                      Row(children: [
                        if (!closed) ...[Icon(LucideIcons.clock, size: 14, color: t.mut), const SizedBox(width: 6)],
                        Expanded(
                          child: Text(meta.join(' · '),
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: anketText(12, FontWeight.w500, t.mut)),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
