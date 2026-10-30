import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'anket_style.dart';
import 'anket_widgets.dart';
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

  @override
  Widget build(BuildContext context) {
    final p = _poll;
    if (p == null || p.isClosed()) return const SizedBox.shrink();
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final canRate = p.canVote;
    final rated = p.myRating != null;
    final isTr = Localizations.localeOf(context).languageCode == 'tr';
    String avgText(double v) => isTr ? v.toStringAsFixed(1).replaceAll('.', ',') : v.toStringAsFixed(1);
    final stars = StarRating(
      value: p.myRating,
      size: 30,
      compact: rated,
      activeColor: t.pr,
      inactiveColor: rated ? t.pr.withValues(alpha: .25) : t.pr,
      onChanged: canRate && !_busy ? _rate : null,
    );
    final title = Semantics(header: true, child: Text(l.pollMenuRateToday, style: tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w800)));
    final err = _msg == null ? null : Text(_msg!, style: tx.bodySmall!.copyWith(color: t.danger));
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: BuCard(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 20),
        child: SizedBox(
          width: double.infinity,
          child: rated
              // Puan verilmiş: sola dayalı başlık + onay simgesi, yıldızlar, "Puanınız · Ortalama" hapı, teşekkür metni.
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: title),
                    const SizedBox(width: 8),
                    ExcludeSemantics(child: Icon(LucideIcons.circleCheck, size: 24, color: t.pr)),
                  ]),
                  const SizedBox(height: 8),
                  FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: stars),
                  const SizedBox(height: 10),
                  AnketPill(
                    p.average != null ? l.pollYourRatingAvg('${p.myRating}', avgText(p.average!)) : l.pollYourRating('${p.myRating}'),
                    bg: t.soft,
                    fg: t.onSoft,
                  ),
                  const SizedBox(height: 12),
                  if (err != null) err else Text(l.p13MenuRated, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.4)),
                ])
              // Henüz puan yok: ortalanmış simge, başlık, ipucu ve boş yıldızlar.
              : Column(children: [
                  AnketRoundIcon(LucideIcons.thumbsUp, size: 44, bg: t.soft, fg: t.pr),
                  const SizedBox(height: 12),
                  Center(child: title),
                  const SizedBox(height: 4),
                  Text(canRate ? l.pollTapStar : l.pollNoVoteRight, textAlign: TextAlign.center, style: tx.bodySmall!.copyWith(color: t.mut)),
                  const SizedBox(height: 12),
                  FittedBox(fit: BoxFit.scaleDown, child: stars),
                  if (err != null) ...[const SizedBox(height: 8), err],
                ]),
        ),
      ),
    );
  }
}
