import '../../core/analytics.dart';
import 'package:flutter/material.dart';

import '../../core/api.dart' show ApiError;
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart' show ErrorView;
import 'post_api.dart';
import 'post_card.dart';
import 'post_models.dart';
import 'post_stream.dart';

/// Gönderi sayfası (Stitch v3 kesfet2 08/09): açılan gönderi en üstte, altında [stream] ile akışın sıradaki
/// gönderileri aynı detay düzeninde alt alta (sonsuz kaydırma). [stream] yoksa yalnız o gönderi gösterilir.
///
/// Sayfa kapanırken açılan gönderinin güncel [Post] hâliyle pop edilir; akıştaki HERHANGİ bir gönderide olan
/// değişim (beğeni, düzenleme) [onChanged], silme/engelleme [onDeleted] ile anında bildirilir.
class PostDetailPage extends StatefulWidget {
  const PostDetailPage({
    super.key,
    required this.session,
    required this.postId,
    this.initial,
    this.onChanged,
    this.onDeleted,
    this.heroTag,
    this.stream,
  });

  /// Listeden gelen fotoğraf Hero etiketi (yoksa uçuş yok). Yalnız açılan (ilk) gönderiye uygulanır.
  final Object? heroTag;

  final Session session;
  final int postId;
  final Post? initial;
  final ValueChanged<Post>? onChanged;
  final ValueChanged<int>? onDeleted;

  /// Gönderinin altında sürecek akış (null: tek gönderi).
  final PostStreamSeed? stream;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  static const _pageSize = 12;

  /// Kaydırma bu eşiği aşınca başlık kaybolur ve geri düğmesi yuvarlak zemin kazanır (Stitch v3 09).
  static const _scrolledAt = 24.0;

  final _scroll = ScrollController();
  late final PostApi _api = PostApi(widget.session);

  /// [0] = açılan gönderi, sonrası akış.
  final List<Post> _posts = [];
  Object? _postError;

