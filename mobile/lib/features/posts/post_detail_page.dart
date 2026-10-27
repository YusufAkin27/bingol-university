import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart' show ApiError;
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart' show EmptyView, ErrorView;
import 'comment_composer.dart';
import 'comment_controller.dart';
import 'comment_models.dart';
import 'comment_thread.dart';
import 'like_button.dart';
import 'post_actions.dart';
import 'post_api.dart';
import 'post_card.dart';
import 'post_media_gallery.dart';
import 'post_media_view.dart';
import 'post_models.dart';

/// Gönderi detayı: gönderi + yorum bölümü (Yeni | Üst), iç içe yanıtlar, altta yorum yazma çubuğu.
///
/// Sayfa kapanırken güncel [Post] ile pop edilir; ayrıca [onChanged] her değişimde çağrılır
/// (yorum sayısı, beğeni, düzenleme). [focusCommentId]: bildirimden gelen yoruma kaydırıp vurgular.
class PostDetailPage extends StatefulWidget {
  const PostDetailPage({
    super.key,
    required this.session,
    required this.postId,
    this.initial,
    this.focusCommentId,
    this.onChanged,
    this.onDeleted,
  });

  final Session session;
  final int postId;
  final Post? initial;
  final int? focusCommentId;
  final ValueChanged<Post>? onChanged;
  final ValueChanged<int>? onDeleted;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late final CommentsController _ctl;
  final _scroll = ScrollController();
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _commentsKey = GlobalKey();
  final _focusKey = GlobalKey();

  Post? _post;
  Object? _postError;
  CNode? _replyTo;
  String? _sendError;
  int? _highlightId;
  Timer? _highlightTimer;
  bool _loadMoreQueued = false;

