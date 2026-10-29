import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'anket_style.dart';
import 'anket_widgets.dart';
import 'poll_api.dart';
import 'poll_models.dart';
import 'poll_parts.dart';

/// Anket detayı (tasarım An2/An3): seçim (SINGLE/MULTI/RATING/RANKED), oy ver / değiştir / geri çek, sonuçlar.
class PollDetailPage extends StatefulWidget {
  const PollDetailPage({super.key, required this.session, required this.pollId, this.initial});

  final Session session;
  final int pollId;
  final Poll? initial;

  @override
  State<PollDetailPage> createState() => _PollDetailPageState();
}

class _PollDetailPageState extends State<PollDetailPage> {
  late final PollApi _api = PollApi(widget.session);
  Poll? _poll;
  Object? _error;
  bool _busy = false;
  bool _changed = false; // çağıran listeyi tazelesin
  bool _editing = false; // oylandıktan sonra "Oyu değiştir"
  PollSelection? _sel;

  @override
  void initState() {
    super.initState();
    _poll = widget.initial;
    if (_poll != null) _resetSelection();
    _load();
  }

  void _resetSelection() {
    final p = _poll!;
    _sel = PollSelection(p.type, initial: p.myOptionIds, maxChoices: p.maxChoices)..rating = p.myRating;
  }

