import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../posts/social_api.dart';
import '../posts/social_models.dart';
import 'follow_button.dart';
import 'follow_list_page.dart';

/// Profildeki takipçi / takip sayıları (listeye giden) ve (başkasının profilinde) Takip Et düğmesi.
/// Sayılar alınamazsa sessizce gizlenir (profil yine çalışır).
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

  Widget _count(BuTokens t, int n, String label, bool followers) {
    return Semantics(
      button: true,
      label: '$n $label',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await openFollowList(context, widget.session, userId: widget.userId, followers: followers, name: widget.name);
          if (mounted) _load();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$n', key: ValueKey(followers ? 'followerCount' : 'followingCount'), style: BuType.heading.copyWith(color: t.ink)),
            Text(label, style: BuType.caption.copyWith(color: t.mut)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    if (s == null) return const SizedBox.shrink();
    final t = context.bu;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _count(t, s.followers, 'Takipçi', true),
          _count(t, s.following, 'Takip', false),
        ]),
        if (!_self)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: FollowButton(
              session: widget.session,
              userId: widget.userId,
              followed: s.followedByMe,
              compact: false,
              onChanged: (v) => setState(() =>
                  _stats = s.copyWith(followedByMe: v, followers: (s.followers + (v ? 1 : -1)).clamp(0, 1 << 30))),
            ),
          ),
      ]),
    );
  }
}