  @override
  void initState() {
    super.initState();
    _post = widget.initial;
    _ctl = CommentsController(widget.session, widget.postId, onCountDelta: _countDelta)..addListener(_onCtl);
    _scroll.addListener(_maybeLoadMore);
    _loadPost();
    _ctl.load().then((_) => _focusComment());
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _ctl
      ..removeListener(_onCtl)
      ..dispose();
    _scroll.dispose();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onCtl() {
    if (!mounted) return;
    setState(() {});
    _queueLoadMore();
  }

  void _queueLoadMore() {
    if (_loadMoreQueued) return;
    _loadMoreQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMoreQueued = false;
      _maybeLoadMore();
    });
  }

  void _maybeLoadMore() {
    if (!mounted || !_ctl.canLoadMore) return;
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.extentAfter < 400) _ctl.loadMore();
  }

  Future<void> _loadPost() async {
    try {
      final p = await PostApi(widget.session).get(widget.postId);
      if (!mounted) return;
      setState(() {
        _post = p;
        _postError = null;
      });
      widget.onChanged?.call(p);
    } catch (e) {
      if (!mounted) return;
      // Eldeki gönderi varsa sessizce onu göster; 404/yok ise sayfa hata verir.
      if (_post == null || (e is ApiError && e.status == 404)) setState(() => _postError = e);
    }
  }

  void _countDelta(int d) {
    final p = _post;
    if (p == null || !mounted) return;
    final next = p.copyWith(commentCount: (p.commentCount + d).clamp(0, 1 << 30));
    _post = next;
    widget.onChanged?.call(next);
  }

  void _onPostChanged(Post p) {
    if (!mounted) return;
    setState(() => _post = p);
    widget.onChanged?.call(p);
  }

  void _onPostDeleted(int id) {
    widget.onDeleted?.call(id);
    if (mounted) Navigator.of(context).pop();
  }

  void _close() => Navigator.of(context).pop(_post);

  // ---- Odak (bildirimden gelen yorum) ----

  Future<void> _focusComment() async {
    final id = widget.focusCommentId;
    if (id == null || !mounted) return;
    final node = await _ctl.reveal(id);
    if (node == null || !mounted) return;
    setState(() => _highlightId = id);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) setState(() => _highlightId = null);
    });
    unawaited(_scrollToFocus());
  }

  Future<void> _scrollToFocus([int attempt = 0]) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final ctx = _focusKey.currentContext;
    if (ctx != null && ctx.mounted) {
      await Scrollable.ensureVisible(ctx, alignment: .3, duration: const Duration(milliseconds: 300));
      return;
    }
    if (attempt >= 12 || !_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent) return;
    _scroll.jumpTo((pos.pixels + pos.viewportDimension * .8).clamp(0, pos.maxScrollExtent));
    await _scrollToFocus(attempt + 1);
  }

  // ---- Gönderme ----

  void _startReply(CNode n) {
    if (n.c.isTemp) return;
    setState(() => _replyTo = n);
    _focus.requestFocus();
  }

  void _cancelReply() => setState(() => _replyTo = null);

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    final target = _replyTo;
    _text.clear();
    setState(() {
      _replyTo = null;
      _sendError = null;
    });
    if (target == null) _revealComments();
    final r = await _ctl.send(text, replyTo: target);
    if (!mounted) return;
    if (!r.ok && r.removed) {
      // Doğrulama / hız sınırı: metin kaybolmasın, mesaj çubuğun altında görünsün.
      if (_text.text.isEmpty) _text.text = text;
      setState(() {
        _sendError = r.error;
        _replyTo = target;
      });
    }
  }

  void _revealComments() {
    final ctx = _commentsKey.currentContext;
    if (ctx == null || !_scroll.hasClients) return;
    Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250), alignment: 0);
  }

  Future<void> _refresh() => Future.wait([_loadPost(), _ctl.load(refresh: true)]);

  // ---- Görünüm ----

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final fatal = _postError != null && _post == null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: t.bg,
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            BuHeader(title: 'Gönderi', onBack: _close),
            const SizedBox(height: 8),
            Expanded(
              child: fatal
                  ? ErrorView(error: _postError!, onRetry: () {
                      setState(() => _postError = null);
                      _loadPost();
                    })
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: CustomScrollView(
                        controller: _scroll,
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(child: _postHeader(t)),
                          SliverToBoxAdapter(child: _commentsHeader(t)),
                          ..._commentSlivers(t),
                          SliverToBoxAdapter(child: CommentsFooter(controller: _ctl)),
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                        ],
                      ),
                    ),
            ),
            if (!fatal)
              CommentComposer(
                controller: _text,
                focusNode: _focus,
                session: widget.session,
                onSend: _send,
                replyingTo: _replyTo?.c.author.displayName,
                onCancelReply: _cancelReply,
                error: _sendError,
              ),
          ],
        ),
      ),
    );
  }

  Widget _postHeader(BuTokens t) {
    final p = _post;
    if (p == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Container(
          height: 120,
          decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(20)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: PostCard(
        session: widget.session,
        post: p,
        onChanged: _onPostChanged,
        onDeleted: _onPostDeleted,
        onOpen: (_) {},
        expandable: false,
        mediaBuilder: (c, post) => PostMediaView(
          session: widget.session,
          media: post.media,
          autoplay: true,
          onOpen: (i) => openPostMediaGallery(c, widget.session, post.media, i),
        ),
        likeBuilder: (c, post, cb) => LikeButton(session: widget.session, post: post, onChanged: cb),
        menuBuilder: (c, post, cb, del) =>
            PostMenuButton(session: widget.session, post: post, onChanged: cb, onDeleted: del),
      ),
    );
  }

  Widget _commentsHeader(BuTokens t) {
    final count = _post?.commentCount ?? _ctl.total;
    return Padding(
      key: _commentsKey,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(count > 0 ? 'Yorumlar ($count)' : 'Yorumlar',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.heading.copyWith(color: t.ink)),
          ),
          BuChip(label: 'Yeni', selected: _ctl.sort == 'new', onTap: () => _ctl.setSort('new')),
          const SizedBox(width: 8),
          BuChip(label: 'Üst', selected: _ctl.sort == 'top', onTap: () => _ctl.setSort('top')),
        ],
      ),
    );
  }

  List<Widget> _commentSlivers(BuTokens t) {
    if (_ctl.loading) return const [SliverToBoxAdapter(child: CommentsSkeleton())];
    if (_ctl.error != null) {
      return [SliverToBoxAdapter(child: CommentsError(error: _ctl.error!, onRetry: _ctl.load))];
    }
    if (_ctl.roots.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: EmptyView(icon: LucideIcons.messageCircle, text: 'İlk yorumu sen yaz'),
          ),
        ),
      ];
    }
    final roots = _ctl.roots;
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverList.builder(
          itemCount: roots.length,
          itemBuilder: (_, i) => CommentThread(
            key: ValueKey('thread-${roots[i].c.id}'),
            node: roots[i],
            controller: _ctl,
            session: widget.session,
            onReply: _startReply,
            highlightId: _highlightId,
            focusId: widget.focusCommentId,
            focusKey: _focusKey,
          ),
        ),
      ),
    ];
  }
}
