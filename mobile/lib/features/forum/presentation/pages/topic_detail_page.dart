import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/api.dart' show ApiError;
import '../../../../core/icons/bu_icons.dart';
import '../../../../core/locale_controller.dart';
import '../../../../core/session.dart';
import '../../../../core/theme.dart';
import '../../../../core/theme/bu_motion.dart';
import '../../../../widgets/bu_overlays.dart';
import '../../../../widgets/bu_skeleton.dart';
import '../../../../widgets/bu_state.dart';
import '../../../profile/user_profile_page.dart';
import '../../data/forum_api.dart';
import '../../data/forum_models.dart';
import '../../forum_routes.dart' show openEditTopic, openReportSheet;
import '../widgets/comment_card.dart' show commentAuthorName;
import '../widgets/comment_composer.dart';
import '../widgets/comment_controller.dart';
import '../widgets/comment_interactions.dart';
import '../widgets/comment_section.dart';
import '../widgets/comment_tree.dart';
import '../widgets/topic_detail_header.dart';
import '../widgets/topic_detail_menu.dart';
import '../widgets/topic_detail_share.dart';
import 'comment_thread_page.dart';

/// Anket parçasının bağlantı noktası (MB-C `PollView`): konu ve güncel anket değişikliği bildirimi verilir.
typedef TopicPollBuilder = Widget Function(BuildContext context, ForumApi api, TopicView topic, ValueChanged<ForumPoll> onChanged);

/// Konu detayı: yazar, kategori, tarih, başlık, TAM açıklama, görseller, anket, beğeni / yorum / kaydet / takip /
/// paylaş; altında Reddit tarzı iç içe yorumlar ve klavyeye uyumlu sabit yazma çubuğu.
///
/// * [commentId] verilirse (bağlantı / bildirim) o yoruma inilir ve vurgulanır.
/// * Kapanırken güncel [TopicSummary] döner (liste kartı güncellenir); konu silindiyse null.
/// * Durumlar: yükleniyor iskeleti, internet yok, sunucu hatası, silinmiş/kaldırılmış konu (404/410), kilitli konu.
class TopicDetailPage extends StatefulWidget {
  const TopicDetailPage({
    super.key,
    required this.session,
    required this.topicId,
    this.commentId,
    this.initial,
    this.api,
    this.pollBuilder,
  });

  final Session session;
  final int topicId;
  final int? commentId;

  /// Liste kartından hızlı ilk çizim (gövde gelene dek).
  final TopicSummary? initial;

  /// Test için API örneği.
  final ForumApi? api;

  /// Anket parçası (MB-C `PollView`); verilmezse anket çizilmez.
  final TopicPollBuilder? pollBuilder;

  @override
  State<TopicDetailPage> createState() => _TopicDetailPageState();
}

class _TopicDetailPageState extends State<TopicDetailPage> with CommentInteractions<TopicDetailPage> {
  late final ForumApi _api = widget.api ?? ForumApi(widget.session);
  late final CommentsController _cc = CommentsController(api: _api, topicId: widget.topicId, onCountDelta: _countDelta);
  final ScrollController _scroll = ScrollController();
  final GlobalKey _commentsKey = GlobalKey();
  final GlobalKey _focusKey = GlobalKey();
  final GlobalKey<CommentComposerState> _composerKey = GlobalKey<CommentComposerState>();

  TopicView? _topic;
  bool _loading = true;
  Object? _error;

  /// 404/410: konu yok ya da kaldırılmış.
  bool _gone = false;
  bool _slow = false;
  Timer? _slowTimer;
  int? _scrollToId;

  // Beğeni tek uçuş (art arda dokunuşlar birleşir).
  bool _likeBusy = false;
  bool _likeConfirmed = false;
  int _likeConfirmedCount = 0;

  @override
  Session get session => widget.session;
  @override
  CommentsController get cc => _cc;
  @override
  ForumApi get api => _api;
  @override
  bool get canComment => _topic != null && !_topic!.locked && !_topic!.removed;

