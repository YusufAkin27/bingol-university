import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../../../core/api.dart';
import '../../../../core/locale_controller.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../widgets/bu.dart';
import '../../data/forum_api.dart';
import '../../data/forum_models.dart';

/// Forum anketi: seçenek çubukları (yüzde, oy sayısı), kendi oyum işaretli, toplam oy, kalan süre, oy ver /
/// değiştir / geri al. Sonuçlar herkese her zaman görünür; oy verenler listelenmez.
///
/// Oy ARAYÜZDE hemen yansır (iyimser) ve hatada geri alınır; ikinci dokunuş sürerken yok sayılır. Sunucu yanıtı
/// geldiğinde yerel anket sunucunun anketiyle değişir ve [onChanged] çağrılır (konu detayı kendi durumunu günceller).
///
/// MB-B konu detayında: `PollView(poll: topic.poll!, api: api, topicId: topic.id, onChanged: (p) => ...)`.
class PollView extends StatefulWidget {
  const PollView({
    super.key,
    required this.poll,
    required this.api,
    required this.topicId,
    this.onChanged,
    this.now,
  });

  final ForumPoll poll;
  final ForumApi api;
  final int topicId;

  /// Oy/geri alma sunucuda onaylanınca güncel anketle çağrılır.
  final ValueChanged<ForumPoll>? onChanged;

  /// Testler için sabit saat.
  final DateTime Function()? now;

  @override
  State<PollView> createState() => _PollViewState();
}

ForumPoll _copy(ForumPoll p,
        {List<ForumPollOption>? options,
        int? totalVotes,
        int? myOptionId,
        bool clearMine = false,
        bool? closed}) =>
    ForumPoll(
      id: p.id,
      question: p.question,
      options: options ?? p.options,
      totalVotes: totalVotes ?? p.totalVotes,
      myOptionId: clearMine ? null : (myOptionId ?? p.myOptionId),
      endsAt: p.endsAt,
      closed: closed ?? p.closed,
      allowChangeVote: p.allowChangeVote,
      canVote: p.canVote,
    );

/// Yüzdeyi 1 ondalığa yuvarlar.
double _pct(int count, int total) => total <= 0 ? 0 : (count * 1000 / total).round() / 10;

/// [mine] seçeneğine oy verilmiş (varsa eskisi geri alınmış) halin iyimser anketi.
ForumPoll applyVote(ForumPoll p, int? optionId) {
  var total = p.totalVotes;
  final prev = p.myOptionId;
  if (prev == null && optionId != null) total += 1;
  if (prev != null && optionId == null) total = total > 0 ? total - 1 : 0;
  final opts = [
    for (final o in p.options)
      ForumPollOption(
        id: o.id,
        text: o.text,
        voteCount: o.id == prev && o.id != optionId
            ? (o.voteCount > 0 ? o.voteCount - 1 : 0)
            : (o.id == optionId && o.id != prev ? o.voteCount + 1 : o.voteCount),
        percent: 0,
      ),
  ];
  return _copy(
    p,
    totalVotes: total,
    options: [for (final o in opts) ForumPollOption(id: o.id, text: o.text, voteCount: o.voteCount, percent: _pct(o.voteCount, total))],
    myOptionId: optionId,
    clearMine: optionId == null,
  );
}

class _PollViewState extends State<PollView> {
  late ForumPoll _poll = widget.poll;
  bool _busy = false;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void didUpdateWidget(PollView old) {
    super.didUpdateWidget(old);
    // Üst widget yeni anket verirse (yenileme) yerel durum güncellenir; oy sürerken iyimser durum korunur.
    if (!_busy && !identical(old.poll, widget.poll)) _poll = widget.poll;
  }

  DateTime? get _ends => _poll.endsAt == null ? null : DateTime.tryParse(_poll.endsAt!)?.toLocal();

  bool get _closed => _poll.closed || (_ends != null && !_ends!.isAfter(_now()));

  bool get _interactive {
    if (_closed || _busy) return false;
    if (_poll.voted) return _poll.allowChangeVote;
    return _poll.canVote;
  }

  Future<void> _vote(ForumPollOption o) async {
    if (_busy) return;
    if (_closed) {
      BuToast.show(context, context.l10n.forumPollErrClosed, kind: BuToastKind.warning);
      return;
    }
    if (_poll.voted && !_poll.allowChangeVote) {
      BuToast.show(context, context.l10n.forumPollErrAlready, kind: BuToastKind.info);
      return;
    }
    if (!_interactive || o.id == _poll.myOptionId) return;
    buHaptic(BuHaptic.selection);
    await _run(applyVote(_poll, o.id), () => widget.api.votePoll(widget.topicId, o.id));
  }

  Future<void> _undo() async {
    if (_busy || !_interactive || !_poll.voted) return;
    buHaptic(BuHaptic.selection);
    await _run(applyVote(_poll, null), () async {
      final r = await widget.api.clearPollVote(widget.topicId);
      return r;
    });
  }

  /// İyimser [next] uygulanır; [call] başarısızsa eski anket geri gelir ve kısa hata gösterilir.
  Future<void> _run(ForumPoll next, Future<ForumPoll?> Function() call) async {
    final before = _poll;
    final undoing = next.myOptionId == null;
    setState(() {
      _poll = next;
      _busy = true;
    });
    try {
      final server = await call();
      if (!mounted) return;
      // Geri alma yanıtı anket döndürmeyebilir: iyimser durum geçerlidir.
      final fin = server ?? (undoing ? next : _poll);
      setState(() {
        _poll = fin;
        _busy = false;
      });
      widget.onChanged?.call(fin);
    } catch (e) {
      if (!mounted) return;
      final l = context.l10n;
      var restored = before;
      if (e is ApiError && e.code == 'FORUM_POLL_CLOSED') restored = _copy(before, closed: true);
      setState(() {
        _poll = restored;
        _busy = false;
      });
      BuToast.show(context, pollErrorText(e, l), kind: BuToastKind.error);
    }
  }

