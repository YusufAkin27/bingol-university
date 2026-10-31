import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../posts/social_api.dart';
import '../posts/social_models.dart';
import 'follow_button.dart';
import 'follow_list_page.dart';

/// [StatStrip] hücresi: büyük sayı + küçük etiket; dokununca ilgili liste.
class StatCell {
  const StatCell({required this.label, required this.value, required this.onTap, this.valueKey});

  final String label;

  /// null: henüz yüklenmedi / alınamadı ("–").
  final int? value;
  final VoidCallback onTap;
  final Key? valueKey;
}

/// Profil sayaçları: TEK yüzey, TEK satır (Takipçi · Takip · Kulüp · Etkinlik). Hücreler ince çizgiyle ayrılır; sayılar
/// nötr mürekkep renginde (vurgu rengi yok). Büyük yazı ölçeğinde (etiket küçülmesin diye) 2 x 2 dizilir.
class StatStrip extends StatelessWidget {
  const StatStrip({super.key, required this.cells});

  final List<StatCell> cells;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final big = MediaQuery.textScalerOf(context).scale(10) > 11 && cells.length > 2;
    Widget row(List<StatCell> part) => Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < part.length; i++) ...[
            if (i > 0) VerticalDivider(width: 1, thickness: 1, indent: 10, endIndent: 10, color: t.bd),
            Expanded(child: _Cell(cell: part[i])),
          ],
        ]);
    final Widget body;
    if (big) {
      final half = (cells.length / 2).ceil();
      body = Column(mainAxisSize: MainAxisSize.min, children: [
        IntrinsicHeight(child: row(cells.sublist(0, half))),
        Divider(height: 1, thickness: 1, indent: 12, endIndent: 12, color: t.bd),
        IntrinsicHeight(child: row(cells.sublist(half))),
      ]);
    } else {
      body = IntrinsicHeight(child: row(cells));
    }
    return BuCard(padding: EdgeInsets.zero, child: body);
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.cell});

  final StatCell cell;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final n = cell.value;
    final style = tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()]);
    return Semantics(
      button: true,
      label: n == null ? cell.label : '$n ${cell.label}',
      excludeSemantics: true,
      child: BuPressable(
        haptic: BuHaptic.selection,
        scale: .96,
        onTap: cell.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72, minWidth: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
            child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
              if (n != null)
                KeyedSubtree(key: cell.valueKey, child: BuCountUp(value: n, style: style))
              else
                Text('–', maxLines: 1, style: style),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(cell.label, maxLines: 1, style: tx.labelMedium!.copyWith(color: t.mut)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Profildeki takipçi / takip sayıları ve (başkasının profilinde) Takip Et düğmesi. [extraCells] verilirse (Kulüp,
/// Etkinlik gibi) hepsi tek [StatStrip] yüzeyinde birleşir. Yüklenirken sayılar "–" görünür (sayfa zıplamaz);
/// takip sayıları alınamazsa yalnız ek hücreler gösterilir (profil yine çalışır).
class FollowSummary extends StatefulWidget {
  const FollowSummary({super.key, required this.session, required this.userId, this.name, this.extraCells = const []});

  final Session session;
  final int userId;
  final String? name;
  final List<StatCell> extraCells;

  @override
  State<FollowSummary> createState() => _FollowSummaryState();
}

class _FollowSummaryState extends State<FollowSummary> {
  FollowStats? _stats;
  bool _failed = false;

  bool get _self => widget.userId == widget.session.userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await SocialApi(widget.session).followStats(widget.userId);
      if (mounted) setState(() => _stats = s);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _open(bool followers) async {
    await openFollowList(context, widget.session, userId: widget.userId, followers: followers, name: widget.name);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    final l = context.l10n;
    final hasExtra = widget.extraCells.isNotEmpty;
    if (s == null && (_failed || !hasExtra)) {
      // Takip sayıları yok: ek hücreler (varsa) tek başına; hiçbiri yoksa hiçbir şey.
      return hasExtra ? StatStrip(cells: widget.extraCells) : const SizedBox.shrink();
    }
    return Column(children: [
      StatStrip(cells: [
        StatCell(
            label: l.followersCount,
            value: s?.followers,
            valueKey: const ValueKey('followerCount'),
            onTap: () => _open(true)),
        StatCell(
            label: l.followingCount,
            value: s?.following,
            valueKey: const ValueKey('followingCount'),
            onTap: () => _open(false)),
        ...widget.extraCells,
      ]),
      if (!_self && s != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: FollowButton(
            session: widget.session,
            userId: widget.userId,
            followed: s.followedByMe,
            compact: false,
            onChanged: (v) => setState(() =>
                _stats = s.copyWith(followedByMe: v, followers: (s.followers + (v ? 1 : -1)).clamp(0, 1 << 30))),
          ),
        ),
    ]);
  }
}
