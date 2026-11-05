import 'package:flutter/material.dart';

import '../../core/api.dart' show ApiError;
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart' show ErrorView;
import '../discover/discover_prefetch.dart';
import 'feed_pager.dart';
import 'feed_seen.dart';
import 'post_api.dart';
import 'post_card.dart';
import 'post_models.dart';
import 'post_pager.dart';
import 'post_stream.dart';

/// Gönderi sayfası: dikey kaydırmalı akış (Instagram Keşfet gibi). Açılan gönderi AKIŞIN ORTASINDA başlar; yukarı
/// kaydırınca ızgarada ondan ÖNCE gelenler, aşağı kaydırınca ondan sonrakiler ve ızgaranın sonundan sonra sunucudan
/// RASTGELE (yeni oturum tohumu) gelen gönderiler görünür ([PostPager], [PostStreamSeed]). [stream] yoksa yalnız o
/// gönderi gösterilir.
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

  /// Akışın yukarı/aşağı kısımları (null: tek gönderi).
  final PostStreamSeed? stream;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final _scroll = ScrollController();
  late final PostApi _api = PostApi(widget.session);
  late final FeedSeenReporter _seen = FeedSeenReporter(_api);
  late final DiscoverPrefetch _prefetch = DiscoverPrefetch(widget.session);
  FeedPager? _pager;

  /// Açılan gönderinin ÜSTÜNDEKİLER (ızgara sırası).
  final List<Post> _before = [];

  /// [0] = açılan gönderi, sonrası akış.
  final List<Post> _after = [];
  Object? _postError;

  bool _loadingMore = false;
  Object? _moreError;

  @override
  void initState() {
    super.initState();
    final seed = widget.stream;
    final first = widget.initial;
    if (first != null) _after.add(first);
    if (seed != null) {
      final seen = {widget.postId};
      _before.addAll(seed.before.where((e) => seen.add(e.id)));
      _after.addAll(seed.items.where((e) => seen.add(e.id)));
      // Izgaranın sonundan sonra: imleçsiz (yeni tohum) sayfalar; ekrandakiler tekilleştirilir.
      if (seed.hasMore) _pager = FeedPager(_api, scope: seed.scope);
    }
    _scroll.addListener(_onScroll);
    _loadPost();
    _warm();
  }

  @override
  void dispose() {
    _seen.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _warm() => _prefetch.onItems(_after, from: 0);

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 600) _loadMore();
  }

  Future<void> _loadPost() async {
    try {
      final p = await _api.get(widget.postId);
      if (!mounted) return;
      setState(() {
        final i = _after.indexWhere((e) => e.id == widget.postId);
        if (i >= 0) {
          _after[i] = p;
        } else {
          _after.insert(0, p);
        }
        _postError = null;
      });
      widget.onChanged?.call(p);
      _afterLoad();
    } catch (e) {
      if (!mounted) return;
      // Eldeki gönderi varsa sessizce onu göster; 404/yok ise sayfa hata verir.
      if (_after.isEmpty || (e is ApiError && e.status == 404)) {
        setState(() => _postError = e);
      }
    }
  }

  /// Gönderi alındıktan sonra: akış hiç yüklenmemişse (derin bağlantı) ilk sayfayı iste; ekran dolmuyorsa sonrakini.
  void _afterLoad() {
    final seed = widget.stream;
    if (seed == null) return;
    if (!seed.primed && _after.length <= 1) _loadMore();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pager = _pager;
      if (mounted && pager != null && !pager.ended && _scroll.hasClients && _scroll.position.maxScrollExtent <= 0) _loadMore();
    });
  }

  Set<int> get _have => {for (final p in _before) p.id, for (final p in _after) p.id};

  Future<void> _loadMore() async {
    final pager = _pager;
    if (pager == null || pager.ended || _loadingMore || _postError != null || _after.isEmpty) return;
    setState(() {
      _loadingMore = true;
      _moreError = null;
    });
    try {
      final chunk = await pager.next(_have);
      if (!mounted) return;
      setState(() {
        _after.addAll(chunk.items);
        _loadingMore = false;
      });
      _warm();
      _afterLoad();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        // Akış hiç alınamadıysa (derin bağlantı): sessizce yalnız açılan gönderi kalır. Sonradan olursa "Yeniden dene".
        if (_after.length <= 1 && _before.isEmpty && widget.stream?.primed == false) {
          pager.ended = true;
        } else {
          _moreError = e;
        }
      });
    }
  }

  void _onPostChanged(Post p) {
    if (!mounted) return;
    var found = false;
    for (final list in [_after, _before]) {
      final i = list.indexWhere((e) => e.id == p.id);
      if (i >= 0) {
        found = true;
        setState(() => list[i] = p);
        break;
      }
    }
    if (found) widget.onChanged?.call(p);
  }

  void _onPostDeleted(int id) {
    widget.onDeleted?.call(id);
    if (!mounted) return;
    setState(() {
      _after.removeWhere((e) => e.id == id);
      _before.removeWhere((e) => e.id == id);
    });
    // Akışta hiç gönderi kalmadıysa sayfa kapanır (tek gönderi silinince önceki davranış).
    if (_after.isEmpty && _before.isEmpty) Navigator.of(context).pop();
  }

  /// Açılan gönderinin güncel hâli (silindiyse null).
  Post? get _head {
    for (final p in _after) {
      if (p.id == widget.postId) return p;
    }
    return null;
  }

  void _close() => Navigator.of(context).pop(_head);

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final fatal = _postError != null && _after.isEmpty;
    final Widget content;
    if (fatal) {
      content = (_postError is ApiError && (_postError as ApiError).status == 404)
          ? const _NotFound(key: ValueKey('postNotFound'))
          : ErrorView(
              error: _postError!,
              onRetry: () {
                setState(() => _postError = null);
                _loadPost();
              });
    } else if (_after.isEmpty) {
      content = const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: Padding(padding: EdgeInsets.fromLTRB(BuSpace.page, BuSpace.sm, BuSpace.page, 0), child: PostCardSkeleton()),
      );
    } else {
      content = PostPager(
        controller: _scroll,
        before: _before,
        after: _after,
        bottomPadding: MediaQuery.paddingOf(context).bottom + BuSpace.xxl,
        footer: _footer(),
        itemBuilder: (_, p) {
          _seen.mark(p.id);
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
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: t.bg,
        body: Column(children: [
          _TopBar(onBack: _close),
          Expanded(child: content),
        ]),
      ),
    );
  }

  Widget? _footer() {
    if (_moreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: BuSpace.sm),
        child: Center(
          child: BuButton(label: context.l10n.postViewRetry, compact: true, kind: BuButtonKind.outline, onPressed: _loadMore),
        ),
      );
    }
    if (!_loadingMore) return null;
    // Sayfa sonu iskeleti: sıradaki gönderinin avatar + 2 çubuk + 4:5 blok + çubuğu (PostCardSkeleton).
    return const Padding(
      key: ValueKey('postStreamSkeleton'),
      padding: EdgeInsets.fromLTRB(BuSpace.page, BuSpace.sm, BuSpace.page, 0),
      child: PostCardSkeleton(),
    );
  }
}