  String _remaining(AppLocalizations l) {
    final e = _ends;
    if (e == null) return '';
    final d = e.difference(_now());
    if (d.inDays >= 1) return l.forumPollLeftDays(d.inDays);
    if (d.inHours >= 1) return l.forumPollLeftHours(d.inHours);
    return l.forumPollLeftMinutes(d.inMinutes < 1 ? 1 : d.inMinutes);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final fmt = NumberFormat.decimalPatternDigits(locale: Localizations.localeOf(context).toString(), decimalDigits: 1);
    final closed = _closed;
    final q = (_poll.question ?? '').trim();
    final info = closed
        ? l.forumPollEnded
        : (_poll.voted ? (_poll.allowChangeVote ? l.forumPollCanChange : l.forumPollLocked) : (_poll.allowChangeVote ? '' : l.forumPollLocked));
    return Column(
      key: const ValueKey('pollView'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (q.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(q, style: tt.titleSmall?.copyWith(color: t.ink, fontWeight: FontWeight.w400, height: 1.3)),
          ),
        for (final o in _poll.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OptionRow(
              key: ValueKey('pollOption${o.id}'),
              option: o,
              selected: o.id == _poll.myOptionId,
              enabled: _interactive,
              dim: closed || (_poll.voted && !_poll.allowChangeVote),
              percentText: l.forumPollPercent(fmt.format(o.percent)),
              votesText: l.forumPollVotes(o.voteCount),
              onTap: () => _vote(o),
            ),
          ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 0,
          children: [
            Text(l.forumPollVotes(_poll.totalVotes),
                key: const ValueKey('pollTotal'),
                style: tt.bodySmall?.copyWith(color: t.mut, fontWeight: FontWeight.w400)),
            if (!closed && _ends != null) ...[
              Text('·', style: tt.bodySmall?.copyWith(color: t.mut)),
              Text(_remaining(l), key: const ValueKey('pollLeft'), style: tt.bodySmall?.copyWith(color: t.mut, fontWeight: FontWeight.w400)),
            ],
            if (info.isNotEmpty) ...[
              Text('·', style: tt.bodySmall?.copyWith(color: t.mut)),
              Text(info, key: const ValueKey('pollInfo'), style: tt.bodySmall?.copyWith(color: t.mut, fontWeight: FontWeight.w400)),
            ],
            if (!closed && _poll.voted && _poll.allowChangeVote)
              TextButton(
                key: const ValueKey('pollUndo'),
                onPressed: _busy ? null : _undo,
                style: TextButton.styleFrom(
                  minimumSize: const Size(BuSize.touch, BuSize.touch),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                child: Text(l.forumPollUndo, style: tt.labelMedium?.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
              ),
          ],
        ),
      ],
    );
  }
}

/// Kısa, çevrilmiş anket hata metni (oy / geri alma).
String pollErrorText(Object e, AppLocalizations l) {
  if (e is ApiError) {
    if (e.isNetwork) return l.forumPollErrNetwork;
    switch (e.code) {
      case 'FORUM_POLL_CLOSED':
        return l.forumPollErrClosed;
      case 'FORUM_POLL_ALREADY_VOTED':
        return l.forumPollErrAlready;
    }
    if (e.status == 429) return l.forumPollErrRate;
    if (e.status == 404) return l.forumPollErrGone;
    if (e.status == 403) return l.forumPollErrForbidden;
  }
  return l.forumPollErrGeneric;
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    super.key,
    required this.option,
    required this.selected,
    required this.enabled,
    required this.dim,
    required this.percentText,
    required this.votesText,
    required this.onTap,
  });

  final ForumPollOption option;
  final bool selected;
  final bool enabled;
  final bool dim;
  final String percentText;
  final String votesText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final frac = (option.percent / 100).clamp(0.0, 1.0);
    final radius = BorderRadius.circular(BuRadius.sm);
    final label = '${l.forumPollSemantics(option.text, percentText, votesText)}${selected ? ', ${l.forumPollSelected}' : ''}';
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: BuPressable(
        scale: .985,
        enabled: enabled,
        child: Material(
          color: t.sf,
          shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: selected ? t.ink : t.bd, width: selected ? 1.5 : 1)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            // Kapalı/değiştirilemez ankette de dokunuş kısa bilgi verir; görsel basış yalnız etkinken.
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: BuSize.touch),
              child: Stack(
                alignment: AlignmentDirectional.centerStart,
                children: [
                  Positioned.fill(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: frac),
                        duration: BuMotion.of(context, BuMotion.medium),
                        curve: BuMotion.standard,
                        builder: (_, v, __) => FractionallySizedBox(
                          widthFactor: v,
                          heightFactor: 1,
                          child: ColoredBox(color: selected ? t.sf3 : t.sf2),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(children: [
                      if (selected) ...[
                        ExcludeSemantics(child: Icon(BuIcons.circleCheck, size: 18, color: t.ink)),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(option.text,
                            style: tt.bodyMedium?.copyWith(color: dim && !selected ? t.mut : t.ink, fontWeight: FontWeight.w400, height: 1.3)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(percentText, style: tt.labelLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w400, fontFeatures: const [FontFeature.tabularFigures()])),
                          Text(votesText, style: tt.labelSmall?.copyWith(color: t.mut, fontWeight: FontWeight.w400)),
                        ],
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
