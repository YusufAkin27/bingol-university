import 'package:flutter/material.dart';

import '../../core/academic_catalog.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/profile_photo_viewer.dart';
import '../follow/follow_button.dart';
import '../follow/follow_suggestions.dart';
import '../follow/suggestion_pager.dart';
import '../posts/post_models.dart' show postAuthHeaders;
import '../profile/user_profile_page.dart' show openUserProfile;

/// Ana Sayfa "Önerilen kişiler" bölümü: yatay kaydırılan, sayfalı kart şeridi (`GET /users/me/follow-suggestions`).
/// Kaydırma sonuna yaklaşınca sıradaki sayfa gelir. Veri yoksa ya da yüklenemezse bölüm TAMAMEN gizlenir
/// ([onUnavailable] ana sayfaya haber verir; boş kart / hata kartı çizilmez). Yüklenirken ince iskelet görünür.
class HomeSuggestions extends StatefulWidget {
  const HomeSuggestions({
    super.key,
    required this.session,
    this.onUnavailable,
    this.onLongPressTitle,
    this.refreshToken,
  });

  final Session session;

  /// Öneri yok ya da ilk sayfa yüklenemedi: ana sayfa bölümü gizler.
  final VoidCallback? onUnavailable;

  /// Başlığa uzun basma: "Ana sayfayı düzenle".
  final VoidCallback? onLongPressTitle;

  /// Değişirse (çek-yenile) liste baştan yüklenir.
  final Object? refreshToken;

  @override
  State<HomeSuggestions> createState() => _HomeSuggestionsState();
}

class _HomeSuggestionsState extends State<HomeSuggestions> {
  late final SuggestionPager _pager = SuggestionPager(widget.session, pageSize: 10);
  final _scroll = ScrollController();
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _pager.addListener(_onPager);
    _pager.reload();
  }

  @override
  void didUpdateWidget(HomeSuggestions old) {
    super.didUpdateWidget(old);
    if (old.refreshToken != widget.refreshToken) {
      _reported = false;
      _pager.reload();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _pager.removeListener(_onPager);
    _pager.dispose();
    super.dispose();
  }

  void _onPager() {
    if (!mounted) return;
    // İlk yanıt bitti ve gösterilecek kişi yok (boş ya da hata): bölüm gizlenir.
    final settled = !_pager.loading && (_pager.loaded || _pager.error != null);
    if (settled && _pager.items.isEmpty && !_reported) {
      _reported = true;
      widget.onUnavailable?.call();
      return;
    }
    setState(() {});
    // Ilk sayfa şeridi doldurmadıysa kaydırma olmaz: sıradaki sayfayı kendimiz iste.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (_pager.moreError == null && _scroll.position.maxScrollExtent <= 0) _pager.loadMore();
    });
  }

  void _onScroll() {
    if (!_scroll.hasClients || _pager.moreError != null) return;
    final p = _scroll.position;
    if (p.pixels >= p.maxScrollExtent - HomeSuggestionCard.width * 2) _pager.loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final items = _pager.items;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final height = HomeSuggestionCard.heightFor(scale);
    final hasTail = _pager.loadingMore || _pager.moreError != null;

    return Column(
      key: const ValueKey('homeSuggestions'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: BuSpace.pageH,
          child: Row(children: [
            Expanded(
              child: Semantics(
                header: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: widget.onLongPressTitle,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: BuSize.touch),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(l.followSuggestionsTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: BuType.title.copyWith(fontSize: 20, fontWeight: FontWeight.w400, letterSpacing: -.2, color: t.ink)),
                    ),
                  ),
                ),
              ),
            ),
            Semantics(
              button: true,
              excludeSemantics: true,
              label: l.homeViewAll,
              onTap: () => openFollowSuggestions(context, widget.session),
              child: InkWell(
                key: const ValueKey('homeSuggestionsAll'),
                borderRadius: BuRadius.bXs,
                onTap: () => openFollowSuggestions(context, widget.session),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: BuSize.touch, minWidth: BuSize.touch),
                  child: Center(
                    widthFactor: 1,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: BuSpace.md),
                      child: Text(l.homeViewAll,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BuType.label.copyWith(fontSize: 14, fontWeight: FontWeight.w400, color: t.prText)),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
        SizedBox(
          height: height,
          child: items.isEmpty
              ? const BuSkeletonScope(child: _SkeletonStrip())
              : ListView.separated(
                  key: const ValueKey('homeSuggestionsStrip'),
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  padding: BuSpace.pageH,
                  itemCount: items.length + (hasTail ? 1 : 0),
                  separatorBuilder: (_, __) => BuGap.w12,
                  itemBuilder: (_, i) {
                    if (i >= items.length) {
                      return _pager.moreError != null
                          ? _MoreError(onRetry: _pager.loadMore)
                          : const BuSkeletonScope(child: _SkeletonCard());
                    }
                    return HomeSuggestionCard(session: widget.session, person: items[i]);
                  },
                ),
        ),
      ],
    );
  }
}

