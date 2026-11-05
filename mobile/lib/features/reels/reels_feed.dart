import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart' show ApiError;
import '../../core/locale_controller.dart';
import '../../core/nav.dart' show shellImmersive;
import '../../core/session.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import '../posts/avatar_preview.dart';
import '../posts/feed_seen.dart';
import '../posts/like_button.dart';
import '../posts/post_actions.dart';
import '../share/share_button.dart' show shareContentForPost;
import '../share/share_sheet.dart' show showShareSheet;
import '../posts/post_api.dart';
import '../posts/post_media_uploader.dart' show postErrorText;
import '../posts/post_models.dart';
import '../posts/post_video.dart';
import '../posts/social_api.dart';
import '../posts/social_models.dart';
import '../follow/follow_button.dart';
import '../profile/user_profile_page.dart' show openUserProfile;
import 'reels_comments.dart';

/// Reels: dikey, tam ekran video akışı (`GET /feed/reels`). Yalnız video gönderiler; öneri sırası sunucudadır (izlenmemiş
/// öncelikli, aynı oturumda tekrar yok). Her sayfa ekranı doldurur; YALNIZ göründüğü sayfa oynar (diğerlerinin
/// oynatıcısı kurulmaz/atılır). Dokununca oynat/duraklat; sağ eylem çubuğu: Beğen, Yorumlar (sunucu sunuyorsa), Kaydet
/// (sunucu sunuyorsa), Üç nokta (İlgilenmiyorum/Şikâyet/...). Altta avatar + ad (profil; avatara uzun basma = önizleme) +
/// açıklama ("Devamını gör") + puan.
///
/// İçerik tükenince sonsuz döngü YOK: "Şimdilik tüm videoları gördün" + Tekrar izle + Keşfet gönderilerine bak. En üstteyken
/// aşağı çekmek yeni oturum (yeni sıra, yeni videolar) başlatır. [active] false iken (başka filtre/sekme/üst rota) oynatma
/// durur; uzun süre sonra geri dönülürse akış yenilenir.
class ReelsFeed extends StatefulWidget {
  const ReelsFeed({
    super.key,
    required this.session,
    required this.active,
    this.onCompose,
    this.onOpenPosts,
    this.api,
    this.comments,
    this.topInset = 0,
  });

  final Session session;
  final bool active;
  final VoidCallback? onCompose;

  /// "Keşfet gönderilerine bak" (tükenince alternatif).
  final VoidCallback? onOpenPosts;
  final PostApi? api;

  /// Yorum erişimi (testlerde sahte); null: gerçek uçlar.
  final CommentsRepository? comments;

  /// Üstte (durum çubuğu + başlık + filtreler) boş bırakılacak alan.
  final double topInset;

  @override
  State<ReelsFeed> createState() => _ReelsFeedState();
}

class _ReelsFeedState extends State<ReelsFeed> {
  static const _pageSize = 8;

  /// Etkinleşmede akışı yenilemek için gereken boşta kalma süresi.
  static const _staleAfter = Duration(minutes: 3);

  /// En üstte aşağı çekme eşiği (dp): aşılırsa yeni oturum.
  static const _pullThreshold = 90.0;

  final PageController _pager = PageController();
  late final PostApi _api = widget.api ?? PostApi(widget.session);
  late final FeedSeenReporter _seen = FeedSeenReporter(_api);
  final List<Post> _items = [];

  String? _cursor;
  bool _hasMore = true;
  bool _exhausted = false;
  bool _loading = false;
  bool _loaded = false;
  Object? _error;
  int _index = 0;
  int _gen = 0;
  DateTime? _loadedAt;
  double _pull = 0;

  /// Üstte başka bir rota açıkken (ör. yazar profili) oynatma durur.
  bool _routeCurrent = true;

  bool get _on => widget.active && _routeCurrent;

  /// Yazar takip durumları (reel başına istek atmamak için akış boyunca önbellek; GET /users/{id}).
  final Map<int, FollowStats> _authors = {};
  final Map<int, Future<FollowStats?>> _authorLoads = {};