  String? _cursor;
  bool _hasMore = false;
  bool _loadingMore = false;
  Object? _moreError;
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    final seed = widget.stream;
    final first = widget.initial;
    if (first != null) _posts.add(first);
    if (seed != null) {
      final seen = {for (final p in _posts) p.id, widget.postId};
      _posts.addAll(seed.items.where((e) => seen.add(e.id)));
      _cursor = seed.cursor;
      _hasMore = seed.hasMore;
    }
    _scroll.addListener(_onScroll);
    _loadPost();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final s = _scroll.position.pixels > _scrolledAt;
    if (s != _scrolled) setState(() => _scrolled = s);
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 500) _loadMore();
  }

  Future<void> _loadPost() async {
    try {
      final p = await _api.get(widget.postId);
      if (!mounted) return;
      setState(() {
        final i = _posts.indexWhere((e) => e.id == widget.postId);
        if (i >= 0) {
          _posts[i] = p;
        } else {
          _posts.insert(0, p);
        }
        _postError = null;
      });
      widget.onChanged?.call(p);
      _afterLoad();
    } catch (e) {
      if (!mounted) return;
      // Eldeki gönderi varsa sessizce onu göster; 404/yok ise sayfa hata verir.
      if (_posts.isEmpty || (e is ApiError && e.status == 404)) {
        setState(() => _postError = e);
      }
    }
  }

  /// Gönderi alındıktan sonra: akış hiç yüklenmemişse (derin bağlantı) ilk sayfayı iste; ekran dolmuyorsa sonrakini.
  void _afterLoad() {
    final seed = widget.stream;
    if (seed == null) return;
    if (!seed.primed && _cursor == null && _posts.length <= 1) _loadMore();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _hasMore && _scroll.hasClients && _scroll.position.maxScrollExtent <= 0) _loadMore();
    });
  }

  Future<void> _loadMore() async {
    final seed = widget.stream;
    if (seed == null || _loadingMore || !_hasMore || _postError != null || _posts.isEmpty) return;
    setState(() {
      _loadingMore = true;
      _moreError = null;
    });
    try {
      final page = await _api.feed(scope: seed.scope, cursor: _cursor, size: _pageSize);
      if (!mounted) return;
      setState(() {
        final seen = {for (final p in _posts) p.id};
        _posts.addAll(page.items.where((e) => seen.add(e.id)));
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
      _afterLoad();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        // Akış hiç alınamadıysa (derin bağlantı): sessizce yalnız açılan gönderi kalır. Sonradan olursa "Yeniden dene".
        if (_posts.length <= 1 && !seed.primed || (e is ApiError && e.code == 'POST_CURSOR_INVALID')) {
          _hasMore = false;
        } else {
          _moreError = e;
        }
      });
    }
  }

  void _onPostChanged(Post p) {
    if (!mounted) return;
    final i = _posts.indexWhere((e) => e.id == p.id);
    if (i >= 0) setState(() => _posts[i] = p);
    widget.onChanged?.call(p);
  }

  void _onPostDeleted(int id) {
    widget.onDeleted?.call(id);
    if (!mounted) return;
    setState(() => _posts.removeWhere((e) => e.id == id));
    // Akışta hiç gönderi kalmadıysa sayfa kapanır (tek gönderi silinince önceki davranış).
    if (_posts.isEmpty) Navigator.of(context).pop();
  }

  /// Açılan gönderinin güncel hâli (silindiyse null).
  Post? get _head {
    for (final p in _posts) {
      if (p.id == widget.postId) return p;
    }
    return null;
  }

  void _close() => Navigator.of(context).pop(_head);

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final fatal = _postError != null && _posts.isEmpty;
    final Widget content;
    if (fatal) {
      content = Column(children: [
        const _TitleBar(),
        Expanded(
          child: (_postError is ApiError && (_postError as ApiError).status == 404)
              ? const _NotFound(key: ValueKey('postNotFound'))
              : ErrorView(
                  error: _postError!,
                  onRetry: () {
                    setState(() => _postError = null);
                    _loadPost();
                  }),
        ),
      ]);
    } else {
      final loadingHead = _posts.isEmpty;
      final extra = loadingHead ? 0 : (_loadingMore || _moreError != null ? 1 : 0);
      content = RefreshIndicator(
        onRefresh: Analytics.pullRefresh(_loadPost),
        child: CustomScrollView(
          key: const ValueKey('postStream'),
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: _TitleBar()),
            if (loadingHead)
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(BuSpace.page, BuSpace.sm, BuSpace.page, 0), child: PostCardSkeleton()))
            else
              SliverList.separated(
                itemCount: _posts.length + extra,
                findItemIndexCallback: (k) {
                  if (k is! ValueKey<String>) return null;
                  final i = _posts.indexWhere((e) => 'stream-post-${e.id}' == k.value);
                  return i < 0 ? null : i;
                },
                separatorBuilder: (_, __) => const _StreamDivider(),
                itemBuilder: (_, i) {
                  if (i >= _posts.length) return _footer();
                  final p = _posts[i];
                  return PostCard(
                    key: ValueKey('stream-post-${p.id}'),
                    session: widget.session,
                    post: p,
                    detail: true,
                    heroTag: p.id == widget.postId ? widget.heroTag : null,
                    onChanged: _onPostChanged,
                    onDeleted: _onPostDeleted,
                  );
                },
              ),
            SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + BuSpace.xxl)),
          ],
        ),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: t.bg,
        body: Stack(children: [
          Positioned.fill(child: content),
          // Geri düğmesi SABİT: içerik altından kayar; kaydırınca yuvarlak zemin belirir (Stitch v3 09).
          PositionedDirectional(
            start: 6,
            top: MediaQuery.paddingOf(context).top + 4,
            child: _BackButton(scrolled: _scrolled, onTap: _close),
          ),
        ]),
      ),
    );
  }

  Widget _footer() {
    if (_moreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: BuSpace.sm),
        child: Center(
          child: BuButton(label: context.l10n.postViewRetry, compact: true, kind: BuButtonKind.outline, onPressed: _loadMore),
        ),
      );
    }
    // Sayfa sonu iskeleti: sıradaki gönderinin avatar + 2 çubuk + 4:5 blok + çubuğu (PostCardSkeleton).
    return const Padding(
      key: ValueKey('postStreamSkeleton'),
      padding: EdgeInsets.fromLTRB(BuSpace.page, BuSpace.sm, BuSpace.page, 0),
      child: PostCardSkeleton(),
    );
  }
}

