import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
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
            label: '$i yıldız',
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
                    color: (value ?? 0) >= i ? t.pr : t.mut),
              ),
            ),
          ),
      ],
    );
  }
}

/// Seçenek sonuç çubuğu: yüzde ve oy sayısı; [mine] ise vurgulu ve onay işaretli.
class ResultBar extends StatelessWidget {
  const ResultBar({super.key, required this.text, required this.percent, required this.votes, this.mine = false, this.showVotes = true, this.score});

  final String text;
  final double percent;
  final int votes;
  final bool mine;
  final bool showVotes;

  /// Sıralı seçimde Borda puanı.
  final int? score;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final pct = percent.round();
    return Semantics(
      label: '$text, yüzde $pct${showVotes ? ', $votes oy' : ''}${mine ? ', seçiminiz' : ''}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: t.sf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: mine ? t.pr : t.bd, width: mine ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (mine) ...[Icon(LucideIcons.check, size: 15, color: t.pr), const SizedBox(width: 6)],
              Expanded(child: Text(text, style: BuType.bodyStrong.copyWith(color: t.ink))),
              const SizedBox(width: 8),
              Text('%$pct', style: BuType.bodyStrong.copyWith(color: mine ? t.pr : t.ink)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (percent / 100).clamp(0, 1).toDouble(),
                minHeight: 8,
                backgroundColor: t.sf2,
                color: mine ? t.pr : t.mut,
              ),
            ),
            if (showVotes) ...[
              const SizedBox(height: 4),
              Text('$votes oy${score != null ? ' · $score puan' : ''}', style: BuType.caption.copyWith(color: t.mut)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Liste kartı: başlık, kulüp, tür/kalan süre rozetleri, katılım.
class PollCard extends StatelessWidget {
  const PollCard({super.key, required this.poll, required this.onTap});

  final Poll poll;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final closed = poll.isClosed();
    final rem = pollRemaining(poll.closesAt);
    final typeLabel = switch (poll.type) {
      PollType.single => 'Tek seçim',
      PollType.multi => 'Çoklu seçim',
      PollType.rating => 'Puanlama',
      PollType.ranked => 'Sıralı seçim',
    };
    return Semantics(
      button: true,
      label: 'Anket: ${poll.title}',
      child: BuCard(
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (poll.communityName != null) ...[
                Row(children: [
                  Icon(LucideIcons.users, size: 12.5, color: t.mut),
                  const SizedBox(width: 5),
                  Flexible(
                      child: Text(poll.communityName!,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.label.copyWith(color: t.mut))),
                ]),
                const SizedBox(height: 6),
              ],
              Text(poll.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: BuType.heading.copyWith(color: t.ink)),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                BuBadge(typeLabel, soft: true),
                if (poll.anonymous) const BuBadge('Gizli oy', soft: true),
                if (poll.voted) BuBadge('Oy verdiniz', color: t.okSoft, onColor: t.ok),
                if (rem != null) BuBadge(closed ? 'Kapandı' : rem, soft: !closed),
              ]),
              const SizedBox(height: 8),
              Text('${poll.participants} katılım', style: BuType.caption.copyWith(color: t.mut)),
            ],
          ),
        ),
      ),
    );
  }
}