  /// Sürükleyici mod bayrağını bu akış açtı mı (alt gezinme saydamlığı; bkz. [shellImmersive]).
  bool _immersiveOn = false;

  @override
  void initState() {
    super.initState();
    _syncImmersive();
    if (widget.active) _reload();
  }

  /// Reels görünürken alt gezinme saydam olur; çizim sırasında dinleyici tetiklenmesin diye kare sonrası yazılır.
  void _syncImmersive() {
    final want = widget.active;
    if (want == _immersiveOn) return;
    _immersiveOn = want;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (shellImmersive.value != _immersiveOn) shellImmersive.value = _immersiveOn;
    });
  }

  /// Yazarın takip durumu (başarısızsa null: düğme çizilmez, sahte durum gösterilmez).
  Future<FollowStats?> _authorStats(int id) {
    final have = _authors[id];
    if (have != null) return Future<FollowStats?>.value(have);
    return _authorLoads[id] ??= () async {
      try {
        final s = await SocialApi(widget.session).followStats(id);
        _authors[id] = s;
        return s;
      } catch (_) {
        return null;
      } finally {
        _authorLoads.remove(id);
      }
    }();
  }

  void _followChanged(int id, FollowState st) {
    final s = _authors[id];
    if (s != null) _authors[id] = s.copyWith(followState: st);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeCurrent = ModalRoute.of(context)?.isCurrent ?? true;
  }

  @override
  void didUpdateWidget(ReelsFeed old) {
    super.didUpdateWidget(old);
    _syncImmersive();
    if (!old.active && widget.active) {
      final at = _loadedAt;
      if (!_loaded && !_loading) {
        _reload();
      } else if (at != null && DateTime.now().difference(at) > _staleAfter) {
        _reload();
      } else {
        _markCurrent();
      }
    } else if (old.active && !widget.active) {
      unawaited(_seen.flush());
    }
  }

  @override
  void dispose() {
    if (_immersiveOn) {
      _immersiveOn = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => shellImmersive.value = false);
    }
    _seen.dispose();
    _pager.dispose();
    super.dispose();
  }

  /// Kaydırma konumundaki reeli "görüldü" işaretler (yalnız gerçekten ekrandayken).
  void _markCurrent() {
    if (!_on || _index < 0 || _index >= _items.length) return;
    _seen.mark(_items[_index].id);
  }

  Future<void> _reload({bool replay = false}) async {
    final gen = ++_gen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _api.reels(size: _pageSize, replay: replay);
      if (!mounted || gen != _gen) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items.where((p) => p.isVideo));
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _exhausted = page.exhausted;
        _loaded = true;
        _loading = false;
        _index = 0;
        _loadedAt = DateTime.now();
      });
      if (_pager.hasClients) _pager.jumpToPage(0);
      _markCurrent();
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _loading = false;
        if (!_loaded) _error = e;
      });
      if (_loaded) BuToast.show(context, postErrorText(e, context.l10n), kind: BuToastKind.error);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore || !_loaded) return;
    final gen = _gen;
    setState(() => _loading = true);
    try {
      final page = await _api.reels(cursor: _cursor, size: _pageSize);
      if (!mounted || gen != _gen) return;
      setState(() {
        final have = {for (final p in _items) p.id};
        _items.addAll(page.items.where((p) => p.isVideo && have.add(p.id)));
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _exhausted = page.exhausted;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      // Bozuk imleç ya da ağ hatası: sessizce dur; kullanıcı yukarı-aşağı kaydırınca yeniden denenir.
      setState(() {
        _loading = false;
        if (e is ApiError && e.code == 'POST_CURSOR_INVALID') {
          _hasMore = false;
          _exhausted = true;
        }
      });
    }
  }

  void _onPage(int i) {
    setState(() => _index = i);
    _markCurrent();
    if (i >= _items.length - 2) _loadMore();
  }

  void _changed(Post p) {
    final i = _items.indexWhere((e) => e.id == p.id);
    if (i >= 0 && mounted) setState(() => _items[i] = p);
  }

  void _removed(int id) {
    if (mounted) setState(() => _items.removeWhere((e) => e.id == id));
  }

  /// En üstte aşağı çekme (iOS sıçrama / Android taşma) -> yeni oturum.
  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || _index != 0 || _loading) return false;
    if (n is OverscrollNotification && n.overscroll < 0) {
      _pull += -n.overscroll;
    } else if (n is ScrollUpdateNotification && n.metrics.pixels < n.metrics.minScrollExtent) {
      _pull = n.metrics.minScrollExtent - n.metrics.pixels;
    } else if (n is ScrollEndNotification) {
      if (_pull >= _pullThreshold) {
        _pull = 0;
        buHaptic(BuHaptic.light);
        _reload();
      }
      _pull = 0;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final Widget body;
    if (!_loaded && _error == null) {
      body = Center(child: CircularProgressIndicator(key: const ValueKey('reelsLoading'), strokeWidth: 2, color: t.onMedia));
    } else if (_error != null && !_loaded) {
      body = _Message(
        key: const ValueKey('reelsError'),
        title: l.p04FeedErrTitle,
        body: l.p04FeedErrBody,
        actions: [_Act(l.postViewRetry, _reload)],
      );
    } else if (_items.isEmpty) {
      body = _exhausted ? _done(l) : _empty(l);
    } else {
      final extra = _exhausted && !_hasMore ? 1 : 0; // son sayfa: "tüm videoları gördün"
      body = NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: PageView.builder(
          key: const ValueKey('reelsPager'),
          controller: _pager,
          scrollDirection: Axis.vertical,
          physics: const AlwaysScrollableScrollPhysics(),
          // Komşu sayfalar kurulur: sıradaki video önceden hazırlanır (yalnız aktif olan oynar).
          allowImplicitScrolling: true,
          itemCount: _items.length + extra,
          onPageChanged: _onPage,
          itemBuilder: (_, i) {
            if (i >= _items.length) return _done(l);
            final p = _items[i];
            return _ReelPage(
              key: ValueKey('reel-${p.id}'),
              session: widget.session,
              post: p,
              active: _on && i == _index,
              prepare: _on && i == _index + 1,
              topInset: widget.topInset,
              authorStats: _authorStats,
              onFollowState: _followChanged,
              api: _api,
              comments: widget.comments,
              onChanged: _changed,
              onRemoved: () => _removed(p.id),
            );
          },
        ),
      );
    }
    return ColoredBox(color: t.scrim, child: body);
  }

  Widget _empty(AppLocalizations l) => _Message(
        key: const ValueKey('reelsEmpty'),
        title: l.kesReelsEmptyTitle,
        body: l.kesReelsEmptyBody,
        actions: [if (widget.onCompose != null) _Act(l.discoverCompose, widget.onCompose!)],
      );

  /// İçerik tükendi: sonsuz döngü yok; Tekrar izle + alternatifler.
  Widget _done(AppLocalizations l) => _Message(
        key: const ValueKey('reelsDone'),
        title: l.kesReelsDoneTitle,
        body: l.kesReelsDoneBody,
        actions: [
          _Act(l.kesReelsReplay, () => _reload(replay: true), key: const ValueKey('reelsReplay')),
          if (widget.onOpenPosts != null) _Act(l.kesReelsToPosts, widget.onOpenPosts!, key: const ValueKey('reelsToPosts')),
          if (widget.onCompose != null) _Act(l.discoverCompose, widget.onCompose!),
        ],
      );
}

