import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'anket_style.dart';
import 'poll_models.dart';

/// 1-5 yıldız seçici. [value] null ise boş; [onChanged] null ise salt okunur.
/// Dokunulabilir yıldız en az 48 dp hedef; seçilen yıldız hafifçe büyüyüp titreşir (hareket azaltılmışsa yalnız renk).
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.value, this.onChanged, this.size = 36, this.activeColor, this.inactiveColor});

  final int? value;
  final ValueChanged<int>? onChanged;
  final double size;

  /// Dolu/boş yıldız renkleri (varsayılan: altın / soluk gri).
  final Color? activeColor;
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final gold = activeColor ?? anketGoldOf(context);
    final cell = onChanged == null ? size + 8 : (size + 8 < 48 ? 48.0 : size + 8);
    final d = BuMotion.of(context, BuMotion.short);
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
              onTap: onChanged == null
                  ? null
                  : () {
                      buHaptic(BuHaptic.selection);
                      onChanged!(i);
                    },
              child: SizedBox(
                width: cell,
                height: cell,
                child: AnimatedScale(
                  scale: value == i && onChanged != null ? 1.16 : 1,
                  duration: d,
                  curve: Curves.easeOutBack,
                  child: Icon((value ?? 0) >= i ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: size + 4,
                      color: (value ?? 0) >= i ? gold : (inactiveColor ?? t.mut.withValues(alpha: .5))),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Seçenek sonuç satırı (tasarım An3): ad, yüzde, animasyonlu çubuk, oy sayısı; [mine] ise "Seçiminiz" rozeti.
/// [top] en çok oy alan seçenektir (dolu marka çubuğu + "Önde" rozeti).
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
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final pct = percent.round();
    final fill = top ? t.pr : (mine ? t.pr.withValues(alpha: .62) : t.pr.withValues(alpha: .26));
    final frac = (percent / 100).clamp(0, 1).toDouble();
    return Semantics(
      label: [
        l.pollSemPercent(text, '$pct'),
        if (showVotes) l.pollVotes('$votes'),
        if (mine) l.pollSemMine,
        if (top && percent > 0) l.p13Leading,
      ].join(', '),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(text, style: tx.titleSmall!.copyWith(color: mine ? t.pr : t.ink, height: 1.3)),
                if (mine) AnketPill(l.anketMineBadge, bg: t.soft, fg: t.onSoft, small: true, icon: LucideIcons.check),
                if (top && percent > 0 && !mine) AnketPill(l.p13Leading, bg: t.sf2, fg: t.ink, small: true),
              ]),
            ),
            const SizedBox(width: 12),
            Text('%$pct', style: tx.titleMedium!.copyWith(color: mine ? t.pr : t.ink, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BuRadius.bPill,
            child: ColoredBox(
              color: t.sf2,
              child: SizedBox(
                height: 10,
                width: double.infinity,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: frac),
                  duration: BuMotion.of(context, BuMotion.long),
                  curve: BuMotion.emphasizedDecelerate,
                  builder: (context, v, _) => Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: v,
                      heightFactor: 1,
                      child: DecoratedBox(decoration: BoxDecoration(color: fill, borderRadius: BuRadius.bPill)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (showVotes) ...[
            const SizedBox(height: 6),
            Text(score != null ? l.pollVotesWithScore('$votes', '$score') : l.pollVotes('$votes'),
                style: tx.labelMedium!.copyWith(color: t.mut, fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    );
  }
}

/// Kapsam adı, tonu ve simgesi (liste kartı ve detay çipleri için tek yer).
({String label, AnketTone tone, IconData icon}) pollScopeOf(BuildContext context, Poll p) {
  final l = context.l10n;
  return switch (p.scope.toUpperCase()) {
    'COMMUNITY' => (label: l.anketScopeClub, tone: AnketTone.club(context), icon: LucideIcons.users),
    'MENU' => (label: l.anketScopeMenu, tone: AnketTone.meal(context), icon: LucideIcons.utensils),
    _ => (label: l.anketScopeGlobal, tone: AnketTone.general(context), icon: LucideIcons.landmark),
  };
}

IconData pollTypeIcon(PollType t) => switch (t) {
      PollType.single => LucideIcons.circleDot,
      PollType.multi => LucideIcons.listChecks,
      PollType.rating => LucideIcons.star,
      PollType.ranked => LucideIcons.listOrdered,
    };

/// Kalan süre; bitiş yoksa/geçmişse null.
Duration? pollTimeLeft(Poll p, [DateTime? now]) {
  final c = p.closesAt == null ? null : DateTime.tryParse(p.closesAt!);
  if (c == null) return null;
  final d = c.difference(now ?? DateTime.now());
  return d.isNegative ? null : d;
}

/// Liste kartı (tasarım 31): kapsam/tür/gizli oy çipleri, durum hapı, başlık, açıklama, kalan süre · katılım ve eylem düğmesi.
/// Kapanan kartta sonuç özeti (en çok oy alan seçenek ya da ortalama puan) gösterilir.
class PollCard extends StatelessWidget {
  const PollCard({super.key, required this.poll, required this.onTap, this.reviewCta = false});

  final Poll poll;
  final VoidCallback onTap;

  /// true ise oy verilmiş açık kartta "Oyu incele" düğmesi görünür (Katıldıklarım bloğu).
  final bool reviewCta;

  /// Açılıştan bitişe geçen süre oranı (0-1); tarih yoksa/kapalıysa null.
  static double? elapsedFraction(Poll p, [DateTime? now]) {
    final a = p.opensAt == null ? null : DateTime.tryParse(p.opensAt!);
    final b = p.closesAt == null ? null : DateTime.tryParse(p.closesAt!);
    if (a == null || b == null || !b.isAfter(a)) return null;
    final n = now ?? DateTime.now();
    return (n.difference(a).inSeconds / b.difference(a).inSeconds).clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final closed = poll.isClosed();
    final left = closed ? null : pollTimeLeft(poll);
    final rem = pollRemaining(poll.closesAt, null, l);
    final urgent = left != null && left < const Duration(days: 3);
    final soon = left != null && left < const Duration(days: 1);
    final scope = pollScopeOf(context, poll);
    final canAct = !closed && !poll.voted && poll.canVote && !poll.notOpenYet;
    final timeColor = closed ? t.mut : (urgent ? t.pr : t.mut);
    final meta = tx.labelLarge!.copyWith(color: t.mut, fontWeight: FontWeight.w500);
    final statusLabel = closed ? l.pollClosedBadge : (poll.voted ? l.pollVotedBadge : (soon ? l.p13PollClosingSoon : null));
    final summary = closed ? PollResultSummary.of(poll) : null;
    final count = poll.totalVotes ?? poll.turnoutVoted;
    return Semantics(
      button: true,
      label: '${l.pollSemPoll(poll.title)}${statusLabel == null ? '' : ', $statusLabel'}',
      excludeSemantics: true,
      onTap: onTap,
      child: BuCard(
        onTap: onTap,
        padding: const EdgeInsetsDirectional.all(16),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    AnketPill(scope.label, bg: scope.tone.bg, fg: scope.tone.fg, icon: scope.icon, small: true),
                    AnketPill(pollTypeLabel(l, poll.type), bg: t.sf2, fg: t.mut, small: true),
                    if (poll.anonymous) AnketPill(l.pollAnonymous, bg: t.sf2, fg: t.mut, icon: LucideIcons.lock, small: true),
                  ]),
                ),
                if (statusLabel != null) ...[
                  const SizedBox(width: 8),
                  if (closed)
                    _DotPill(label: statusLabel)
                  else if (poll.voted)
                    AnketPill(statusLabel, bg: t.sf2, fg: t.ink, icon: LucideIcons.circleCheck)
                  else
                    AnketPill(statusLabel, bg: t.soft, fg: t.onSoft, icon: LucideIcons.alarmClock),
                ],
              ]),
              const SizedBox(height: 12),
              Text(poll.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w800, fontSize: 17, height: 1.3)),
              if (poll.description != null) ...[
                const SizedBox(height: 6),
                Text(poll.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.45)),
              ],
              if (summary != null) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  _Meta(icon: LucideIcons.clock, text: l.pollEnded, style: meta, color: t.mut),
                  if (count != null) const _Bullet(),
                  if (count != null) _Meta(icon: LucideIcons.users, text: l.pollParticipants('$count'), style: meta, color: t.mut, strongNumber: true),
                ]),
                const SizedBox(height: 12),
                summary.build(context),
              ] else ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: Wrap(spacing: closed ? 10 : 14, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      if (rem != null)
                        _Meta(icon: LucideIcons.clock, text: closed ? l.pollEnded : rem, style: meta, color: timeColor, strong: urgent),
                      if (closed && rem != null && count != null) const _Bullet(),
                      if (count != null)
                        _Meta(icon: LucideIcons.users, text: l.pollParticipants('$count'), style: meta, color: t.mut, strongNumber: true),
                    ]),
                  ),
                  if (canAct) ...[
                    const SizedBox(width: 12),
                    _Cta(label: poll.type == PollType.rating ? l.p13PollRateCta : l.pollVote, rating: poll.type == PollType.rating),
                  ] else if (reviewCta && !closed && poll.voted) ...[
                    const SizedBox(width: 12),
                    _Cta(label: l.p13PollReview, rating: false, soft: true),
                  ],
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Kapanan kartın sonuç özeti: sonuç görünürse en çok oy alan seçenek (çubuk) ya da ortalama puan.
class PollResultSummary {
  const PollResultSummary._({this.topText, this.topPercent, this.average});