/// Öneri kartı: avatar (uzun basma = büyük fotoğraf), ad, bölüm · sınıf, (varsa) neden, "Takip et". Dokunma = profil.
class HomeSuggestionCard extends StatelessWidget {
  const HomeSuggestionCard({super.key, required this.session, required this.person});

  final Session session;
  final SuggestedPerson person;

  static const double width = 152;

  /// Yazı ölçeğine göre kart yüksekliği: sabit kısım (avatar + düğme + boşluklar) + 3 yazı satırı.
  static double heightFor(double textScale) => 148 + 52 * textScale.clamp(1.0, 1.6);

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final u = person.user;
    final dept = context.departmentName((u.department ?? '').trim());
    final sub = [
      if (dept.isNotEmpty) dept,
      if (person.classYear != null) l.p18ClassYear('${person.classYear}'),
    ].join(' · ');
    void open() => openUserProfile(context, session, userId: u.id, name: u.displayName, avatarUrl: u.avatarUrl);

    return SizedBox(
      width: width,
      child: BuCard(
        key: ValueKey('home-suggestion-${u.id}'),
        padding: const EdgeInsetsDirectional.fromSTEB(BuSpace.md, BuSpace.md, BuSpace.md, BuSpace.sm),
        radius: BuRadius.md,
        onTap: open,
        child: Semantics(
          container: true,
          label: [u.displayName, if (sub.isNotEmpty) sub].join(', '),
          child: Column(children: [
            AvatarLongPress(
              imageUrl: u.avatarUrl,
              headers: postAuthHeaders(session),
              title: u.displayName,
              child: BuAvatar(name: u.displayName, url: u.avatarUrl, size: 56, headers: postAuthHeaders(session)),
            ),
            BuGap.h8,
            Text(u.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: tt.titleSmall?.copyWith(color: t.ink, fontSize: 14, fontWeight: FontWeight.w400)),
            if (sub.isNotEmpty)
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: tt.labelSmall?.copyWith(color: t.mut, fontSize: 12)),
            if (person.reasonLabel(context.l10n) != null)
              Text(person.reasonLabel(context.l10n)!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: tt.labelSmall?.copyWith(color: t.mut, fontSize: 12)),
            const Spacer(),
            FollowStateButton(
              session: session,
              userId: u.id,
              state: u.followState,
              isPrivate: u.isPrivate,
              look: FollowLook.chip,
              tapKey: ValueKey('home-suggestion-follow-${u.id}'),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SkeletonStrip extends StatelessWidget {
  const _SkeletonStrip();

  @override
  Widget build(BuildContext context) => ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: BuSpace.pageH,
        itemCount: 3,
        separatorBuilder: (_, __) => BuGap.w12,
        itemBuilder: (_, __) => const _SkeletonCard(),
      );
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: HomeSuggestionCard.width,
        child: BuCard(
          padding: EdgeInsetsDirectional.fromSTEB(BuSpace.md, BuSpace.md, BuSpace.md, BuSpace.md),
          radius: BuRadius.md,
          child: Column(children: [
            BuSkeleton.circle(56),
            BuGap.h8,
            BuSkeleton.line(width: 88, height: 14),
            BuGap.h6,
            BuSkeleton.line(width: 64),
            Spacer(),
            BuSkeleton(width: double.infinity, height: 36, radius: 999),
          ]),
        ),
      );
}

/// Sonraki sayfa yüklenemedi: şeridin sonunda kısa uyarı + "Yeniden dene".
class _MoreError extends StatelessWidget {
  const _MoreError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SizedBox(
      width: HomeSuggestionCard.width,
      child: Center(
        child: BuButton(label: l.commonRetry, icon: BuIcons.refreshCw, compact: true, onPressed: onRetry),
      ),
    );
  }
}