/// Üst çubuk başlığı (56 dp, "Gönderi" 18/600): içerikle birlikte kayıp kaybolur. Geri düğmesi ayrı, sabit katmandır;
/// başlık onun yanından (60 dp) başlar.
class _TitleBar extends StatelessWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      padding: EdgeInsetsDirectional.only(start: 60, end: BuSpace.page, top: MediaQuery.paddingOf(context).top),
      child: SizedBox(
        height: 56,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Semantics(
            header: true,
            child: Text(context.l10n.postViewPost,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: t.ink, fontSize: 18, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}

/// Sabit geri düğmesi: 24 dp ok, 48 dp dokunma alanı. Kaydırılınca (>24 dp) 40 dp yuvarlak `sf` %94 zemin + 1 dp `bd`
/// çizgi 120 ms'de belirir (yalnız opacity). Hareket azaltılmışsa anında.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.scrolled, required this.onTap});

  final bool scrolled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: context.l10n.commonBack,
      child: BuPressable(
        scale: .92,
        child: GestureDetector(
          key: const ValueKey('postBack'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: BuSize.touch,
            height: BuSize.touch,
            child: Stack(alignment: Alignment.center, children: [
              AnimatedOpacity(
                opacity: scrolled ? .94 : 0,
                duration: BuMotion.of(context, const Duration(milliseconds: 120)),
                child: DecoratedBox(
                  key: const ValueKey('postBackCircle'),
                  decoration: BoxDecoration(color: t.sf, shape: BoxShape.circle, border: Border.all(color: t.bd)),
                  child: const SizedBox(width: 40, height: 40),
                ),
              ),
              ExcludeSemantics(child: Icon(buDirIcon(context, BuIcons.arrowLeft), size: 24, color: t.ink)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Gönderiler arası ayırıcı (Stitch v3 08): 1 dp `bd` çizgi (20 dp kenar) + altında 24 dp boşluk. Gönderinin kendi alt
/// boşluğu (16) çizginin üstündeki payı verir.
class _StreamDivider extends StatelessWidget {
  const _StreamDivider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(BuSpace.page, 0, BuSpace.page, BuSpace.xxl),
        child: Divider(key: const ValueKey('postStreamDivider'), height: 1, thickness: 1, color: context.bu.bd),
      );
}

/// "Gönderi bulunamadı (silinmiş veya gizlenmiş olabilir)": kart/gölge yok, tek simge + tek cümle.
class _NotFound extends StatelessWidget {
  const _NotFound({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    // "Gönderi bulunamadı (silinmiş veya gizlenmiş olabilir)": başlık + soluk ikinci satır (Stitch v3).
    final raw = context.l10n.p04PostNotFound;
    final i = raw.indexOf('(');
    final title = i > 0 ? raw.substring(0, i).trim() : raw;
    final detail = i > 0 ? raw.substring(i + 1).replaceAll(')', '').trim() : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.xxxl, BuSpace.page, 0),
      child: Align(
        alignment: Alignment.topCenter,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: t.ink, fontSize: 18, fontWeight: FontWeight.w600)),
          if (detail != null) ...[
            BuGap.h6,
            Text(detail, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: t.mut, fontSize: 15)),
          ],
        ]),
      ),
    );
  }
}