  final String? topText;
  final double? topPercent;
  final double? average;

  static PollResultSummary? of(Poll p) {
    if (!p.resultsVisible) return null;
    if (p.type == PollType.rating) {
      return p.average == null ? null : PollResultSummary._(average: p.average);
    }
    PollOption? top;
    var pct = 0.0;
    for (final o in p.options) {
      final v = p.percentOf(o);
      if (v > pct) {
        pct = v;
        top = o;
      }
    }
    return top == null ? null : PollResultSummary._(topText: top.text, topPercent: pct);
  }

  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    if (average != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 14, 12),
        decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          AnketIconTile(LucideIcons.chartColumn, bg: t.sf, fg: t.mut, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.p13PollAvgTitle, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
              Text(l.p13PollAvgOutOf(average!.toStringAsFixed(1)), style: tx.bodySmall!.copyWith(color: t.mut)),
            ]),
          ),
          const SizedBox(width: 8),
          PollMiniStars(average!),
        ]),
      );
    }
    final frac = ((topPercent ?? 0) / 100).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 14, 12),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ExcludeSemantics(child: Icon(LucideIcons.award, size: 18, color: t.pr)),
          const SizedBox(width: 8),
          Expanded(child: Text(topText!, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800))),
          const SizedBox(width: 8),
          Text('%${topPercent!.round()}', style: tx.titleSmall!.copyWith(color: t.pr, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BuRadius.bPill,
            child: ColoredBox(
              color: t.bd,
              child: SizedBox(
                height: 8,
                width: double.infinity,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(widthFactor: frac < .03 ? .03 : frac, heightFactor: 1, child: DecoratedBox(decoration: BoxDecoration(color: t.pr, borderRadius: BuRadius.bPill))),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(l.p13PollTopOption, style: tx.labelMedium!.copyWith(color: t.mut, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Salt okunur küçük yıldız dizisi (ortalama puan; yarım yıldız dahil), marka renginde.
class PollMiniStars extends StatelessWidget {
  const PollMiniStars(this.value, {super.key, this.size = 16});

  final double value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final v = (value * 2).round() / 2;
    return ExcludeSemantics(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++)
          if (v >= i - .5) Icon(v >= i ? Icons.star_rounded : Icons.star_half_rounded, size: size + 2, color: t.pr),
      ]),
    );
  }
}

/// Kapandı hapı: solda gri nokta.
class _DotPill extends StatelessWidget {
  const _DotPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bPill),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: t.mut, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: tx.labelMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Kart içi eylem görünümü ("Oy ver →" / "Puanla ★"); dokunmayı kartın kendisi alır.
class _Cta extends StatelessWidget {
  const _Cta({required this.label, required this.rating, this.soft = false});

  final String label;
  final bool rating;

  /// true: gri (ikincil) düğme görünümü.
  final bool soft;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return ExcludeSemantics(
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: soft ? t.sf2 : t.pr, borderRadius: BorderRadius.circular(14)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: tx.labelLarge!.copyWith(color: soft ? t.ink : t.onPr, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Icon(rating ? LucideIcons.star : buDirIcon(context, LucideIcons.arrowRight), size: 16, color: soft ? t.ink : t.onPr),
        ]),
      ),
    );
  }
}

/// Meta öğeleri arasındaki küçük nokta ayırıcı.
class _Bullet extends StatelessWidget {
  const _Bullet();

  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: Container(width: 4, height: 4, decoration: BoxDecoration(color: context.bu.mut.withValues(alpha: .6), shape: BoxShape.circle)));
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, required this.style, required this.color, this.strong = false, this.strongNumber = false});

  final IconData icon;
  final String text;
  final TextStyle style;
  final Color color;
  final bool strong;

  /// Sayıyı kalın yazar ("42 katılım" -> 42 kalın).
  final bool strongNumber;

  @override
  Widget build(BuildContext context) {
    final base = style.copyWith(color: color, fontWeight: strong ? FontWeight.w700 : style.fontWeight);
    Widget label = Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: base);
    if (strongNumber) {
      final m = RegExp(r'^(\D*)(\d[\d.,]*)(.*)$').firstMatch(text);
      if (m != null) {
        label = Text.rich(
          TextSpan(style: base, children: [
            TextSpan(text: m.group(1)),
            TextSpan(text: m.group(2), style: TextStyle(fontWeight: FontWeight.w800, color: context.bu.ink)),
            TextSpan(text: m.group(3)),
          ]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 6),
      Flexible(child: label),
    ]);
  }
}
