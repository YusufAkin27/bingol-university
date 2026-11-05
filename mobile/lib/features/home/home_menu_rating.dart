import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../polls/poll_api.dart';
import '../polls/poll_models.dart';
import '../polls/poll_parts.dart' show StarRating;

/// Günün menüsü kartındaki "Menüyü puanla" + 5 yıldız satırı (mevcut menü anketi: `GET /polls/menu/today`, oy
/// `POST /polls/{id}/vote`). Menü anketi yoksa (204), kapanmışsa ya da hata olursa hiçbir şey çizmez; puan verilince
/// yıldızlar dolu kalır. Hata sessizdir (kart yalnız bir kolaylık).
class HomeMenuRating extends StatefulWidget {
  const HomeMenuRating({super.key, required this.session});

  final Session session;

  @override
  State<HomeMenuRating> createState() => _HomeMenuRatingState();
}

class _HomeMenuRatingState extends State<HomeMenuRating> {
  late final PollApi _api = PollApi(widget.session);
  Poll? _poll;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await _api.menuToday();
      if (mounted) setState(() => _poll = p);
    } catch (_) {}
  }

  Future<void> _rate(int v) async {
    final p = _poll;
    if (p == null || _busy) return;
    setState(() => _busy = true);
    try {
      final r = await _api.vote(p.id, PollSelection(PollType.rating)..setRating(v));
      if (mounted) setState(() => _poll = r);
    } catch (e) {
      if (mounted) BuToast.show(context, pollErrorText(e, context.l10n), kind: BuToastKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _poll;
    if (p == null || p.isClosed()) return const SizedBox.shrink();
    final t = context.bu;
    final canRate = p.canVote;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Flexible(
        child: Text(context.l10n.homeMenuRate,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BuType.label.copyWith(fontSize: 13, fontWeight: BuType.emphasisWeight, color: t.mut)),
      ),
      const SizedBox(width: 4),
      StarRating(
        value: p.myRating,
        size: 16,
        compact: true,
        activeColor: t.prPressed,
        inactiveColor: t.mut,
        onChanged: canRate && !_busy ? _rate : null,
      ),
    ]);
  }
}
