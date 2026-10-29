import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../follow/follow_suggestions.dart';
import '../posts/post_models.dart';
import '../posts/social_api.dart';
import '../posts/social_models.dart';

/// Keşfet: "Tanıyor Olabilirsin" yatay kart şeridi (`GET /users/me/follow-suggestions`). Öneri yoksa ya da yüklenemezse
/// bölüm hiç görünmez (akış boş bir başlıkla başlamasın).
class DiscoverSuggestions extends StatefulWidget {
  const DiscoverSuggestions({super.key, required this.session});

  final Session session;

  @override
  State<DiscoverSuggestions> createState() => _DiscoverSuggestionsState();
}

class _DiscoverSuggestionsState extends State<DiscoverSuggestions> {
  List<SocialUser>? _items;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await SocialApi(widget.session).followSuggestions(size: 10);
      if (mounted) setState(() => _items = r);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final items = _items;
    if (_failed || (items != null && items.isEmpty)) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('discoverSuggestions'),
      padding: const EdgeInsets.only(bottom: BuSpace.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(BuSpace.lg, 0, BuSpace.lg, BuSpace.sm),
            child: Row(children: [
              Icon(LucideIcons.userPlus, size: 18, color: t.pr),
              BuGap.w6,
              Expanded(
                child: Text(l.p04SuggestTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
              ),
              InkWell(
                key: const ValueKey('discoverSuggestionsAll'),
                borderRadius: BuRadius.bXs,
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => FollowSuggestionsPage(session: widget.session))),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Align(
                    widthFactor: 1,
                    child: Text(l.p04SuggestSeeAll,
                        style: tt.labelSmall?.copyWith(color: t.pr, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ]),
          ),
          SizedBox(
            height: 200 * (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 1.6),
            child: items == null
                ? const BuSkeletonScope(child: _SuggestionSkeletonRow())
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: BuSpace.lg, vertical: 10),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => BuGap.w12,
                    itemBuilder: (_, i) => _SuggestionCard(session: widget.session, user: items[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionSkeletonRow extends StatelessWidget {
  const _SuggestionSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: BuSpace.lg, vertical: 10),
      itemCount: 3,
      separatorBuilder: (_, __) => BuGap.w12,
      itemBuilder: (_, __) => const _SuggestionSurface(
        child: Column(children: [
          BuSkeleton.circle(56),
          BuGap.h8,
          BuSkeleton.line(width: 72, height: 12),
          BuGap.h6,
          BuSkeleton.line(width: 56, height: 10),
          Spacer(),
          BuSkeleton(width: double.infinity, height: 30, radius: 999),
        ]),
      ),
    );
  }
}

class _SuggestionSurface extends StatelessWidget {
  const _SuggestionSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 144,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.bu.sf,
        borderRadius: BorderRadius.circular(BuRadius.md),
        boxShadow: BuElevation.of(context, 2),
      ),
      child: child,
    );
  }
}

class _SuggestionCard extends StatefulWidget {
  const _SuggestionCard({required this.session, required this.user});

  final Session session;
  final SocialUser user;

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard> {
  late bool _followed = widget.user.followedByMe;
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    final want = !_followed;
    setState(() {
      _busy = true;
      _followed = want;
    });
    buHaptic(want ? BuHaptic.light : BuHaptic.selection);
    final api = SocialApi(widget.session);
    try {
      await (want ? api.follow(widget.user.id) : api.unfollow(widget.user.id));
    } catch (e) {
      if (mounted) {
        setState(() => _followed = !want);
        BuToast.show(context, errorText(e), kind: BuToastKind.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final u = widget.user;
    final dept = (u.department ?? '').trim();
    return _SuggestionSurface(
      child: Column(children: [
        BuAvatar(
            name: u.displayName, url: u.avatarUrl, size: 56, headers: postAuthHeaders(widget.session)),
        BuGap.h8,
        Text(u.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: tt.titleSmall?.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
        Text(dept,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: tt.labelSmall?.copyWith(color: t.mut)),
        const Spacer(),
        Semantics(
          button: true,
          toggled: _followed,
          label: _followed ? context.l10n.followButtonUnfollow : context.l10n.followButtonFollow,
          excludeSemantics: true,
          child: GestureDetector(
            key: ValueKey('discover-follow-${u.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: _busy ? null : _toggle,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Center(
                child: Container(
                  width: double.infinity,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _followed ? t.sf2 : t.pr,
                    borderRadius: BorderRadius.circular(BuRadius.pill),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (_followed) ...[Icon(Icons.check, size: 14, color: t.mut), BuGap.w4],
                    Flexible(
                      child: Text(_followed ? context.l10n.p04FollowingState : context.l10n.p04FollowAction,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelMedium?.copyWith(color: _followed ? t.mut : t.onPr, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