/// Tek reel: tam ekran video + sağ eylem çubuğu + alt sol yazar/açıklama/puan.
class _ReelPage extends StatefulWidget {
  const _ReelPage({
    super.key,
    required this.session,
    required this.post,
    required this.active,
    required this.topInset,
    required this.api,
    required this.onChanged,
    required this.onRemoved,
    required this.authorStats,
    required this.onFollowState,
    this.prepare = false,
    this.comments,
  });

  final Session session;
  final Post post;
  final bool active;

  /// Sıradaki reel: oynatıcı hazırlanır ama oynamaz.
  final bool prepare;
  final Future<FollowStats?> Function(int authorId) authorStats;
  final void Function(int authorId, FollowState state) onFollowState;
  final double topInset;
  final PostApi api;
  final CommentsRepository? comments;
  final ValueChanged<Post> onChanged;
  final VoidCallback onRemoved;

  @override
  State<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<_ReelPage> {
  bool _expanded = false;
  FollowStats? _follow;

  Post get p => widget.post;

  bool get _mine => p.mine || p.author.id == widget.session.userId;

  @override
  void initState() {
    super.initState();
    if (widget.active) _loadFollow();
  }

  @override
  void didUpdateWidget(_ReelPage old) {
    super.didUpdateWidget(old);
    if (!old.active && widget.active) _loadFollow();
  }

  /// Yalnız göründüğü reel için, kendi gönderisi değilse yazarın takip durumunu getirir.
  Future<void> _loadFollow() async {
    if (_follow != null || _mine || p.author.id <= 0) return;
    final s = await widget.authorStats(p.author.id);
    if (mounted && s != null) setState(() => _follow = s);
  }

  Future<void> _toggleSave() async {
    final want = !(p.savedByMe ?? false);
    widget.onChanged(p.copyWith(savedByMe: want));
    try {
      final got = await widget.api.setSaved(p.id, want);
      if (mounted) widget.onChanged(p.copyWith(savedByMe: got));
    } catch (e) {
      if (!mounted) return;
      widget.onChanged(p.copyWith(savedByMe: !want));
      BuToast.show(context, postErrorText(e, context.l10n), kind: BuToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final mine = p.mine || p.author.id == widget.session.userId;
    final text = (p.text ?? '').trim();
    return Stack(fit: StackFit.expand, children: [
      PostVideoView(
        session: widget.session,
        post: p,
        active: widget.active,
        fit: p.video!.aspect >= 1 ? BoxFit.contain : BoxFit.cover,
        tap: PostVideoTap.playPause,
        showFullscreen: false,
        showProgress: true,
        prepare: widget.prepare,
        soundOnTop: true,
        inset: EdgeInsets.only(top: widget.topInset, bottom: kNavInset),
        api: widget.api,
      ),
      // Okunaklılık için alt gradyan.
      Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: .42,
          widthFactor: 1,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [t.scrim.withValues(alpha: 0), t.scrim.withValues(alpha: .35), t.scrim.withValues(alpha: .72)],
                ),
              ),
            ),
          ),
        ),
      ),
      PositionedDirectional(
        start: BuSpace.page,
        end: 80,
        bottom: kNavInset + 14,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Yazar satırı: avatar + ad (profil; uzun basma = önizleme) ve yanında "Takip et" (kendi gönderi değilse).
          Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: AvatarPreviewTap(
                key: ValueKey('reel-author-${p.id}'),
                session: widget.session,
                url: p.author.avatarUrl,
                name: p.author.displayName,
                onTap: () => openUserProfile(context, widget.session,
                    userId: p.author.id, name: p.author.displayName, avatarUrl: p.author.avatarUrl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    DecoratedBox(
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: t.onMedia.withValues(alpha: .45), width: 1.5)),
                      child: Padding(
                        padding: const EdgeInsets.all(1.5),
                        child: BuAvatar(name: p.author.displayName, url: p.author.avatarUrl, size: 32, headers: postAuthHeaders(widget.session)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(p.author.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleSmall?.copyWith(color: t.onMedia, fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              ),
            ),
            if (_follow != null && !_mine && _follow!.followState != FollowState.self) ...[
              const SizedBox(width: 4),
              FollowStateButton(
                key: ValueKey('reel-follow-${p.id}'),
                session: widget.session,
                userId: p.author.id,
                state: _follow!.followState,
                isPrivate: _follow!.isPrivate,
                look: FollowLook.media,
                tapKey: ValueKey('reel-follow-btn-${p.id}'),
                onState: (st, _) {
                  _follow = _follow!.copyWith(followState: st);
                  widget.onFollowState(p.author.id, st);
                },
              ),
            ],
          ]),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 4),
            GestureDetector(
              key: ValueKey('reel-caption-${p.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = !_expanded),
              child: Text(text,
                  maxLines: _expanded ? null : 2,
                  overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: tt.bodyLarge?.copyWith(color: t.onMedia, fontSize: 15, height: 1.35)),
            ),
          ],
          if (p.viewCount != null && p.viewCount! > 0) ...[
            const SizedBox(height: 6),
            Text(l.kesViews('${p.viewCount}'),
                style: tt.labelMedium?.copyWith(color: t.onMedia.withValues(alpha: .75), fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ]),
      ),
      // Sağ eylem çubuğu: Beğen, Yorumlar, Kaydet, Üç nokta.
      PositionedDirectional(
        end: 4,
        bottom: kNavInset + 14,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          LikeButton(
            session: widget.session,
            post: p,
            tile: true,
            compact: true,
            size: 28,
            a11yCount: (n) => l.p04LikeCount('$n'),
            onChanged: widget.onChanged,
          ),
          if (p.commentCount != null)
            _RailButton(
              key: ValueKey('reel-comments-${p.id}'),
              icon: BuIcons.messageCircle,
              label: '${p.commentCount}',
              tooltip: l.kesActionComments,
              onTap: () => showReelsComments(context,
                  session: widget.session,
                  post: p,
                  repository: widget.comments,
                  onCountChanged: (n) => widget.onChanged(p.copyWith(commentCount: n))),
            ),
          if (p.savedByMe != null)
            _RailButton(
              key: ValueKey('reel-save-${p.id}'),
              icon: p.savedByMe! ? BuIcons.bookmarkFilled : BuIcons.bookmark,
              tooltip: p.savedByMe! ? l.kesActionSaved : l.kesActionSave,
              onTap: _toggleSave,
            ),
          _RailButton(
            key: ValueKey('reel-share-${p.id}'),
            icon: BuIcons.share2,
            tooltip: l.shareTitle,
            onTap: () => showShareSheet(context, widget.session, shareContentForPost(widget.session, p)),
          ),
          _RailButton(
            key: ValueKey('reel-menu-${p.id}'),
            icon: BuIcons.ellipsis,
            tooltip: l.kesMore,
            onTap: () => showPostActions(context,
                session: widget.session,
                post: p,
                notInterested: !mine,
                onEdited: widget.onChanged,
                onDeleted: widget.onRemoved),
          ),
        ]),
      ),
    ]);
  }
}

