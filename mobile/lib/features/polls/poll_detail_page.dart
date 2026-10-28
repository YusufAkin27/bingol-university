import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'anket_style.dart';
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

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  /// Sunucu durumuyla çelişen hatalarda (kapandı / zaten oy verdi / yetkisiz) ekranı tazeler.
  Future<void> _fail(Object e) async {
    _snack(pollErrorText(e, context.l10n));
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
      _snack(context.l10n.pollVoteSaved);
    } catch (e) {
      if (mounted) await _fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retract() async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(context.l10n.pollRetractTitle),
        content: Text(context.l10n.pollRetractBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(context.l10n.pollCancel)),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(context.l10n.pollRetractAction)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
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
      _snack(context.l10n.pollVoteRetracted);
    } catch (e) {
      if (mounted) await _fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggle(int id) {
    final ok = _sel!.toggle(id);
    if (!ok) _snack(context.l10n.pollMaxChoicesSnack('${_poll!.maxChoices}'));
    setState(() {});
  }

  bool _isVoting(Poll p) =>
      !p.isClosed() && !p.notOpenYet && p.canVote && (!p.voted || (_editing && p.allowChangeVote));

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final p = _poll;
    final voting = p != null && _isVoting(p);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: t.bg,
        body: Column(
          children: [
            BuHeader(
              title: voting || p == null || !p.showResults() ? context.l10n.pollHeader : context.l10n.anketResultsTitle,
              onBack: () => Navigator.pop(context, _changed),
              actions: [
                if (p != null && p.isClosed())
                  AnketPill(context.l10n.pollClosedBadge, bg: t.sf2, fg: t.mut)
                else if (p != null && p.anonymous)
                  AnketPill(context.l10n.pollAnonymous, bg: t.sf2, fg: t.ink, icon: LucideIcons.lock),
              ],
            ),
            Expanded(child: _body(t)),
          ],
        ),
        bottomNavigationBar: voting ? _voteBar(p) : null,
      ),
    );
  }

  /// Alt sabit çubuk (An2): gizli oy notu + "Oy ver".
  Widget _voteBar(Poll p) {
    final t = context.bu;
    final s = _sel!;
    return AnketBottomBar(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (p.anonymous)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(LucideIcons.lock, size: 14, color: t.mut),
              const SizedBox(width: 6),
              Flexible(
                  child: Text(context.l10n.pollSecretVote,
                      textAlign: TextAlign.center, style: anketText(12, FontWeight.w600, t.mut, height: 1.3))),
            ]),
          ),
        AnketPrimaryButton(
          label: p.voted ? context.l10n.pollVoteUpdate : context.l10n.pollVote,
          busy: _busy,
          onPressed: s.canSubmit ? _submit : null,
        ),
      ]),
    );
  }

  Widget _body(BuTokens t) {
    final p = _poll;
    if (p == null) {
      return _error != null ? ErrorView(error: _error!, onRetry: _load) : const LoadingView();
    }
    final l = context.l10n;
    final closed = p.isClosed();
    final rem = pollRemaining(p.closesAt, null, l);
    final voting = _isVoting(p);
    final showResults = !voting && p.showResults();
    final scope = switch (p.scope.toUpperCase()) {
      'COMMUNITY' => p.communityName ?? l.anketScopeClub,
      'MENU' => l.anketScopeMenu,
      _ => l.anketScopeGlobal,
    };
    final count = p.turnoutVoted ?? p.totalVotes;
    final meta = [scope, if (rem != null) rem, if (count != null) l.pollVotes('$count')];
    final hint = voting && (p.type == PollType.multi || p.type == PollType.ranked)
        ? (p.type == PollType.ranked
            ? l.pollHintRanked
            : (p.maxChoices != null ? l.pollHintMax('${p.maxChoices}') : l.pollHintMulti))
        : null;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 14, 20, voting ? 12 : 28),
        children: [
          if (_error != null) StaleBanner(text: l.pollStale),
          Text(meta.join(' · '), style: anketText(12, FontWeight.w600, t.mut)),
          const SizedBox(height: 6),
          Semantics(
              header: true, child: Text(p.title, style: anketText(20, FontWeight.w800, t.ink, height: 1.3, ls: -.3))),
          const SizedBox(height: 6),
          if (p.description != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(p.description!, style: anketText(13.5, FontWeight.w400, t.mut, height: 1.45)),
            ),
          Text(
            [pollTypeLabel(l, p.type), if (hint != null) hint].join(' · '),
            style: anketText(13, FontWeight.w400, t.mut, height: 1.45),
          ),
          const SizedBox(height: 16),
          if (closed) _notice(t, LucideIcons.clock, l.pollBlockedClosed),
          if (!closed && p.notOpenYet) _notice(t, LucideIcons.clock, l.pollBlockedNotOpen),
          if (!closed && !p.notOpenYet && !p.canVote)
            _notice(t, p.voted ? LucideIcons.check : LucideIcons.ban, pollBlockedText(p.voteBlockedReason, l)),
          if (p.menuItems.isNotEmpty) _notice(t, LucideIcons.utensils, p.menuItems.join(' · ')),
          if (voting) ..._votingBody(t, p),
          if (showResults) ..._resultsBody(t, p),
          if (!voting && !showResults && p.voted) _notice(t, LucideIcons.eyeOff, l.pollResultsAfterClose),
          const SizedBox(height: 12),
          Text(_participation(p), style: anketText(11.5, FontWeight.w500, t.mut)),
          if (!closed && p.voted && !_editing && p.allowChangeVote) ..._ownerActions(p),
        ],
      ),
    );
  }

  String _participation(Poll p) {
    final v = p.turnoutVoted ?? p.totalVotes;
    if (v == null) return '';
    final e = p.turnoutEligible;
    return e != null && e > 0 ? context.l10n.pollParticipationOf('$v', '$e') : context.l10n.pollParticipants('$v');
  }

  Widget _notice(BuTokens t, IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Icon(icon, size: 16, color: t.mut),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: anketText(13, FontWeight.w500, t.ink, height: 1.4))),
          ]),
        ),
      );

  List<Widget> _votingBody(BuTokens t, Poll p) {
    final s = _sel!;
    final out = <Widget>[];
    if (p.type == PollType.rating) {
      final r = s.rating;
      out.add(Container(
        padding: const EdgeInsets.fromLTRB(12, 22, 12, 18),
        decoration: anketCardDeco(t),
        child: Column(children: [
          Center(child: StarRating(value: r, size: 38, onChanged: (v) => setState(() => s.setRating(v)))),
          const SizedBox(height: 8),
          Text(r == null ? context.l10n.pollTapStar : '$r / 5',
              textAlign: TextAlign.center, style: anketText(13, FontWeight.w700, t.mut)),
        ]),
      ));
    } else {
      for (final o in p.options) {
        final on = s.has(o.id);
        final rank = p.type == PollType.ranked ? s.rankOf(o.id) : null;
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Semantics(
            inMutuallyExclusiveGroup: p.type == PollType.single,
            checked: on,
            label: o.text,
            excludeSemantics: true,
            onTap: () => _toggle(o.id),
            child: Material(
              color: on ? t.soft : t.sf,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: on ? t.pr : t.bd, width: 1.5),
              ),
              child: InkWell(
                customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onTap: () => _toggle(o.id),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(children: [
                      if (p.type == PollType.ranked)
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: on ? t.pr : t.sf2, shape: BoxShape.circle),
                          child: Text(rank == null ? '' : '$rank', style: anketText(12.5, FontWeight.w800, t.onPr)),
                        )
                      else
                        AnketMark(on: on, square: p.type != PollType.single),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(o.text,
                              style: anketText(14, FontWeight.w600, on ? t.pr : t.ink, height: 1.3))),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ));
      }
    }
    if (p.voted) {
      out.add(const SizedBox(height: 6));
      out.add(BuButton(
          label: context.l10n.pollCancel,
          kind: BuButtonKind.outline,
          onPressed: _busy
              ? null
              : () => setState(() {
                    _editing = false;
                    _resetSelection();
                  })));
    }
    return out;
  }

  List<Widget> _resultsBody(BuTokens t, Poll p) {
    final secret = p.anonymous && p.voted;
    final note = secret ? [const SizedBox(height: 14), _secretNote()] : <Widget>[];
    if (p.type == PollType.rating) {
      final avg = p.average;
      final n = p.ratingCount ?? p.participants;
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: anketCardDeco(t),
          child: Row(children: [
            SizedBox(
              width: 104,
              child: Column(children: [
                Text(avg == null ? '-' : avg.toStringAsFixed(1),
                    style: anketText(32, FontWeight.w800, t.ink, height: 1, ls: -1)),
                const SizedBox(height: 6),
                StarRating(value: avg?.round(), size: 12),
                const SizedBox(height: 4),
                Text(context.l10n.pollRatingCount('$n'), style: anketText(11.5, FontWeight.w500, t.mut)),
                if (p.myRating != null) ...[
                  const SizedBox(height: 4),
                  Text(context.l10n.pollYourRating('${p.myRating}'),
                      textAlign: TextAlign.center, style: anketText(11.5, FontWeight.w700, t.pr)),
                ],
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(children: [
                for (final o in p.options.reversed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Semantics(
                      label: context.l10n.pollSemPercent(context.l10n.pollStars(o.text), '${p.percentOf(o).round()}'),
                      excludeSemantics: true,
                      child: Row(children: [
                        SizedBox(width: 12, child: Text(o.text, style: anketText(11.5, FontWeight.w600, t.mut))),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              height: 8,
                              color: t.sf2,
                              alignment: AlignmentDirectional.centerStart,
                              child: FractionallySizedBox(
                                widthFactor: (p.percentOf(o) / 100).clamp(0, 1).toDouble(),
                                child: const ColoredBox(color: anketGold),
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
        ...note,
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
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: anketCardDeco(t),
        child: Column(children: [
          for (var i = 0; i < p.options.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
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
      ...note,
    ];
  }

  /// "Oyunuz gizli" uyarı kutusu (An3).
  Widget _secretNote() {
    final c = anketNoteColors(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.bd)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: Icon(LucideIcons.lock, size: 16, color: c.fg)),
        const SizedBox(width: 10),
        Expanded(child: Text(context.l10n.anketSecretNote, style: anketText(12.5, FontWeight.w500, c.fg, height: 1.45))),
      ]),
    );
  }

  List<Widget> _ownerActions(Poll p) => [
        const SizedBox(height: 16),
        if (p.canVote)
          BuButton(
            label: context.l10n.pollChangeVote,
            kind: BuButtonKind.soft,
            onPressed: _busy ? null : () => setState(() => _editing = true),
          ),
        ...[
          const SizedBox(height: 8),
          BuButton(label: context.l10n.pollRetractTitle, kind: BuButtonKind.outline, busy: _busy, onPressed: _busy ? null : _retract),
        ],
      ];
}