/// Sabit üst çubuk (56 dp): geri düğmesi (24 dp ok, 48 dp dokunma alanı) + alt çizgi (başlık metni görünmez, yalnız anlamsal etiket).
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return DecoratedBox(
      decoration: BoxDecoration(color: t.bg, border: Border(bottom: BorderSide(color: t.bd))),
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        child: SizedBox(
          height: 56,
          child: Row(children: [
            BuGap.w4,
            Semantics(
              button: true,
              label: context.l10n.commonBack,
              child: BuPressable(
                scale: .92,
                child: GestureDetector(
                  key: const ValueKey('postBack'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onBack,
                  child: SizedBox(
                    width: BuSize.touch,
                    height: BuSize.touch,
                    child: Center(child: ExcludeSemantics(child: Icon(buDirIcon(context, BuIcons.arrowLeft), size: 24, color: t.ink))),
                  ),
                ),
              ),
            ),
            BuGap.w8,
            Expanded(
              child: Semantics(header: true, label: context.l10n.postViewPost, child: const SizedBox.shrink()),
            ),
          ]),
        ),
      ),
    );
  }
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
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: t.ink, fontSize: 18, fontWeight: FontWeight.w400)),
          if (detail != null) ...[
            BuGap.h6,
            Text(detail, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: t.mut, fontSize: 15)),
          ],
        ]),
      ),
    );
  }
}
