import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
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
      if (mounted) setState(() => _msg = pollErrorText(e));
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
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: BuCard(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(LucideIcons.star, size: 16, color: t.pr),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('Bugünün menüsünü puanla', style: BuType.heading.copyWith(color: t.ink))),
              ]),
              const SizedBox(height: 10),
              if (p.menuItems.isNotEmpty) ...[
                Text(p.menuItems.join(' · '),
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.body.copyWith(color: t.mut)),
                const SizedBox(height: 8),
              ],
              Center(child: StarRating(value: p.myRating, onChanged: canRate && !_busy ? _rate : null)),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  _msg ??
                      (p.voted
                          ? 'Puanınız: ${p.myRating}${p.average != null ? ' · Ortalama ${p.average!.toStringAsFixed(1)}' : ''}'
                          : (p.canVote ? 'Yıldıza dokunarak puanla' : 'Bu anket için oy hakkınız yok')),
                  textAlign: TextAlign.center,
                  style: BuType.caption.copyWith(color: _msg != null ? t.danger : t.mut),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