/// Eylem çubuğu düğmesi: 48 dp dokunma alanı, ikon + isteğe bağlı sayı (`onMedia`).
class _RailButton extends StatelessWidget {
  const _RailButton({super.key, required this.icon, required this.tooltip, required this.onTap, this.label});

  final IconData icon;
  final String tooltip;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: label == null ? tooltip : '$tooltip, $label',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: BuSize.touch, minHeight: BuSize.touch + 8),
          child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: t.onMedia, size: 26),
            if (label != null)
              Text(label!,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: t.onMedia, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
        ),
      ),
    );
  }
}

class _Act {
  const _Act(this.label, this.onTap, {this.key});

  final String label;
  final VoidCallback onTap;
  final Key? key;
}

/// Boş / hata / tükendi durumu: koyu zeminde başlık + gövde + eylemler.
class _Message extends StatelessWidget {
  const _Message({super.key, required this.title, required this.body, this.actions = const []});

  final String title;
  final String body;
  final List<_Act> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: BuSpace.xxxl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, textAlign: TextAlign.center, style: tt.titleMedium?.copyWith(color: t.onMedia, fontSize: 18, fontWeight: FontWeight.w600)),
          BuGap.h6,
          Text(body, textAlign: TextAlign.center, style: tt.bodyLarge?.copyWith(color: t.onMedia.withValues(alpha: .75), fontSize: 15)),
          BuGap.h16,
          for (final a in actions)
            TextButton(
              key: a.key,
              onPressed: a.onTap,
              style: TextButton.styleFrom(minimumSize: const Size(BuSize.touch, BuSize.touch), foregroundColor: t.onMedia),
              child: Text(a.label, style: tt.labelLarge?.copyWith(color: t.onMedia, fontSize: 15, fontWeight: FontWeight.w600)),
            ),
        ]),
      ),
    );
  }
}
