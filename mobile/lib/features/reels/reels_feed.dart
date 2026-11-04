import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart' show ApiError;
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../posts/feed_seen.dart';
import '../posts/like_button.dart';
import '../posts/popularity_meter.dart';
import '../posts/post_actions.dart';
import '../posts/post_api.dart';
import '../posts/post_models.dart';
import '../posts/post_routes.dart';
import '../posts/post_video.dart';

/// Reels: dikey, tam ekran video akışı (`GET /feed/reels`). Yalnız video gönderiler; sıralama sunucudaki popülerlik
/// puanıdır, görülmüş reeller hariç tutulur (tümü görüldüyse `exhausted` ile baştan). Her sayfa ekranı doldurur;
/// yalnız göründüğü sayfa oynar. Dokununca oynat/duraklat, sağ altta ses; ilerleme çizgisi altta.
///
/// [active] false iken (Keşfet'te "Gönderiler" görünümü ya da başka sekme) oynatma durur. İlk etkinleşmede yüklenir;
/// uzun süre sonra geri dönülürse akış yenilenir (aynı reeller yine gelmesin).
class ReelsFeed extends StatefulWidget {
  const ReelsFeed({super.key, required this.session, required this.active, this.onCompose, this.api, this.topInset = 0});

  final Session session;
  final bool active;
  final VoidCallback? onCompose;
  final PostApi? api;

  /// Üstte (durum çubuğu + segment) boş bırakılacak alan: yazılar buraya taşmaz.
  final double topInset;

  @override
  State<ReelsFeed> createState() => _ReelsFeedState();
}

class _ReelsFeedState extends State<ReelsFeed> {
  static const _pageSize = 6;

  /// Etkinleşmede akışı yenilemek için gereken boşta kalma süresi.
  static const _staleAfter = Duration(minutes: 3);

  final PageController _pager = PageController();
  late final PostApi _api = widget.api ?? PostApi(widget.session);
  late final FeedSeenReporter _seen = FeedSeenReporter(_api);
  final List<Post> _items = [];

  String? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  bool _loaded = false;
  Object? _error;
  int _index = 0;
  int _gen = 0;
  DateTime? _loadedAt;

  /// Üstte başka bir rota açıkken (ör. yazar profili) oynatma durur.
  bool _routeCurrent = true;

  bool get _on => widget.active && _routeCurrent;

  @override
  void initState() {
    super.initState();
    if (widget.active) _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeCurrent = ModalRoute.of(context)?.isCurrent ?? true;
  }

  @override
  void didUpdateWidget(ReelsFeed old) {
    super.didUpdateWidget(old);
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
    _seen.dispose();
    _pager.dispose();
    super.dispose();
  }

  /// Kaydırma konumundaki reeli "görüldü" işaretler (yalnız gerçekten ekrandayken).
  void _markCurrent() {
    if (!widget.active || _index < 0 || _index >= _items.length) return;
    _seen.mark(_items[_index].id);
  }

  Future<void> _reload() async {
    final gen = ++_gen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _api.reels(size: _pageSize);
      if (!mounted || gen != _gen) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items.where((p) => p.isVideo));
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loaded = true;
        _loading = false;
        _index = 0;
        _loadedAt = DateTime.now();
      });
      if (_pager.hasClients) _pager.jumpToPage(0);
      if (page.exhausted && _items.isNotEmpty) BuToast.show(context, context.l10n.kesSeenAll);
      _markCurrent();
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _loading = false;
        if (!_loaded) _error = e;
      });
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
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      // Bozuk imleç ya da ağ hatası: sessizce dur; kullanıcı yukarı-aşağı kaydırınca yeniden denenir.
      setState(() {
        _loading = false;
        if (e is ApiError && e.code == 'POST_CURSOR_INVALID') _hasMore = false;
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

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final Widget body;
    if (!_loaded && _error == null) {
      body = Center(child: CircularProgressIndicator(key: const ValueKey('reelsLoading'), strokeWidth: 2, color: t.onMedia));
    } else if (_error != null && !_loaded) {
      body = _Message(
        key: const ValueKey('reelsError'),
        title: context.l10n.p04FeedErrTitle,
        body: context.l10n.p04FeedErrBody,
        action: context.l10n.postViewRetry,
        onAction: _reload,
      );
    } else if (_items.isEmpty) {
      body = _Message(
        key: const ValueKey('reelsEmpty'),
        title: context.l10n.kesReelsEmptyTitle,
        body: context.l10n.kesReelsEmptyBody,
        action: widget.onCompose == null ? null : context.l10n.discoverCompose,
        onAction: widget.onCompose,
      );
    } else {
      body = PageView.builder(
        key: const ValueKey('reelsPager'),
        controller: _pager,
        scrollDirection: Axis.vertical,
        itemCount: _items.length,
        onPageChanged: _onPage,
        itemBuilder: (_, i) {
          final p = _items[i];
          return _ReelPage(
            key: ValueKey('reel-${p.id}'),
            session: widget.session,
            post: p,
            active: _on && i == _index,
            topInset: widget.topInset,
            api: _api,
            onChanged: _changed,
            onRemoved: () => _removed(p.id),
          );
        },
      );
    }
    return ColoredBox(color: t.scrim, child: body);
  }
}

