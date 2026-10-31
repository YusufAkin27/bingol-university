import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'anket_flat.dart';
import 'anket_style.dart';
import 'poll_models.dart';

/// Yüzde metni (sayaç animasyonunun biçimleyicisi): `%48`.
String pollPercentText(int v) => '%$v';

/// 1-5 yıldız seçici. [value] null ise boş; [onChanged] null ise salt okunur.
/// Dokunulabilir yıldız en az 48 dp hedef; seçilen yıldız hafifçe büyüyüp titreşir (hareket azaltılmışsa yalnız renk).
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.value, this.onChanged, this.size = 36, this.activeColor, this.inactiveColor, this.compact = false});

  final int? value;
  final ValueChanged<int>? onChanged;
  final double size;

  /// Dolu/boş yıldız renkleri (varsayılan: altın / soluk gri).
  final Color? activeColor;
  final Color? inactiveColor;

  /// true: yıldızlar arası dar (sola yaslı satır); dokunma yüksekliği yine 44 dp.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final gold = activeColor ?? anketGoldOf(context);
    final cell = compact ? size + 6 : (onChanged == null ? size + 8 : (size + 8 < 48 ? 48.0 : size + 8));
    final cellH = compact ? 44.0 : cell;
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
                height: cellH,
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

/// Seçenek sonuç satırı (Stitch v3 03): ad solda, yüzde sağda (16 sp), 8 dp çubuk, altta "Senin oyun" (kendi seçim,
/// `pr`) ve sağda "N oy". Kendi seçim (ya da kapanmış ankette önde olan) çubuğu `pr`, diğerleri soluk iz tonu.
class ResultBar extends StatelessWidget {
  const ResultBar(
      {super.key, required this.text, required this.percent, required this.votes, this.mine = false, this.showVotes = true, this.score, this.top = false});

  final String text;
  final double percent;
  final int votes;
  final bool mine;
  final bool showVotes;

  /// Kapanmış ankette en çok oy alan seçenek: çubuk `pr`, ad kalın.
  final bool top;

  /// Sıralı seçimde Borda puanı.
  final int? score;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final pct = percent.round();
    final lead = top && percent > 0;
    final fill = (mine || lead) ? t.pr : Color.alphaBlend(t.mut.withValues(alpha: .18), t.sf2);
    final frac = (percent / 100).clamp(0, 1).toDouble();
    final name = tx.bodyLarge!.copyWith(fontSize: 16, color: t.ink, fontWeight: (mine || lead) ? FontWeight.w700 : FontWeight.w400, height: 1.3);
    final small = tx.bodySmall!.copyWith(color: t.mut, fontSize: 12, height: 1.35);
    return Semantics(
      label: [
        l.pollSemPercent(text, '$pct'),
        if (showVotes) l.pollVotes('$votes'),
        if (mine) l.pollSemMine,
        if (lead && !mine) l.p13Leading,
      ].join(', '),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 25.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(child: Text(text, style: name)),
              const SizedBox(width: 12),
              BuCountUp(value: pct, format: pollPercentText, style: name.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
            ]),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BuRadius.bPill,
              child: ColoredBox(
                color: t.sf2,
                child: SizedBox(
                  height: 8,
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
            if (showVotes || mine) ...[
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: mine
                      ? Row(children: [
                          ExcludeSemantics(child: Icon(Icons.check_circle_rounded, size: 14, color: t.pr)),
                          const SizedBox(width: 4),
                          Flexible(child: Text(l.p68MyVote, maxLines: 1, overflow: TextOverflow.ellipsis, style: small.copyWith(color: t.pr, fontWeight: FontWeight.w500))),
                        ])
                      : const SizedBox.shrink(),
                ),
                if (showVotes) Text(score != null ? l.pollVotesWithScore('$votes', '$score') : l.pollVotes('$votes'), style: small),
              ]),
            ],
          ],
        ),
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

/// Liste satırı (Stitch v3 01): kartsız; solda başlık 17 sp/600 + "Kapsam · Tür · Kalan süre" (muted), sağda "N katılım"
/// ve oy verilmişse `ok` yeşil "Oy verdiniz". Alt ayraç `bd` tam satır genişliği.
class PollCard extends StatelessWidget {
  const PollCard({super.key, required this.poll, required this.onTap, this.first = false});

  final Poll poll;
  final VoidCallback onTap;

  /// Listenin ilk satırı (üst boşluk +7 dp, referanstaki ilk satır payı).
  final bool first;

  /// Açılıştan bitişe geçen süre oranı (0-1); tarih yoksa/kapalıysa null.
  static double? elapsedFraction(Poll p, [DateTime? now]) {
    final a = p.opensAt == null ? null : DateTime.tryParse(p.opensAt!);
    final b = p.closesAt == null ? null : DateTime.tryParse(p.closesAt!);
    if (a == null || b == null || !b.isAfter(a)) return null;
    final n = now ?? DateTime.now();
    return (n.difference(a).inSeconds / b.difference(a).inSeconds).clamp(0.0, 1.0).toDouble();
  }

  /// "Yemek · Tek seçim · 2 gün kaldı" (kapanmışta "Sona erdi").
  static String metaLine(BuildContext context, Poll p) {
    final l = context.l10n;
    final rem = p.isClosed() ? l.pollEnded : pollRemaining(p.closesAt, null, l);
    return [pollScopeOf(context, p).label, pollTypeLabel(l, p.type), if (rem != null) rem].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final closed = poll.isClosed();
    final count = poll.totalVotes ?? poll.turnoutVoted;
    final votedMark = !closed && poll.voted;
    final status = closed ? l.pollClosedBadge : (poll.voted ? l.pollVotedBadge : null);
    final small = tx.bodySmall!.copyWith(color: t.mut, fontSize: 13, height: 1.3);
    return Semantics(
      button: true,
      label: '${l.pollSemPoll(poll.title)}${status == null ? '' : ', $status'}',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsetsDirectional.fromSTEB(kAnketPad, first ? 24 : 17, kAnketPad, 16),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.bd))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(poll.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: anketRowTitle(context)),
                const SizedBox(height: 4),
                Text(metaLine(context, poll), maxLines: 2, overflow: TextOverflow.ellipsis, style: anketMeta(context)),
              ]),
            ),
            if (count != null || votedMark) ...[
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                SizedBox(
                    height: 22,
                    child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: count == null ? null : Text(l.pollParticipants('$count'), maxLines: 1, style: small))),
                const SizedBox(height: 4),
                if (votedMark)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    ExcludeSemantics(child: Icon(LucideIcons.circleCheck, size: 16, color: t.ok)),
                    const SizedBox(width: 4),
                    Text(l.pollVotedBadge, maxLines: 1, style: small.copyWith(color: t.ok, fontWeight: FontWeight.w600)),
                  ]),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}