  Future<void> _load() async {
    try {
      final p = await _api.get(widget.pollId);
      if (!mounted) return;
      setState(() {
        _poll = p;
        _error = null;
        _editing = false;
        _resetSelection();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _toast(String text, [BuToastKind kind = BuToastKind.info]) => BuToast.show(context, text, kind: kind);

  /// Sunucu durumuyla çelişen hatalarda (kapandı / zaten oy verdi / yetkisiz) ekranı tazeler.
  Future<void> _fail(Object e) async {
    _toast(pollErrorText(e, context.l10n), BuToastKind.error);
    if (e is ApiError && pollStateErrors.contains(e.code)) {
      await _load();
    }
  }

  Future<void> _submit() async {
    final s = _sel;
    if (s == null || !s.canSubmit || _busy) return;
    setState(() => _busy = true);
    try {
      final p = await _api.vote(widget.pollId, s);
      if (!mounted) return;
      setState(() {
        _poll = p;
        _changed = true;
        _editing = false;
        _resetSelection();
      });
      buHaptic(BuHaptic.medium);
      _toast(context.l10n.pollVoteSaved, BuToastKind.success);
    } catch (e) {
      if (mounted) await _fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retract() async {
    if (_busy) return;
    final l = context.l10n;
    final ok = await BuDialog.confirm(
      context,
      title: l.pollRetractTitle,
      message: l.pollRetractBody,
      confirmLabel: l.pollRetractAction,
      cancelLabel: l.pollCancel,
      destructive: true,
      icon: LucideIcons.undo2,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final p = await _api.retract(widget.pollId);
      if (!mounted) return;
      setState(() {
        _poll = p;
        _changed = true;
        _editing = false;
        _resetSelection();
      });
      _toast(context.l10n.pollVoteRetracted, BuToastKind.success);
    } catch (e) {
      if (mounted) await _fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggle(int id) {
    final ok = _sel!.toggle(id);
    if (!ok) {
      _toast(context.l10n.pollMaxChoicesSnack('${_poll!.maxChoices}'), BuToastKind.warning);
    } else {
      buHaptic(BuHaptic.selection);
    }
    setState(() {});
  }

  bool _isVoting(Poll p) =>
      !p.isClosed() && !p.notOpenYet && p.canVote && (!p.voted || (_editing && p.allowChangeVote));

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final p = _poll;
    final voting = p != null && _isVoting(p);
    final state = p != null ? BuViewState.ready : (_error != null ? BuViewState.error : BuViewState.loading);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: BuPageScaffold(
        title: voting || p == null || !p.showResults() ? l.pollHeader : l.anketResultsTitle,
        large: false,
        state: state,
        error: _error,
        onRetry: _load,
        onRefresh: _load,
        loading: const _DetailSkeleton(),
        banner: p != null && _error != null ? BuOfflineBanner(message: l.pollStale, showCachedHint: false) : null,
        actions: [
          if (p != null && p.isClosed())
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: Center(child: AnketPill(l.pollClosedBadge, bg: t.sf2, fg: t.mut, icon: LucideIcons.lock)),
            ),
        ],
        bottomInset: voting ? 16 : 32,
        bottomBar: voting ? _voteBar(p) : null,
        slivers: p == null ? const [] : [SliverToBoxAdapter(child: _content(t, p))],
      ),
    );
  }

  /// Alt sabit çubuk (tasarım 32): "Oy ver" / "Oyu güncelle", altında not ya da "Vazgeç".
  Widget _voteBar(Poll p) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final s = _sel!;
    return AnketBottomBar(
      solid: true,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        BuButton(
          label: p.voted ? l.pollVoteUpdate : l.pollVote,
          icon: LucideIcons.vote,
          busy: _busy,
          onPressed: s.canSubmit ? _submit : null,
        ),
        if (p.voted)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: t.ink, minimumSize: const Size(0, 48)),
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _editing = false;
                        _resetSelection();
                      }),
              child: Text(l.pollCancel, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700)),
            ),
          )
        else if (p.allowChangeVote)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ExcludeSemantics(child: Icon(LucideIcons.info, size: 14, color: t.mut)),
              const SizedBox(width: 6),
              Flexible(child: Text(l.p13PollChangeNote, textAlign: TextAlign.center, style: tx.labelMedium!.copyWith(color: t.mut, height: 1.3))),
            ]),
          ),
      ]),
    );
  }

  Widget _content(BuTokens t, Poll p) {
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final closed = p.isClosed();
    final rem = pollRemaining(p.closesAt, null, l);
    final left = closed ? null : pollTimeLeft(p);
    final urgent = left != null && left < const Duration(days: 3);
    final voting = _isVoting(p);
    final showResults = !voting && p.showResults();
    final scope = pollScopeOf(context, p);
    final count = p.turnoutVoted ?? p.totalVotes;
    final multi = p.type == PollType.multi;
    final mode = voting ? 'v' : (showResults ? 'r' : 'n');
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (voting && p.voted) AnketPill(l.p13PollEditMode, bg: t.sf2, fg: t.ink, icon: LucideIcons.squarePen),
            AnketPill(scope.label, bg: scope.tone.bg, fg: scope.tone.fg, icon: scope.icon),
            AnketPill(pollTypeLabel(l, p.type), bg: t.soft, fg: t.onSoft, icon: pollTypeIcon(p.type)),
            if (p.anonymous) AnketPill(l.pollAnonymous, bg: t.sf2, fg: t.mut, icon: LucideIcons.lock),
          ]),
          const SizedBox(height: 12),
          BuCard(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 18),
            child: SizedBox(
              width: double.infinity,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if ((rem != null && !closed) || count != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Wrap(spacing: 14, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      if (rem != null && !closed)
                        _MetaLine(icon: LucideIcons.clock, text: rem, color: urgent ? t.pr : t.mut, strong: urgent),
                      if (count != null) _MetaLine(icon: LucideIcons.users, text: l.pollParticipants('$count'), color: t.mut),
                    ]),
                  ),
                Semantics(header: true, child: Text(p.title, style: tx.headlineSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800, height: 1.3))),
                if (p.description != null) ...[
                  const SizedBox(height: 10),
                  Text(p.description!, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5)),
                ],
              ]),
            ),
          ),
          if (p.anonymous) _gap(AnketHintBox(icon: LucideIcons.shieldCheck, title: l.pollSecretVote, body: l.p13PollSecretBody), top: 12),
          const SizedBox(height: 12),
          if (closed) _gap(AnketNotice(icon: LucideIcons.clock, text: l.pollBlockedClosed)),
          if (!closed && p.notOpenYet) _gap(AnketNotice(icon: LucideIcons.clock, text: l.pollBlockedNotOpen)),
          if (!closed && !p.notOpenYet && !p.canVote)
            _gap(AnketNotice(icon: p.voted ? LucideIcons.check : LucideIcons.ban, text: pollBlockedText(p.voteBlockedReason, l))),
          if (p.menuItems.isNotEmpty) _gap(AnketNotice(icon: LucideIcons.utensils, text: p.menuItems.join(' · '), tone: AnketTone.meal(context))),
          if (voting && multi)
            _gap(AnketHintBox(
              icon: LucideIcons.info,
              iconColor: t.pr,
              title: p.maxChoices != null ? l.pollHintMax('${p.maxChoices}') : l.pollHintMulti,
              trailing: p.maxChoices != null ? l.p13PollSelectedCount('${_sel!.ids.length}', '${p.maxChoices}') : null,
            )),
          if (voting && p.type == PollType.ranked)
            _gap(AnketHintBox(icon: LucideIcons.pointer, title: l.p13PollHowTo, body: l.pollHintRanked)),
          BuFadeThrough(
            child: KeyedSubtree(
              key: ValueKey(mode),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (voting) ..._votingBody(t, p),
                if (showResults) ..._resultsBody(t, p),
                if (!voting && !showResults && p.voted) AnketNotice(icon: LucideIcons.eyeOff, text: l.pollResultsAfterClose),
              ]),
            ),
          ),
          if (!voting) ...[const SizedBox(height: 16), _turnout(t, p)],
          if (!closed && p.voted && !_editing && p.allowChangeVote) ..._ownerActions(p),
        ],
      ),
    );
  }

  Widget _gap(Widget w, {double top = 0}) => Padding(padding: EdgeInsets.only(top: top, bottom: 12), child: w);

  /// Katılım özeti: "29 / 40 katılım" + doluluk çubuğu (uygun seçmen sayısı biliniyorsa).
  Widget _turnout(BuTokens t, Poll p) {
    final v = p.turnoutVoted ?? p.totalVotes;
    if (v == null) return const SizedBox.shrink();
    final tx = Theme.of(context).textTheme;
    final e = p.turnoutEligible;
    final text = e != null && e > 0 ? context.l10n.pollParticipationOf('$v', '$e') : context.l10n.pollParticipants('$v');
    final frac = e != null && e > 0 ? (v / e).clamp(0, 1).toDouble() : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(LucideIcons.users, size: 15, color: t.mut),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: tx.labelLarge!.copyWith(color: t.mut, fontWeight: FontWeight.w600))),
      ]),
      if (frac != null) ...[
        const SizedBox(height: 8),
        ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BuRadius.bPill,
            child: ColoredBox(
              color: t.sf2,
              child: SizedBox(
                height: 6,
                width: double.infinity,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: frac),
                  duration: BuMotion.of(context, BuMotion.long),
                  curve: BuMotion.emphasizedDecelerate,
                  builder: (context, v, _) => Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: v < .02 ? .02 : v,
                      child: DecoratedBox(decoration: BoxDecoration(color: t.mut.withValues(alpha: .55), borderRadius: BuRadius.bPill)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ]);
  }

  List<Widget> _votingBody(BuTokens t, Poll p) {
    final s = _sel!;
    final l = context.l10n;
    final out = <Widget>[];
    if (p.type == PollType.rating) {
      out.add(_ratingCard(t, s));
    } else {
      for (var i = 0; i < p.options.length; i++) {
        final o = p.options[i];
        final on = s.has(o.id);
        final ranked = p.type == PollType.ranked;
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: BuStaggerItem(
            index: i,
            child: _OptionTile(
              text: o.text,
              on: on,
              rank: ranked ? s.rankOf(o.id) : null,
              ranked: ranked,
              square: p.type == PollType.multi,
              exclusive: p.type == PollType.single,
              previous: p.voted && p.myOptionIds.contains(o.id),
              onTap: () => _toggle(o.id),
            ),
          ),
        ));
      }
      if (p.type == PollType.ranked) {
        out.add(Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            ExcludeSemantics(child: Icon(LucideIcons.info, size: 14, color: t.mut)),
            const SizedBox(width: 6),
            Flexible(child: Text(l.p13PollRankReset, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: t.mut, height: 1.3))),
          ]),
        ));
      }
    }
    if (p.voted) {
      out.add(const SizedBox(height: 4));
      out.add(AnketHintBox(icon: LucideIcons.info, body: l.p13PollEditNote));
    }
    return out;
  }

  /// Puanlama kartı: başlık, 5 yıldız karosu, seçilen puan + sözel karşılığı, 5 parçalı ölçek.
  Widget _ratingCard(BuTokens t, PollSelection s) {
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final r = s.rating;
    final d = BuMotion.of(context, BuMotion.short);
    return BuCard(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: Column(children: [
          Row(children: [
            ExcludeSemantics(child: Icon(LucideIcons.star, size: 18, color: t.pr)),
            const SizedBox(width: 8),
            Expanded(child: Text(l.p13PollYourScore, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800))),
          ]),
          Divider(height: 24, color: t.bd),
          Row(children: [
            for (var i = 1; i <= 5; i++) ...[
              if (i > 1) const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  button: true,
                  selected: r == i,
                  label: l.pollStars('$i'),
                  excludeSemantics: true,
                  onTap: () => setState(() => s.setRating(i)),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      buHaptic(BuHaptic.selection);
                      setState(() => s.setRating(i));
                    },
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: AnimatedContainer(
                        duration: d,
                        curve: BuMotion.standard,
                        decoration: BoxDecoration(color: (r ?? 0) >= i ? t.soft : t.sf2, borderRadius: BorderRadius.circular(16)),
                        child: Center(
                          child: AnimatedScale(
                            scale: r == i ? 1.12 : 1,
                            duration: d,
                            curve: Curves.easeOutBack,
                            child: Icon((r ?? 0) >= i ? Icons.star_rounded : Icons.star_outline_rounded, size: 32, color: (r ?? 0) >= i ? t.pr : t.mut),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: d,
            child: r == null
                ? const SizedBox(key: ValueKey('none'), height: 4)
                : Column(key: ValueKey(r), mainAxisSize: MainAxisSize.min, children: [
                    Text(l.pollStars('$r'), style: tx.headlineSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(_rateWord(r), style: tx.titleSmall!.copyWith(color: t.pr, fontWeight: FontWeight.w700)),
                  ]),
          ),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            ExcludeSemantics(child: Icon(LucideIcons.pointer, size: 15, color: t.mut)),
            const SizedBox(width: 6),
            Flexible(child: Text(l.pollTapStar, style: tx.bodySmall!.copyWith(color: t.mut))),
          ]),
          Divider(height: 28, color: t.bd),
          ExcludeSemantics(
            child: Row(children: [
              for (var i = 1; i <= 5; i++) ...[
                if (i > 1) const SizedBox(width: 3),
                Expanded(
                  child: AnimatedContainer(
                    duration: d,
                    height: 6,
                    decoration: BoxDecoration(color: (r ?? 0) >= i ? t.pr : t.sf2, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Flexible(child: Text('1 - ${l.p13Rate1}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelSmall!.copyWith(color: t.mut, fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            Flexible(child: Text('5 - ${l.p13Rate5}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelSmall!.copyWith(color: t.mut, fontWeight: FontWeight.w700))),
          ]),
        ]),
      ),
    );
  }

  String _rateWord(int r) {
    final l = context.l10n;
    return switch (r) {
      1 => l.p13Rate1,
      2 => l.p13Rate2,
      3 => l.p13Rate3,
      4 => l.p13Rate4,
      _ => l.p13Rate5,
    };
  }

  List<Widget> _resultsBody(BuTokens t, Poll p) {
    final tx = Theme.of(context).textTheme;
    if (p.type == PollType.rating) {
      final avg = p.average;
      final n = p.ratingCount ?? p.participants;
      final gold = anketGoldOf(context);
      return [
        BuCard(
          padding: const EdgeInsetsDirectional.all(18),
          child: Row(children: [
            SizedBox(
              width: 108,
              child: Column(children: [
                Text(avg == null ? '-' : avg.toStringAsFixed(1),
                    style: tx.displaySmall!.copyWith(color: t.ink, height: 1)),
                const SizedBox(height: 8),
                StarRating(value: avg?.round(), size: 13),
                const SizedBox(height: 6),
                Text(context.l10n.pollRatingCount('$n'), style: tx.labelMedium!.copyWith(color: t.mut)),
                if (p.myRating != null) ...[
                  const SizedBox(height: 8),
                  Text(context.l10n.pollYourRating('${p.myRating}'),
                      textAlign: TextAlign.center, style: tx.labelMedium!.copyWith(color: t.pr, fontWeight: FontWeight.w700)),
                ],
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(children: [
                for (final o in p.options.reversed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Semantics(
                      label: context.l10n.pollSemPercent(context.l10n.pollStars(o.text), '${p.percentOf(o).round()}'),
                      excludeSemantics: true,
                      child: Row(children: [
                        SizedBox(width: 16, child: Text(o.text, style: tx.labelMedium!.copyWith(color: t.mut))),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BuRadius.bPill,
                            child: ColoredBox(
                              color: t.sf2,
                              child: SizedBox(
                                height: 8,
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: (p.percentOf(o) / 100).clamp(0, 1).toDouble()),
                                  duration: BuMotion.of(context, BuMotion.long),
                                  curve: BuMotion.emphasizedDecelerate,
                                  builder: (context, v, _) => Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: FractionallySizedBox(
                                      widthFactor: v,
                                      child: DecoratedBox(decoration: BoxDecoration(color: gold, borderRadius: BuRadius.bPill)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      ];
    }
    var topId = -1;
    var topPct = 0.0;
    for (final o in p.options) {
      if (p.percentOf(o) > topPct) {
        topPct = p.percentOf(o);
        topId = o.id;
      }
    }
    return [
      BuCard(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 18, vertical: 20),
        child: Column(children: [
          for (var i = 0; i < p.options.length; i++) ...[
            if (i > 0) const SizedBox(height: 18),
            ResultBar(
              text: p.options[i].text,
              percent: p.percentOf(p.options[i]),
              votes: p.countOf(p.options[i]),
              mine: p.myOptionIds.contains(p.options[i].id),
              top: p.options[i].id == topId,
              score: p.resultOf(p.options[i])?.score,
            ),
          ],
        ]),
      ),
    ];
  }

  List<Widget> _ownerActions(Poll p) => [
        const SizedBox(height: 20),
        if (p.canVote)
          BuButton(
            label: context.l10n.pollChangeVote,
            icon: LucideIcons.pencil,
            kind: BuButtonKind.soft,
            onPressed: _busy ? null : () => setState(() => _editing = true),
          ),
        const SizedBox(height: 8),
        BuButton(
            label: context.l10n.pollRetractTitle,
            icon: LucideIcons.undo2,
            kind: BuButtonKind.outline,
            busy: _busy,
            onPressed: _busy ? null : _retract),
      ];
}

/// Başlık kartındaki meta satırı (simge + metin).
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text, required this.color, this.strong = false});

  final IconData icon;
  final String text;
  final Color color;
  final bool strong;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        ExcludeSemantics(child: Icon(icon, size: 16, color: color)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge!.copyWith(color: color, fontWeight: strong ? FontWeight.w700 : FontWeight.w600)),
        ),
      ]);
}

/// Seçenek satırı (oylama): seçilince yumuşak marka zemini, işaret yaylanarak dolar.
/// SINGLE yuvarlak radyo, MULTI kare onay kutusu, RANKED sıra numarası ("n. tercih" alt satırı).
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.text,
    required this.on,
    required this.onTap,
    this.rank,
    this.ranked = false,
    this.square = false,
    this.exclusive = false,
    this.previous = false,
  });

  final String text;
  final bool on;
  final int? rank;
  final bool ranked;
  final bool square;
  final bool exclusive;

  /// Oyu değiştirirken önceki seçimi belirten rozet.
  final bool previous;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final d = BuMotion.of(context, BuMotion.short);
    return Semantics(
      inMutuallyExclusiveGroup: exclusive,
      checked: on,
      label: ranked && rank != null ? '$text, ${l.p13PollRankLabel('$rank')}' : text,
      excludeSemantics: true,
      onTap: onTap,
      child: BuPressable(
        scale: .985,
        child: AnimatedContainer(
          duration: d,
          curve: BuMotion.standard,
          decoration: BoxDecoration(
            color: on ? t.soft : t.sf,
            borderRadius: BuRadius.bMd,
            border: Border.all(color: on ? t.pr.withValues(alpha: .18) : t.bd.withValues(alpha: .7)),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BuRadius.bMd,
              onTap: onTap,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: ranked ? 64 : 60),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    if (ranked)
                      AnimatedContainer(
                        duration: d,
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: on ? t.pr : t.sf2, shape: BoxShape.circle),
                        child: on
                            ? Text('${rank ?? ''}', style: tx.titleSmall!.copyWith(color: t.onPr, fontWeight: FontWeight.w800))
                            : Icon(LucideIcons.plus, size: 18, color: t.mut),
                      )
                    else
                      AnketMark(on: on, square: square),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(text, style: tx.titleSmall!.copyWith(color: on ? t.onSoft : t.ink, height: 1.3, fontWeight: FontWeight.w800)),
                        if (ranked) ...[
                          const SizedBox(height: 2),
                          Text(on && rank != null ? l.p13PollRankLabel('$rank') : l.p13PollRankTap,
                              style: tx.labelMedium!.copyWith(color: on ? t.pr : t.mut, fontWeight: FontWeight.w600)),
                        ],
                      ]),
                    ),
                    if (previous) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: t.sf, borderRadius: BuRadius.bPill),
                        child: Text(l.p13PollPrevChoice, style: tx.labelSmall!.copyWith(color: t.onSoft, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Detay iskeleti: rozet satırı, başlık kartı, dört seçenek.
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
        label: context.l10n.commonLoading,
        liveRegion: true,
        container: true,
        child: BuSkeletonScope(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                BuSkeleton(width: 84, height: 26, radius: 13),
                SizedBox(width: 8),
                BuSkeleton(width: 96, height: 26, radius: 13),
                SizedBox(width: 8),
                BuSkeleton(width: 72, height: 26, radius: 13),
              ]),
              const SizedBox(height: 12),
              const BuSkeleton(height: 120, radius: 20),
              const SizedBox(height: 16),
              for (var i = 0; i < 4; i++) ...[
                const BuSkeleton(height: 60, radius: 16),
                const SizedBox(height: 10),
              ],
            ]),
          ),
        ),
      );
}
