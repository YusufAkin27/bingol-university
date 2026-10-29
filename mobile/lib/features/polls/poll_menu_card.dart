import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'anket_style.dart';
import 'poll_api.dart';
import 'poll_models.dart';
import 'poll_parts.dart';

/// Yemek ekranı kartı: "Bugünün menüsünü puanla". Menü anketi yoksa (204) ya da hata olursa görünmez.
class PollMenuCard extends StatefulWidget {
  const PollMenuCard({super.key, required this.session});

  final Session session;

  @override
  State<PollMenuCard> createState() => _PollMenuCardState();
}

class _PollMenuCardState extends State<PollMenuCard> {
  late final PollApi _api = PollApi(widget.session);
  Poll? _poll;
  bool _busy = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await _api.menuToday();
      if (mounted) setState(() => _poll = p);
    } catch (_) {
      // Sessiz: kart yalnız bir kolaylık; hata durumunda gizli kalır.
    }
  }

  Future<void> _rate(int v) async {
    final p = _poll;
    if (p == null || _busy) return;
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final r = await _api.vote(p.id, PollSelection(PollType.rating)..setRating(v));
      if (mounted) setState(() => _poll = r);
    } catch (e) {
      if (mounted) setState(() => _msg = pollErrorText(e, context.l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _word(int r) {
    final l = context.l10n;
    return switch (r) {
      1 => l.p13Rate1,
      2 => l.p13Rate2,
      3 => l.p13Rate3,
      4 => l.p13Rate4,
      _ => l.p13Rate5,
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = _poll;
    if (p == null || p.isClosed()) return const SizedBox.shrink();
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final canRate = p.canVote;
    final tone = AnketTone.meal(context);
    final caption = _msg ??
        (p.voted
            ? (p.average != null
                ? l.pollYourRatingAvg('${p.myRating}', p.average!.toStringAsFixed(1))
                : l.pollYourRating('${p.myRating}'))
            : (p.canVote ? l.pollTapStar : l.pollNoVoteRight));
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: BuCard(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 18),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                AnketIconTile(LucideIcons.star, bg: tone.bg, fg: tone.fg, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Semantics(header: true, child: Text(l.pollMenuRateToday, style: tx.titleMedium!.copyWith(color: t.ink))),
                    if (p.menuItems.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(p.menuItems.join(' · '),
                          maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
                    ],
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: StarRating(value: p.myRating, size: 36, onChanged: canRate && !_busy ? _rate : null),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: AnimatedSwitcher(
                  duration: BuMotion.of(context, BuMotion.short),
                  child: Column(
                    key: ValueKey('${p.myRating}|$_msg|${p.voted}'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (p.myRating != null && _msg == null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(_word(p.myRating!.clamp(1, 5)), style: tx.titleSmall!.copyWith(color: t.ink)),
                        ),
                      Text(
                        caption,
                        textAlign: TextAlign.center,
                        style: tx.bodySmall!.copyWith(color: _msg != null ? t.danger : t.mut),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
