import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../posts/social_api.dart';
import '../posts/social_models.dart';
import 'follow_button.dart';
import 'follow_list_page.dart';

/// Profildeki takipçi / takip sayıları (listeye giden iki karo) ve (başkasının profilinde) Takip Et düğmesi.
/// Sayılar alınamazsa sessizce gizlenir (profil yine çalışır). Yüklenirken aynı boyutta iskelet karoları gösterilir
/// (sayfa zıplamaz).
class FollowSummary extends StatefulWidget {
  const FollowSummary({super.key, required this.session, required this.userId, this.name});

  final Session session;
  final int userId;
  final String? name;

  @override
  State<FollowSummary> createState() => _FollowSummaryState();
}

class _FollowSummaryState extends State<FollowSummary> {
  FollowStats? _stats;

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
    } catch (_) {}
  }

  Widget _tile(BuTokens t, int n, String label, bool followers) {
    final tx = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '$n $label',
      excludeSemantics: true,
      child: BuCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        // Altındaki Kulüp/Etkinlik sayaçlarıyla aynı çizgili yüzey ve 10 dp aralık.
        style: BuCardStyle.outlined,
        radius: 18,
        onTap: () async {
          buHaptic(BuHaptic.selection);
          await openFollowList(context, widget.session, userId: widget.userId, followers: followers, name: widget.name);
          if (mounted) _load();
        },
        child: Row(children: [
          ExcludeSemantics(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: t.tint(followers ? BuTintId.aqua : BuTintId.blue).bg, shape: BoxShape.circle),
              child: Icon(followers ? LucideIcons.users : LucideIcons.userCheck, size: 18, color: t.tint(followers ? BuTintId.aqua : BuTintId.blue).fg),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              // Sayı değişince (takip/bırak) kısa kayarak yenilenir.
              AnimatedSwitcher(
                duration: BuMotion.of(context, BuMotion.short),
                transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
                child: Text('$n',
                    key: ValueKey(followers ? 'followerCount' : 'followingCount'),
                    maxLines: 1,
                    style: tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
              ),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
            ]),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    if (s == null) return const SizedBox.shrink();
    final t = context.bu;
    return Column(children: [
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _tile(t, s.followers, context.l10n.followersCount, true)),
          const SizedBox(width: 10),
          Expanded(child: _tile(t, s.following, context.l10n.followingCount, false)),
        ]),
      ),
      if (!_self)
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