  TopicSummary? get _summary => _topic ?? widget.initial;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _cc.addListener(_onCc);
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cc.collapseDuration = BuMotion.reduced(context) ? Duration.zero : const Duration(milliseconds: 200);
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _scroll.dispose();
    _cc.removeListener(_onCc);
    _cc.dispose();
    super.dispose();
  }

  void _onCc() {
    if (_cc.loading) {
      // Yükleme uzarsa "bağlantı yavaş" ipucu çıkar.
      if (!(_slowTimer?.isActive ?? false) && !_slow) _startSlowTimer();
    } else {
      _slowTimer?.cancel();
      if (_slow && mounted) setState(() => _slow = false);
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 600) _cc.loadMore();
  }

  void _countDelta(int d) {
    final t = _topic;
    if (t == null) return;
    setState(() => _topic = t.copyWith(commentCount: (t.commentCount + d).clamp(0, 1 << 30)));
  }

  // ---- Yükleme -------------------------------------------------------------------------------------------

  Future<void> _load({bool refresh = false}) async {
    if (!refresh && !_loading) {
      setState(() {
        _loading = _topic == null;
        _error = null;
        _gone = false;
      });
    }
    try {
      final t = await _api.topic(widget.topicId, force: true);
      if (!mounted) return;
      setState(() {
        _topic = t;
        _loading = false;
        _error = null;
        _gone = t.removed;
      });
      if (t.removed) return;
      await _cc.load(silent: refresh);
      if (!mounted) return;
      if (!refresh && widget.commentId != null) await _focusComment(widget.commentId!);
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (e.status == 404 || e.status == 410) {
          _gone = true;
        } else if (_topic == null) {
          _error = e;
        } else {
          toast(errorText(e), kind: BuToastKind.error);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_topic == null) _error = e;
      });
    }
  }

  void _startSlowTimer() {
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && _cc.loading) setState(() => _slow = true);
    });
  }

  @override
  Future<void> refreshTopic() async {
    try {
      final t = await _api.topic(widget.topicId, force: true);
      if (mounted) setState(() => _topic = t);
    } catch (_) {}
  }

  Future<void> _refreshAll() => _load(refresh: true);

  // ---- Yoruma git / zincir -------------------------------------------------------------------------------

  Future<void> _focusComment(int id) async {
    final r = await _cc.focus(id);
    if (!mounted) return;
    switch (r.kind) {
      case CommentFocus.notFound:
        toast(context.l10n.forumCommentLinkNotFound, kind: BuToastKind.warning);
      case CommentFocus.found:
        _scrollTo(id);
      case CommentFocus.needsThread:
        await _openChain(r.threadRoot!, focusId: id);
    }
  }

  void _scrollTo(int id) {
    setState(() => _scrollToId = id);
    // Önce yorumlar bölümüne in (liste tembel kurulur), sonra hedefe.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final head = _commentsKey.currentContext;
      if (head != null) await Scrollable.ensureVisible(head, duration: Duration.zero);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _focusKey.currentContext;
        if (ctx != null && mounted) {
          Scrollable.ensureVisible(ctx,
              alignment: .25, duration: BuMotion.of(context, const Duration(milliseconds: 320)), curve: Curves.easeOutCubic);
        }
      });
    });
  }

  @override
  void onCommentCreated(CommentNode n) => _scrollTo(n.id);

  Future<void> _openChain(CommentNode root, {int? focusId}) async {
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'forum_comment_thread'),
      builder: (_) => CommentThreadPage(
        session: widget.session,
        controller: _cc,
        root: root,
        api: _api,
        locked: _topic?.locked ?? false,
        focusId: focusId,
        onTopicChanged: refreshTopic,
      ),
    ));
    if (mounted) setState(() {});
  }

  void _toComments() {
    final ctx = _commentsKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: BuMotion.of(context, const Duration(milliseconds: 300)), curve: Curves.easeOutCubic);
    }
  }

  // ---- Konu etkileşimleri --------------------------------------------------------------------------------

  Future<void> _toggleLike() async {
    final t = _topic;
    if (t == null) return;
    if (!_likeBusy) {
      _likeConfirmed = t.likedByMe;
      _likeConfirmedCount = t.likeCount;
    }
    final want = !t.likedByMe;
    setState(() => _topic = t.copyWith(likedByMe: want, likeCount: (t.likeCount + (want ? 1 : -1)).clamp(0, 1 << 30)));
    if (_likeBusy) return;
    _likeBusy = true;
    try {
      while (true) {
        final target = _topic!.likedByMe;
        final r = await _api.likeTopic(widget.topicId, target);
        _likeConfirmed = r.liked;
        _likeConfirmedCount = r.likeCount;
        if (_topic!.likedByMe == target) {
          if (mounted) setState(() => _topic = _topic!.copyWith(likedByMe: r.liked, likeCount: r.likeCount));
          break;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _topic = _topic!.copyWith(likedByMe: _likeConfirmed, likeCount: _likeConfirmedCount));
        _topicError(e);
      }
    } finally {
      _likeBusy = false;
    }
  }

  Future<void> _toggleSave() async {
    final t = _topic;
    if (t == null) return;
    final prev = t.savedByMe;
    setState(() => _topic = t.copyWith(savedByMe: !prev));
    try {
      final saved = await _api.bookmarkTopic(widget.topicId, !prev);
      if (!mounted) return;
      setState(() => _topic = _topic!.copyWith(savedByMe: saved));
      toast(saved ? context.l10n.forumDetailSaved : context.l10n.forumDetailUnsaved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _topic = _topic!.copyWith(savedByMe: prev));
      _topicError(e);
    }
  }

  Future<void> _toggleFollow() async {
    final t = _topic;
    if (t == null) return;
    final prev = t.followedByMe;
    setState(() => _topic = t.copyWith(followedByMe: !prev));
    try {
      final f = await _api.followTopic(widget.topicId, !prev);
      if (!mounted) return;
      setState(() => _topic = _topic!.copyWith(followedByMe: f));
      toast(f ? context.l10n.forumDetailFollowing : context.l10n.forumDetailUnfollowed);
    } catch (e) {
      if (!mounted) return;
      setState(() => _topic = _topic!.copyWith(followedByMe: prev));
      _topicError(e);
    }
  }

  void _topicError(Object e) {
    if (e is ApiError && (e.status == 404 || e.status == 410)) {
      setState(() => _gone = true);
      return;
    }
    toast(errorText(e), kind: BuToastKind.error);
  }

  Future<void> _shareTopic() async {
    final ok = await shareForumLink(forumTopicLink(widget.topicId));
    if (!ok && mounted) toast(context.l10n.shareExternalFailed, kind: BuToastKind.error);
  }

  Future<void> _openMenu() async {
    final t = _topic;
    if (t == null) return;
    final action = await showTopicMenu(context, t);
    if (action == null || !mounted) return;
    final l = context.l10n;
    switch (action) {
      case TopicMenuAction.edit:
        final updated = await openEditTopic(context, widget.session, t);
        if (updated != null && mounted) setState(() => _topic = updated.copyWith(commentCount: _topic?.commentCount));
      case TopicMenuAction.delete:
        await _confirmDeleteTopic();
      case TopicMenuAction.notifications:
        try {
          final en = await _api.setTopicNotifications(widget.topicId, !t.notificationsEnabled);
          if (!mounted) return;
          setState(() => _topic = _topic!.copyWith(notificationsEnabled: en));
          toast(en ? l.forumDetailNotificationsOnDone : l.forumDetailNotificationsOffDone);
        } catch (e) {
          if (mounted) _topicError(e);
        }
      case TopicMenuAction.share:
        await _shareTopic();
      case TopicMenuAction.pin:
        await _moderate(t.pinned ? 'UNPIN' : 'PIN', t.pinned ? l.forumDetailUnpinnedDone : l.forumDetailPinnedDone);
      case TopicMenuAction.lock:
        await _moderate(t.locked ? 'UNLOCK' : 'LOCK', t.locked ? l.forumDetailUnlockedDone : l.forumDetailLockedDone);
      case TopicMenuAction.report:
        await openReportSheet(context, widget.session,
            targetType: kForumReportTopic, targetId: t.id, anonymousAuthor: t.author.anonymous);
      case TopicMenuAction.block:
        await _confirmBlockAuthor();
    }
  }

  Future<void> _moderate(String action, String done) async {
    try {
      await _api.moderateTopic(widget.topicId, action);
      await refreshTopic();
      toast(done, kind: BuToastKind.success);
    } catch (e) {
      if (mounted) toast(errorText(e), kind: BuToastKind.error);
    }
  }

  Future<void> _confirmDeleteTopic() async {
    final l = context.l10n;
    final ok = await BuConfirmSheet.show(
      context,
      title: l.forumDetailDeleteTitle,
      message: l.forumDetailDeleteBody,
      confirmLabel: l.forumDetailDeleteConfirm,
      destructive: true,
      icon: BuIcons.trash2,
    );
    if (!ok || !mounted) return;
    try {
      await _api.deleteTopic(widget.topicId);
      if (!mounted) return;
      toast(l.forumDetailDeleted, kind: BuToastKind.success);
      Navigator.of(context).pop<TopicSummary?>(null);
    } catch (e) {
      if (mounted) toast(errorText(e), kind: BuToastKind.error);
    }
  }

  Future<void> _confirmBlockAuthor() async {
    final l = context.l10n;
    final ok = await BuConfirmSheet.show(
      context,
      title: l.forumDetailBlockTitle,
      message: l.forumDetailBlockBody,
      confirmLabel: l.forumDetailBlockConfirm,
      destructive: true,
      icon: BuIcons.ban,
    );
    if (!ok || !mounted) return;
    try {
      await _api.blockTopicAuthor(widget.topicId);
      if (!mounted) return;
      toast(l.forumDetailBlocked, kind: BuToastKind.success);
      Navigator.of(context).pop<TopicSummary?>(null);
    } catch (e) {
      if (mounted) toast(errorText(e), kind: BuToastKind.error);
    }
  }

  void _openAuthorProfile() {
    final a = _summary?.author;
    if (a?.userId == null) return;
    openUserProfile(context, widget.session, userId: a!.userId!, name: a.displayName, avatarUrl: a.avatarUrl);
  }

  void _back() => Navigator.of(context).pop<TopicSummary?>(_topic ?? widget.initial);

  // ---- Görünüm ------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final topic = _topic;

    final Widget body;
    if (_gone) {
      final removed = topic?.removed ?? false;
      body = BuEmptyState(
        key: const ValueKey('topicGone'),
        icon: removed ? BuIcons.shieldAlert : BuIcons.fileSearch,
        title: removed ? l.forumDetailRemovedTitle : l.forumDetailNotFoundTitle,
        message: removed ? l.forumDetailRemovedBody : l.forumDetailNotFoundBody,
      );
    } else if (_error != null && topic == null) {
      body = BuErrorState(key: const ValueKey('topicError'), error: _error, onRetry: _load);
    } else if (_loading && topic == null && widget.initial == null) {
      body = const _DetailSkeleton();
    } else {
      body = _content(context, topic);
    }

    final showComposer = !_gone && topic != null && !topic.removed;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: t.bg,
        // Yazma çubuğu bottomNavigationBar'dır: bildirimler (SnackBar) çubuğun ÜSTÜNDE çıkar, gönder düğmesini
        // örtmez. Klavye payını çubuğa kendimiz veririz (gövde Scaffold'un alt çubuk yüksekliğiyle küçülür).
        resizeToAvoidBottomInset: false,
        bottomNavigationBar: showComposer
            ? Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
                child: CommentComposer(
                  key: _composerKey,
                  locked: topic.locked,
                  replyName: replyTo == null ? null : commentAuthorName(context, replyTo!),
                  editing: editing != null,
                  editText: editing?.body,
                  onCancelTarget: cancelTarget,
                  onSend: (b, a, k) => sendComment(b, a, k),
                  onSave: saveEdit,
                  onError: composerError,
                ),
              )
            : null,
        body: Column(children: [
          TopicDetailBar(onBack: _back, onMore: topic != null && !_gone ? _openMenu : null),
          Expanded(child: body),
        ]),
      ),
    );
  }

  Widget _content(BuildContext context, TopicView? topic) {
    final t = context.bu;
    final s = _summary!;
    final locked = topic?.locked ?? s.locked;
    return RefreshIndicator(
      color: t.pr,
      backgroundColor: t.sf3,
      onRefresh: _refreshAll,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: TopicHeaderBlock(summary: s, full: topic, session: widget.session, onOpenProfile: _openAuthorProfile),
          ),
          if (topic?.poll != null && widget.pollBuilder != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 0),
                child: widget.pollBuilder!(context, _api, topic!, (p) => setState(() => _topic = topic.copyWith(poll: p))),
              ),
            ),
          if (locked) const SliverToBoxAdapter(child: TopicLockedBand()),
          if (topic != null)
            SliverToBoxAdapter(
              child: TopicActionBar(
                topic: topic,
                onLike: _toggleLike,
                onComments: _toComments,
                onSave: _toggleSave,
                onFollow: _toggleFollow,
                onShare: _shareTopic,
              ),
            ),
          if (topic != null) ..._commentSlivers(context, topic),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  List<Widget> _commentSlivers(BuildContext context, TopicView topic) {
    return [
      SliverToBoxAdapter(
        child: ListenableBuilder(
          listenable: _cc,
          builder: (context, _) => KeyedSubtree(
            key: _commentsKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              CommentsHeader(
                count: topic.commentCount,
                sort: _cc.sort,
                onSort: (s) => _cc.setSort(s),
              ),
              CommentsStateBox(controller: _cc, slow: _slow),
            ]),
          ),
        ),
      ),
      ListenableBuilder(
        listenable: _cc,
        builder: (context, _) {
          final rows = flattenComments(_cc.roots);
          final index = {for (var i = 0; i < rows.length; i++) rows[i].key: i};
          return SliverList.builder(
            itemCount: rows.length,
            findChildIndexCallback: (k) => k is ValueKey<String> ? index[k.value] : null,
            itemBuilder: (context, i) {
              final row = rows[i];
              Widget tile = CommentRowTile(
                row: row,
                controller: _cc,
                session: widget.session,
                actions: cardActions,
                canReply: canComment,
                onOpenChain: (n) => _openChain(n),
              );
              if (row.kind == CommentRowKind.comment && row.node.id == _scrollToId) {
                tile = KeyedSubtree(key: _focusKey, child: tile);
              }
              return KeyedSubtree(key: ValueKey<String>(row.key), child: tile);
            },
          );
        },
      ),
      SliverToBoxAdapter(child: ListenableBuilder(listenable: _cc, builder: (_, __) => CommentsFooter(controller: _cc))),
    ];
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return BuSkeletonScope(
      child: Semantics(
        label: context.l10n.commonLoading,
        liveRegion: true,
        child: const Padding(
          key: ValueKey('topicLoading'),
          padding: EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              BuSkeleton.circle(40),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  BuSkeleton.line(width: 140),
                  SizedBox(height: 8),
                  BuSkeleton.line(width: 90),
                ]),
              ),
            ]),
            SizedBox(height: 20),
            BuSkeleton(height: 24),
            SizedBox(height: 10),
            BuSkeleton(height: 24, width: 220),
            SizedBox(height: 20),
            BuSkeleton.line(),
            SizedBox(height: 8),
            BuSkeleton.line(),
            SizedBox(height: 8),
            BuSkeleton.line(width: 200),
          ]),
        ),
      ),
    );
  }
}