/// Tek reel: tam ekran video + alt sol yazar/metin/puan, sağ alt beğeni ve menü.
class _ReelPage extends StatelessWidget {
  const _ReelPage({
    super.key,
    required this.session,
    required this.post,
    required this.active,
    required this.topInset,
    required this.api,
    required this.onChanged,
    required this.onRemoved,
  });

  final Session session;
  final Post post;
  final bool active;
  final double topInset;
  final PostApi api;
  final ValueChanged<Post> onChanged;
  final VoidCallback onRemoved;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final p = post;
    final text = (p.text ?? '').trim();
    final mine = p.mine || p.author.id == session.userId;
    final hasMenu = !(mine && !p.canEdit && !p.canDelete);
    return Stack(fit: StackFit.expand, children: [
      PostVideoView(
        session: session,
        post: p,
        active: active,
        fit: p.video!.aspect >= 1 ? BoxFit.contain : BoxFit.cover,
        tap: PostVideoTap.playPause,
        showFullscreen: false,
        showProgress: true,
        soundOnTop: true,
        inset: EdgeInsets.only(top: topInset, bottom: kNavInset),
        api: api,
      ),
      // Okunaklılık için alt gradyan.
      Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: .4,
          widthFactor: 1,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [t.scrim.withValues(alpha: 0), t.scrim.withValues(alpha: .35), t.scrim.withValues(alpha: .7)],
                ),
              ),
            ),
          ),
        ),
      ),
      PositionedDirectional(
        start: BuSpace.page,
        end: 76,
        bottom: kNavInset + 14,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            key: ValueKey('reel-author-${p.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => openUserPosts(context, session, userId: p.author.id, name: p.author.displayName),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: t.onMedia.withValues(alpha: .45), width: 1.5)),
                  child: Padding(
                    padding: const EdgeInsets.all(1.5),
                    child: BuAvatar(name: p.author.displayName, url: p.author.avatarUrl, size: 32, headers: postAuthHeaders(session)),
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
          if (text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: tt.bodyLarge?.copyWith(color: t.onMedia, fontSize: 15, height: 1.35)),
          ],
          if (p.popularityScore != null) ...[
            const SizedBox(height: 10),
            PopularityMeter(score: p.popularityScore!, onMedia: true, width: 72),
          ],
        ]),
      ),
      PositionedDirectional(
        end: 8,
        bottom: kNavInset + 14,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          LikeButton(
            session: session,
            post: p,
            tile: true,
            compact: true,
            size: 28,
            a11yCount: (n) => context.l10n.p04LikeCount('$n'),
            onChanged: onChanged,
          ),
          if (hasMenu)
            IconButton(
              key: ValueKey('reel-menu-${p.id}'),
              tooltip: context.l10n.postComposeEdit,
              constraints: const BoxConstraints(minWidth: BuSize.touch, minHeight: BuSize.touch),
              icon: Icon(BuIcons.ellipsis, color: t.onMedia, size: 24),
              onPressed: () => showPostActions(context, session: session, post: p, onEdited: onChanged, onDeleted: onRemoved),
            ),
        ]),
      ),
    ]);
  }
}

/// Boş / hata durumu: koyu zeminde başlık + gövde + tek eylem.
class _Message extends StatelessWidget {
  const _Message({super.key, required this.title, required this.body, this.action, this.onAction});

  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

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
          if (action != null && onAction != null) ...[
            BuGap.h16,
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(minimumSize: const Size(BuSize.touch, BuSize.touch), foregroundColor: t.onMedia),
              child: Text(action!, style: tt.labelLarge?.copyWith(color: t.onMedia, fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ]),
      ),
    );
  }
}
