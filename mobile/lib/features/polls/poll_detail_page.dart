import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'anket_flat.dart';
import 'poll_api.dart';
import 'poll_models.dart';
import 'poll_parts.dart';

/// Anket detayı (Stitch v3 02/03): oylama (SINGLE/MULTI/RATING/RANKED), oy ver / değiştir / geri çek, sonuçlar.
/// Kartsız: başlık 24 sp/700 + "Kapsam · Tür · Gizli oy · Kalan süre"; seçenekler 56 dp beyaz satır (seçili `soft` + `pr`
/// 1.5 dp çerçeve); "Oy ver" içerikte, sonuçlar çubuk satırlarıdır.
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
      final inv = Theme.of(context).brightness == Brightness.light ? BuTokens.dark : BuTokens.light;
      BuToast.show(context, context.l10n.pollVoteRetracted,
          kind: BuToastKind.success, actionLabel: context.l10n.commonClose, actionColor: inv.tint(4).fg);
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
    final p = _poll;
    final state = p != null ? BuViewState.ready : (_error != null ? BuViewState.error : BuViewState.loading);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: BuPageScaffold(
        title: context.l10n.pollHeader,
        large: false,
        state: state,
        error: _error,
        onRetry: _load,
        onRefresh: _load,
        loading: const _DetailSkeleton(),
        bottomInset: 32,
        slivers: p == null ? const [] : [SliverToBoxAdapter(child: _isVoting(p) ? _votingContent(p) : _stateContent(p))],
      ),
    );
  }

  /// Başlık bloğu: 24 sp/700 başlık, "Kapsam · Tür · Gizli oy · Kalan süre" (muted), isteğe bağlı açıklama/menü satırı.
  Widget _header(Poll p, {required double top, bool rule = false}) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final closed = p.isClosed();
    final rem = closed ? l.pollEnded : pollRemaining(p.closesAt, null, l);
    final meta = [pollScopeOf(context, p).label, pollTypeLabel(l, p.type), if (p.anonymous) l.pollAnonymous, if (rem != null) rem].join(' · ');
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(kAnketPad, top, kAnketPad, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(header: true, child: Text(p.title, style: tx.headlineMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w700, letterSpacing: -.2, height: 1.25))),
        const SizedBox(height: 3),
        Text(meta, style: tx.bodySmall!.copyWith(color: t.mut, fontSize: 13, height: 1.4)),
        if (p.description != null) ...[
          const SizedBox(height: 10),
          Text(p.description!, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5)),
        ],
        if (p.menuItems.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(p.menuItems.join(' · '), style: tx.bodyMedium!.copyWith(color: t.ink, height: 1.5)),
        ],
        if (rule) const Padding(padding: EdgeInsets.only(top: 23), child: AnketRule(inset: false)),
      ]),
    );
  }

  Widget _mutedLine(String text, {TextAlign align = TextAlign.start, double top = 12}) => Padding(
        padding: EdgeInsets.only(top: top),
        child: SizedBox(
          width: double.infinity,
          child: Text(text, textAlign: align, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: context.bu.mut, fontSize: 13, height: 1.45)),
        ),
      );

  // ---------------------------------------------------------------------------------------------------------------
  // Oylama (02)

  Widget _votingContent(Poll p) {
    final l = context.l10n;
    final s = _sel!;
    final multi = p.type == PollType.multi;
    final ranked = p.type == PollType.ranked;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _header(p, top: 24, rule: true),
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 0, kAnketPad, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 12),
          if (p.voted) _mutedLine(l.p13PollEditMode, top: 0),
          if (multi)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(p.maxChoices != null ? l.pollHintMax('${p.maxChoices}') : l.pollHintMulti,
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(color: context.bu.mut, fontSize: 13, height: 1.45)),
                ),
                if (p.maxChoices != null) ...[
                  const SizedBox(width: 12),
                  Text(l.p13PollSelectedCount('${s.ids.length}', '${p.maxChoices}'),
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(color: context.bu.pr, fontSize: 13, fontWeight: FontWeight.w600, height: 1.45)),
                ],
              ]),
            ),
          if (ranked) _mutedLine(l.pollHintRanked, top: 12),
          const SizedBox(height: 12),
          ..._votingBody(p),
          const SizedBox(height: 24),
          BuButton(
            label: p.voted ? l.pollVoteUpdate : l.pollVote,
            busy: _busy,
            onPressed: s.canSubmit ? _submit : null,
          ),
          if (p.voted)
            Center(
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: context.bu.mut, minimumSize: const Size(48, 48)),
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _editing = false;
                          _resetSelection();
                        }),
                child: Text(l.pollCancel, style: Theme.of(context).textTheme.titleSmall!.copyWith(color: context.bu.mut, fontWeight: FontWeight.w600)),
              ),
            )
          else if (p.anonymous)
            _mutedLine(l.pollAnonymousSub, align: TextAlign.center, top: 8)
          else if (p.allowChangeVote)
            _mutedLine(l.p13PollChangeNote, align: TextAlign.center, top: 8),
          if (p.showResultsMode == 'AFTER_CLOSE') _mutedLine(l.pollResultsAfterClose, align: TextAlign.center, top: 6),
        ]),
      ),
    ]);
  }

  List<Widget> _votingBody(Poll p) {
    final s = _sel!;
    final l = context.l10n;
    final out = <Widget>[];
    if (p.type == PollType.rating) {
      out.add(_ratingBlock(s));
      return out;
    }
    for (var i = 0; i < p.options.length; i++) {
      final o = p.options[i];
      final ranked = p.type == PollType.ranked;
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: BuStaggerItem(
          index: i,
          child: _OptionTile(
            text: o.text,
            on: s.has(o.id),
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
      out.add(_mutedLine(l.p13PollRankReset, align: TextAlign.center, top: 0));
    }
    if (p.voted) out.add(_mutedLine(l.p13PollEditNote, top: 8));
    return out;
  }

  /// Puanlama: ortada 5 yıldız (48 dp dokunma), seçilen puanın sözel karşılığı ve ipucu. Kart/kutu yok.
  Widget _ratingBlock(PollSelection s) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final r = s.rating;
    final d = BuMotion.of(context, BuMotion.short);
    return Column(children: [
      const SizedBox(height: 12),
      Center(child: StarRating(value: r, size: 36, onChanged: (v) => setState(() => s.setRating(v)))),
      const SizedBox(height: 8),
      AnimatedSwitcher(
        duration: d,
        child: r == null
            ? SizedBox(key: const ValueKey('none'), height: 26, child: Center(child: Text(l.pollTapStar, style: tx.bodySmall!.copyWith(color: t.mut, fontSize: 13))))
            : SizedBox(
                key: ValueKey(r),
                height: 26,
                child: Center(child: Text('${l.pollStars('$r')} · ${_rateWord(r)}', style: tx.titleSmall!.copyWith(color: t.pr, fontWeight: FontWeight.w600))),
              ),
      ),
      const SizedBox(height: 8),
    ]);
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

  // ---------------------------------------------------------------------------------------------------------------
  // Durumlar ve sonuçlar (03)

  Widget _stateContent(Poll p) {
    final l = context.l10n;
    final closed = p.isClosed();
    final results = p.showResults();
    // Engel/durum notu: yetki yok, oy değiştirilemez, kapandı (sonuç yoksa), henüz açılmadı.
    final String? note = !closed && p.notOpenYet
        ? l.pollBlockedNotOpen
        : !closed && !p.voted && !p.canVote
            ? pollBlockedText(p.voteBlockedReason, l)
            : !closed && p.voted && !p.allowChangeVote
                ? pollBlockedText('ALREADY_VOTED', l)
                : closed && !results
                    ? l.pollBlockedClosed
                    : null;
    final amber = !closed && (p.notOpenYet || (!p.voted && !p.canVote));
    final Widget body;
    if (!closed && p.notOpenYet) {
      body = _notOpenView(p, note!);
    } else if (results) {
      body = _resultsView(p, note: note, amber: amber);
    } else {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(p, top: 8),
        if (note != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 20, kAnketPad, 0),
            child: amber ? AnketAmberNote(note) : Text(note, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: context.bu.mut, height: 1.45)),
          ),
        if (!closed && p.voted && p.canVote && !results && p.showResultsMode == 'AFTER_CLOSE')
          Padding(padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 0, kAnketPad, 0), child: _mutedLine(l.pollResultsAfterClose, top: 14)),
        ..._actions(p),
      ]);
    }
    return BuFadeThrough(child: KeyedSubtree(key: ValueKey('${results}_${p.voted}_$closed'), child: body));
  }

  /// Henüz açılmamış anket: amber not, pasif seçenekler, pasif düğme.
  Widget _notOpenView(Poll p, String note) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _header(p, top: 8),
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 20, kAnketPad, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AnketAmberNote(note),
          const SizedBox(height: 20),
          if (p.type != PollType.rating)
            for (final o in p.options)
              Padding(padding: const EdgeInsets.only(bottom: 12), child: _OptionTile(text: o.text, on: false, onTap: null, square: p.type == PollType.multi)),
          const SizedBox(height: 12),
          BuButton(label: context.l10n.pollVote, onPressed: null),
        ]),
      ),
    ]);
  }

  /// Oyu değiştir (`pr` metin) + Oyumu geri çek (çerçeveli); yalnız açık ve oy verilmiş ankette.
  List<Widget> _actions(Poll p) {
    final tx = Theme.of(context).textTheme;
    final t = context.bu;
    final l = context.l10n;
    if (p.isClosed() || !p.voted || !p.allowChangeVote) return const [];
    return [
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 14, kAnketPad, 0),
        child: Column(children: [
          AnketOutlineButton(label: l.p68Retract, onPressed: _busy ? null : _retract),
          if (p.canVote)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: t.pr, minimumSize: const Size(48, 48)),
              onPressed: _busy ? null : () => setState(() => _editing = true),
              child: Text(l.pollChangeVote, style: tx.titleSmall!.copyWith(color: t.pr, fontWeight: FontWeight.w600)),
            ),
        ]),
      ),
    ];
  }

  /// Sonuç görünümü (oy verildi / kapandı): çubuk satırları, "N katılım · kalan süre" ve eylemler.
  Widget _resultsView(Poll p, {String? note, bool amber = false}) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final closed = p.isClosed();
    final count = p.turnoutVoted ?? p.totalVotes;
    var topId = -1;
    var topPct = 0.0;
    for (final o in p.options) {
      if (p.percentOf(o) > topPct) {
        topPct = p.percentOf(o);
        topId = o.id;
      }
    }
    final rem = closed ? l.pollEnded : pollRemaining(p.closesAt, null, l);
    final summary = [if (count != null) l.pollParticipants('$count'), if (rem != null) rem].join(' · ');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _header(p, top: 8),
      if (note != null && amber)
        Padding(padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 20, kAnketPad, 0), child: AnketAmberNote(note)),
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 24, kAnketPad, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (p.type == PollType.rating)
            ..._ratingResults(p)
          else
            for (final o in p.options)
              ResultBar(
                text: o.text,
                percent: p.percentOf(o),
                votes: p.countOf(o),
                mine: p.myOptionIds.contains(o.id),
                top: closed && o.id == topId,
              ),
          if (summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 34),
              child: Center(child: Text(summary, textAlign: TextAlign.center, style: tx.bodySmall!.copyWith(color: t.mut, fontSize: 13, height: 1.4))),
            ),
          if (note != null && !amber) _mutedLine(note, align: TextAlign.center, top: 4),
        ]),
      ),
      ..._actions(p),
    ]);
  }

  /// Puanlama sonucu: ortalama (büyük), yıldızlar, puan sayısı; altında 5→1 dağılım çubukları. Kart yok.
  List<Widget> _ratingResults(Poll p) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final avg = p.average;
    final n = p.ratingCount ?? p.participants;
    final isTr = Localizations.localeOf(context).languageCode == 'tr';
    final avgText = avg == null ? '-' : (isTr ? avg.toStringAsFixed(1).replaceAll('.', ',') : avg.toStringAsFixed(1));
    return [
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Text(avgText, style: tx.displaySmall!.copyWith(color: t.ink, fontWeight: FontWeight.w700, height: 1)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            StarRating(value: avg?.round(), size: 16, compact: true),
            Text(l.pollRatingCount('$n'), style: tx.bodySmall!.copyWith(color: t.mut, fontSize: 13)),
            if (p.myRating != null) Text(l.pollYourRating('${p.myRating}'), style: tx.bodySmall!.copyWith(color: t.pr, fontSize: 13, fontWeight: FontWeight.w500)),
          ]),
        ),
      ]),
      const SizedBox(height: 20),
      for (final o in p.options.reversed)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Semantics(
            label: l.pollSemPercent(l.pollStars(o.text), '${p.percentOf(o).round()}'),
            excludeSemantics: true,
            child: Row(children: [
              SizedBox(width: 16, child: Text(o.text, style: tx.bodySmall!.copyWith(color: t.mut, fontSize: 13))),
              const SizedBox(width: 12),
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
                            heightFactor: 1,
                            child: DecoratedBox(decoration: BoxDecoration(color: t.pr, borderRadius: BuRadius.bPill)),
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
    ];
  }
}

