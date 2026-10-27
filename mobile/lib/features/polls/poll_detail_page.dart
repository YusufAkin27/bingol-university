import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'poll_api.dart';
import 'poll_models.dart';
import 'poll_parts.dart';

/// Anket detayı: seçim (SINGLE/MULTI/RATING), oy ver / değiştir / geri çek, sonuçlar.
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
    _snack(pollErrorText(e));
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
      _snack('Oyunuz kaydedildi.');
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
        title: const Text('Oyu geri çek'),
        content: const Text('Oyunuz silinecek. Devam edilsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Geri çek')),
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
      _snack('Oyunuz geri çekildi.');
    } catch (e) {
      if (mounted) await _fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggle(int id) {
    final ok = _sel!.toggle(id);
    if (!ok) _snack('En fazla ${_poll!.maxChoices} seçenek işaretleyebilirsiniz.');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: t.bg,
        body: Column(
          children: [
            BuHeader(title: 'Anket', onBack: () => Navigator.pop(context, _changed)),
            Expanded(child: _body(t)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuTokens t) {
    final p = _poll;
    if (p == null) {
      return _error != null ? ErrorView(error: _error!, onRetry: _load) : const LoadingView();
    }
    final closed = p.isClosed();
    final rem = pollRemaining(p.closesAt);
    final voting = !closed && !p.notOpenYet && p.canVote && (!p.voted || (_editing && p.allowChangeVote));
    final showResults = !voting && p.showResults();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          if (_error != null) const StaleBanner(text: 'Güncellenemedi; son bilinen veri gösteriliyor.'),
          if (p.communityName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Icon(LucideIcons.users, size: 13, color: t.mut),
                const SizedBox(width: 6),
                Flexible(child: Text(p.communityName!, style: BuType.label.copyWith(color: t.mut))),
              ]),
            ),
          Semantics(header: true, child: Text(p.title, style: BuType.title.copyWith(color: t.ink))),
          if (p.description != null) ...[
            const SizedBox(height: 8),
            Text(p.description!, style: BuType.body.copyWith(color: t.ink)),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            BuBadge(switch (p.type) {
              PollType.single => 'Tek seçim',
              PollType.multi => 'Çoklu seçim',
              PollType.rating => 'Puanlama',
              PollType.ranked => 'Sıralı seçim',
            }, soft: true),
            if (rem != null) BuBadge(closed ? 'Kapandı' : rem, soft: !closed),
          ]),
          if (p.anonymous) ...[
            const SizedBox(height: 10),
            Row(children: [
              Icon(LucideIcons.lock, size: 14, color: t.mut),
              const SizedBox(width: 6),
              Flexible(child: Text('Oyunuz gizlidir', style: BuType.label.copyWith(color: t.mut))),
            ]),
          ],
          const SizedBox(height: 16),
          if (closed) _notice(t, LucideIcons.clock, 'Bu anket kapandı. Oy verilemez.'),
          if (!closed && p.notOpenYet) _notice(t, LucideIcons.clock, 'Bu anket henüz açılmadı.'),
          if (!closed && !p.notOpenYet && !p.canVote)
            _notice(t, p.voted ? LucideIcons.check : LucideIcons.ban, pollBlockedText(p.voteBlockedReason)),
          if (p.menuItems.isNotEmpty) _notice(t, LucideIcons.utensils, p.menuItems.join(' · ')),
          if (voting) ..._votingBody(t, p),
          if (showResults) ..._resultsBody(t, p),
          if (!voting && !showResults && p.voted)
            _notice(t, LucideIcons.eyeOff, 'Sonuçlar anket kapanınca görünecek.'),
          const SizedBox(height: 12),
          Text(_participation(p), style: BuType.caption.copyWith(color: t.mut)),
          if (!closed && p.voted && !_editing && p.allowChangeVote) ..._ownerActions(p),
        ],
      ),
    );
  }

  String _participation(Poll p) {
    final v = p.turnoutVoted ?? p.totalVotes;
    if (v == null) return '';
    final e = p.turnoutEligible;
    return e != null && e > 0 ? '$v / $e katılım' : '$v katılım';
  }

  Widget _notice(BuTokens t, IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Icon(icon, size: 16, color: t.mut),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: BuType.body.copyWith(color: t.ink))),
          ]),
        ),
      );

  List<Widget> _votingBody(BuTokens t, Poll p) {
    final s = _sel!;
    final out = <Widget>[];
    if (p.type == PollType.rating) {
      out.add(Center(child: StarRating(value: s.rating, size: 40, onChanged: (v) => setState(() => s.setRating(v)))));
    } else {
      if (p.type == PollType.multi || p.type == PollType.ranked) {
        final hint = p.type == PollType.ranked
            ? 'Tercih sırasına göre dokunun: ilk dokunduğunuz en çok tercih ettiğinizdir.'
            : (p.maxChoices != null ? 'En fazla ${p.maxChoices} seçenek işaretleyin.' : 'Birden fazla seçenek işaretleyebilirsiniz.');
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(hint, style: BuType.caption.copyWith(color: t.mut)),
        ));
      }
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
                side: BorderSide(color: on ? t.pr : t.bd, width: on ? 1.5 : 1),
              ),
              child: InkWell(
                customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onTap: () => _toggle(o.id),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(children: [
                      if (p.type == PollType.ranked)
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: on ? t.pr : t.sf2,
                          child: Text(rank == null ? '' : '$rank', style: BuType.label.copyWith(color: t.onPr)),
                        )
                      else
                        Icon(
                          p.type == PollType.single
                              ? (on ? Icons.radio_button_checked : Icons.radio_button_unchecked)
                              : (on ? Icons.check_box : Icons.check_box_outline_blank),
                          size: 22,
                          color: on ? t.pr : t.mut,
                        ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(o.text, style: BuType.bodyStrong.copyWith(color: t.ink))),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ));
      }
    }
    out.add(const SizedBox(height: 6));
    out.add(BuButton(
      label: p.voted ? 'Oyu güncelle' : 'Oy ver',
      busy: _busy,
      onPressed: s.canSubmit ? _submit : null,
    ));
    if (p.voted) {
      out.add(const SizedBox(height: 8));
      out.add(BuButton(
          label: 'Vazgeç',
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
    if (p.type == PollType.rating) {
      final avg = p.average;
      return [
        BuCard(
          child: SizedBox(
            width: double.infinity,
            child: Column(children: [
              Text(avg == null ? '-' : avg.toStringAsFixed(1), style: BuType.display.copyWith(color: t.ink)),
              const SizedBox(height: 6),
              StarRating(value: avg?.round(), size: 26),
              const SizedBox(height: 6),
              Text('${p.ratingCount ?? p.participants} puan', style: BuType.caption.copyWith(color: t.mut)),
              if (p.myRating != null) ...[
                const SizedBox(height: 4),
                Text('Puanınız: ${p.myRating}', style: BuType.label.copyWith(color: t.pr)),
              ],
            ]),
          ),
        ),
        if (p.results.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final o in p.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ResultBar(
                  text: '${o.text} yıldız',
                  percent: p.percentOf(o),
                  votes: p.countOf(o),
                  mine: p.myOptionIds.contains(o.id) || p.myRating?.toString() == o.text),
            ),
        ],
      ];
    }
    return [
      for (final o in p.options)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ResultBar(
            text: o.text,
            percent: p.percentOf(o),
            votes: p.countOf(o),
            mine: p.myOptionIds.contains(o.id),
            score: p.resultOf(o)?.score,
          ),
        ),
    ];
  }

  List<Widget> _ownerActions(Poll p) => [
        const SizedBox(height: 16),
        if (p.canVote)
          BuButton(
            label: 'Oyu değiştir',
            kind: BuButtonKind.soft,
            onPressed: _busy ? null : () => setState(() => _editing = true),
          ),
        ...[
          const SizedBox(height: 8),
          BuButton(label: 'Oyu geri çek', kind: BuButtonKind.outline, busy: _busy, onPressed: _busy ? null : _retract),
        ],
      ];
}