/// Seçenek satırı (oylama): 56 dp, r16, beyaz; seçilince `soft` zemin + `pr` 1.5 dp çerçeve + `pr` işaret.
/// SINGLE yuvarlak radyo, MULTI kare onay kutusu, RANKED sıra numarası ("n. tercih" alt satırı). [onTap] null = pasif.
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

  /// Oyu değiştirirken önceki seçimi belirten etiket.
  final bool previous;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final d = BuMotion.of(context, BuMotion.short);
    final enabled = onTap != null;
    return Semantics(
      inMutuallyExclusiveGroup: exclusive,
      checked: on,
      enabled: enabled,
      label: ranked && rank != null ? '$text, ${l.p13PollRankLabel('$rank')}' : text,
      excludeSemantics: true,
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : .5,
        child: BuPressable(
          scale: .985,
          child: AnimatedContainer(
            duration: d,
            curve: BuMotion.standard,
            decoration: BoxDecoration(
              color: on ? t.soft : t.sf,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: on ? t.pr : Colors.transparent, width: 1.5),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: enabled
                    ? () {
                        buHaptic(BuHaptic.selection);
                        onTap!();
                      }
                    : null,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: (ranked ? 60 : 56) - 3), // 1.5 dp çerçeve dahil toplam 56/60
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 8),
                    child: Row(children: [
                      if (ranked)
                        AnimatedContainer(
                          duration: d,
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: on ? t.pr : t.sf2, shape: BoxShape.circle),
                          child: on
                              ? Text('${rank ?? ''}', style: tx.titleSmall!.copyWith(color: t.onPr, fontWeight: FontWeight.w700))
                              : Icon(LucideIcons.plus, size: 16, color: t.mut),
                        )
                      else
                        AnketMarkFlat(on: on, square: square),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(text, style: tx.bodyLarge!.copyWith(fontSize: 16, color: t.ink, fontWeight: FontWeight.w400, height: 1.35)),
                          if (ranked) ...[
                            const SizedBox(height: 2),
                            Text(on && rank != null ? l.p13PollRankLabel('$rank') : l.p13PollRankTap,
                                style: tx.bodySmall!.copyWith(color: on ? t.pr : t.mut, fontSize: 12.5, fontWeight: FontWeight.w500)),
                          ],
                        ]),
                      ),
                      if (previous) ...[
                        const SizedBox(width: 8),
                        Text(l.p13PollPrevChoice, style: tx.bodySmall!.copyWith(color: t.mut, fontSize: 12)),
                      ],
                    ]),
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

/// Detay iskeleti: başlık + meta çubuğu, dört seçenek satırı.
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
        label: context.l10n.commonLoading,
        liveRegion: true,
        container: true,
        child: BuSkeletonScope(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 24, kAnketPad, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const BuSkeleton.line(width: 280, height: 26),
              const SizedBox(height: 10),
              const BuSkeleton.line(width: 200, height: 13),
              const SizedBox(height: 40),
              for (var i = 0; i < 4; i++) ...[
                const BuSkeleton(height: 56, radius: 16),
                const SizedBox(height: 12),
              ],
            ]),
          ),
        ),
      );
}
