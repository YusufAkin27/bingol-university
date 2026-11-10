import '../../chat/emoji_presentation.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api.dart' show ApiError;
import '../../../core/locale_controller.dart';
import '../../../core/session.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/bu.dart';
import '../../../widgets/report_sheet.dart';
import '../post_media_uploader.dart' show postErrorText;
import 'comment_composer.dart';
import 'comment_models.dart';
import 'comment_tile.dart';
import 'comments_api.dart';
import 'comments_controller.dart';

/// Hata -> kısa kullanıcı metni (yorum yazma / silme / beğeni).
String commentErrorText(Object e, AppLocalizations l) {
  if (e is ApiError) {
    switch (e.code) {
      case 'COMMENT_TOO_LONG':
        return l.pcmErrTooLong;
      case 'CONTENT_PROFANITY':
        return l.postComposeErrProfanity;
      case 'POST_NOT_FOUND':
        return l.pcmErrPostGone;
      case 'COMMENT_PARENT_INVALID':
        return l.pcmErrParent;
      case 'COMMENTS_DISABLED':
        return l.pcmCommentsDisabled;
    }
    if (e.status == 429) return l.pcmErrRate;
  }
  return postErrorText(e, l);
}

/// Yorumlar alt sayfası (~%75 yükseklik, sürüklenerek büyür/küçülür, klavyeyle uyumlu). Gönderi kartı, gönderi detayı,
/// Reels ve bildirim derin bağlantısı aynı paneli açar. [focusCommentId]: açılışta o yoruma kaydırıp vurgular.
/// [onCountChanged]: ekleme/silmede güncel yorum sayısı (kart sayacını günceller).
Future<void> showCommentSheet(
  BuildContext context, {
  required Session session,
  required int postId,
  int commentCount = 0,
  CommentsApi? api,
  ValueChanged<int>? onCountChanged,
  int? focusCommentId,
  bool commentsDisabled = false,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: BuMotionStyles.sheet(context),
      builder: (_) => CommentSheet(
        session: session,
        postId: postId,
        commentCount: commentCount,
        api: api ?? HttpCommentsApi(session),
        onCountChanged: onCountChanged,
        focusCommentId: focusCommentId,
        commentsDisabled: commentsDisabled,
      ),
    );

class CommentSheet extends StatefulWidget {
  const CommentSheet({
    super.key,
    required this.session,
    required this.postId,
    required this.api,
    this.commentCount = 0,
    this.onCountChanged,
    this.focusCommentId,
    this.commentsDisabled = false,
  });

  /// Gönderi sahibi yorumları kapattı: yazma çubuğu yerine bilgi satırı, yanıt/beğeni pasif; okuma ve (sahibi için) silme sürer.
  final bool commentsDisabled;
  final Session session;
  final int postId;
  final int commentCount;
  final CommentsApi api;
  final ValueChanged<int>? onCountChanged;
  final int? focusCommentId;

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  late final CommentsController _c;
  final _input = EmojiTextEditingController();
  final _focus = FocusNode();
  final _focusKey = GlobalKey();
  ScrollController? _sc;

  String? _prefill;
  String? _notice;
  bool _noticeError = false;
  Timer? _noticeTimer;
  Timer? _hlTimer;
  int? _scrolledTo;
  bool _missingShown = false;
  late bool _disabled = widget.commentsDisabled;

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    _c = CommentsController(
      api: widget.api,
      postId: widget.postId,
      initialCount: widget.commentCount,
      focusCommentId: widget.focusCommentId,
      onCountChanged: widget.onCountChanged,
      me: CommentAuthor(
        userId: s.userId ?? 0,
        displayName: s.displayName ?? '',
        avatarUrl: s.avatarUrl.value,
      ),
    )
      ..onError = _onError
      ..onRestore = _onRestore
      ..addListener(_onChange);
    _c.load();
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    _hlTimer?.cancel();
    _c
      ..removeListener(_onChange)
      ..dispose();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    if (_c.focusNotFound && !_missingShown) {
      _missingShown = true;
      _showNotice(context.l10n.commentFocusMissing, error: true);
    }
    final id = _c.highlightId;
    if (id != null && _scrolledTo != id) {
      _scrolledTo = id;
      _hlTimer?.cancel();
      _hlTimer = Timer(const Duration(milliseconds: 2400), _c.clearHighlight);
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealFocus(0));
    }
  }

  /// Vurgulanan yoruma kaydırır; satır henüz çizilmediyse (tembel liste) tahminle yaklaşıp tekrar dener.
  void _revealFocus(int attempt) {
    if (!mounted) return;
    final ctx = _focusKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, alignment: .25, duration: AppMotion.of(context, AppMotion.normal), curve: BuMotion.standard);
      return;
    }
    final sc = _sc;
    final id = _c.highlightId;
    if (attempt >= 4 || sc == null || !sc.hasClients || id == null) return;
    final idx = _c.roots.indexWhere((x) => x.id == id);
    final target = (idx < 0 ? 0.0 : idx * 96.0).clamp(0.0, sc.position.maxScrollExtent).toDouble();
    sc.jumpTo(target);
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealFocus(attempt + 1));
  }

  void _showNotice(String text, {bool error = false}) {
    _noticeTimer?.cancel();
    setState(() {
      _notice = text;
      _noticeError = error;
    });
    _noticeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  void _onError(Object e) {
    if (!mounted) return;
    // Sunucu yorumların kapalı olduğunu söylediyse (sahip arada kapattı) arayüz de kapanır.
    if (e is ApiError && e.code == 'COMMENTS_DISABLED' && !_disabled) setState(() => _disabled = true);
    _showNotice(commentErrorText(e, context.l10n), error: true);
  }

  void _onRestore(String text, PostComment? target) {
    if (!mounted) return;
    _input.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    _prefill = null;
    _c.setReplyTo(target);
  }

  void _reply(PostComment c) {
    _c.setReplyTo(c);
    final a = c.author;
    // Yanıta yanıt: sunucu ilk düzeye yassılar; muhatap "@ad" ile metinde belirtilir.
    if (c.isReply && a != null) {
      final tag = '@${a.handle} ';
      _prefill = tag;
      _input.value = TextEditingValue(text: tag, selection: TextSelection.collapsed(offset: tag.length));
    }
    _focus.requestFocus();
  }

  void _cancelReply() {
    if (_prefill != null && _input.text == _prefill) _input.clear();
    _prefill = null;
    _c.setReplyTo(null);
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty || _c.sending) return;
    _input.clear();
    _prefill = null;
    final root = _c.replyTo == null;
    final ok = _c.send(text);
    if (root) {
      final sc = _sc;
      if (sc != null && sc.hasClients) sc.animateTo(0, duration: AppMotion.of(context, AppMotion.normal), curve: BuMotion.standard);
    }
    await ok;
  }

  Future<void> _menu(PostComment c) async {
    final l = context.l10n;
    final t = context.bu;
    final canDelete = c.canDelete || c.sendState == CommentSendState.failed;
    final canReport = !c.mine && !c.isLocal;
    final canCopy = (c.body ?? '').isNotEmpty;
    final choice = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: t.sf3,
      sheetAnimationStyle: BuMotionStyles.sheet(context),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (canCopy) _MenuRow(key: const ValueKey('commentMenuCopy'), icon: BuIcons.copy, label: l.pcmMenuCopy, onTap: () => Navigator.pop(ctx, 'copy')),
          if (canDelete)
            _MenuRow(key: const ValueKey('commentMenuDelete'), icon: BuIcons.trash2, label: l.pcmMenuDelete, danger: true, onTap: () => Navigator.pop(ctx, 'delete')),
          if (canReport) _MenuRow(key: const ValueKey('commentMenuReport'), icon: BuIcons.flag, label: l.pcmMenuReport, onTap: () => Navigator.pop(ctx, 'report')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: c.body ?? ''));
        if (mounted) _showNotice(l.pcmCopied);
      case 'delete':
        // Başkasının yorumunu (gönderi sahibi olarak) silmeden önce onay sorulur; kendi yorumun anında silinir.
        if (!c.mine && !c.isLocal && c.sendState != CommentSendState.failed) {
          final ok = await _confirmDelete();
          if (ok != true || !mounted) return;
        }
        await _c.delete(c);
      case 'report':
        await ReportSheet.show(context, widget.session, targetType: 'COMMENT', targetId: c.id);
    }
  }

  Future<bool?> _confirmDelete() {
    final l = context.l10n;
    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (c) {
        final t = c.bu;
        final tt = Theme.of(c).textTheme;
        return AlertDialog(
          key: const ValueKey('commentDeleteDialog'),
          backgroundColor: t.sf3,
          surfaceTintColor: Colors.transparent,
          title: Text(l.pcmDeleteOthersTitle, style: tt.titleLarge?.copyWith(color: t.ink, fontWeight: BuType.emphasisWeight)),
          content: Text(l.pcmDeleteOthersBody, style: tt.bodyMedium?.copyWith(color: t.mut)),
          actions: [
            TextButton(
              key: const ValueKey('commentDeleteCancel'),
              onPressed: () => Navigator.pop(c, false),
              style: TextButton.styleFrom(minimumSize: const Size(BuSize.touch, BuSize.touch), foregroundColor: t.mut),
              child: Text(l.postComposeCancel),
            ),
            TextButton(
              key: const ValueKey('commentDeleteConfirm'),
              onPressed: () => Navigator.pop(c, true),
              style: TextButton.styleFrom(minimumSize: const Size(BuSize.touch, BuSize.touch), foregroundColor: t.danger),
              child: Text(l.pcmMenuDelete),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Padding(
      // Klavye açılınca alt sayfa ve yazma çubuğu yukarı çıkar.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .75,
        minChildSize: .5,
        maxChildSize: .95,
        snap: true,
        snapSizes: const [.75],
        builder: (ctx, sc) {
          _sc = sc;
          return Material(
            color: t.sf3,
            clipBehavior: Clip.antiAlias,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(children: [
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.extentAfter < 320) _c.loadMore();
                    return false;
                  },
                  child: CustomScrollView(
                    key: const ValueKey('commentsScroll'),
                    controller: sc,
                    slivers: [
                      SliverPersistentHeader(pinned: true, delegate: _HeaderDelegate(builder: (_) => _header(t, l))),
                      ..._content(t, l),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: AppMotion.of(context, AppMotion.fast),
                alignment: Alignment.bottomCenter,
                child: _notice == null ? const SizedBox(width: double.infinity) : _noticeBar(t),
              ),
              if (_disabled)
                _disabledBar(t)
              else
                CommentComposer(
                  session: widget.session,
                  controller: _input,
                  focusNode: _focus,
                  sending: _c.sending,
                  replyingToName: _c.replyTo?.author?.handle,
                  onCancelReply: _cancelReply,
                  onSend: _send,
                ),
            ]),
          );
        },
      ),
    );
  }

  /// Yorumlar kapalı: yazma çubuğunun yerine sade bilgi satırı.
  Widget _disabledBar(BuTokens t) {
    final tt = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: t.sf3, border: Border(top: BorderSide(color: t.bd, width: .5))),
      child: SafeArea(
        top: false,
        child: Semantics(
          container: true,
          child: Container(
            key: const ValueKey('commentsDisabledBar'),
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: BuSpace.page, vertical: 12),
            child: Row(children: [
              ExcludeSemantics(child: Icon(BuIcons.lock, size: 18, color: t.mut)),
              const SizedBox(width: 10),
              Expanded(child: Text(context.l10n.pcmCommentsDisabled, style: tt.bodyMedium?.copyWith(color: t.mut))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _noticeBar(BuTokens t) {
    final tt = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('commentNotice'),
        width: double.infinity,
        color: t.sf2,
        padding: const EdgeInsets.symmetric(horizontal: BuSpace.page, vertical: 10),
        child: Row(children: [
          Icon(_noticeError ? BuIcons.circleAlert : BuIcons.circleCheck, size: 18, color: _noticeError ? t.danger : t.ok),
          const SizedBox(width: 10),
          Expanded(child: Text(_notice!, style: tt.bodySmall?.copyWith(color: t.ink))),
        ]),
      ),
    );
  }

  Widget _header(BuTokens t, AppLocalizations l) {
    final tt = Theme.of(context).textTheme;
    final top = _c.sort == 'top';
    return Container(
      color: t.sf3,
      child: Column(children: [
        const SizedBox(height: 10),
        Container(width: 36, height: 4, decoration: BoxDecoration(color: t.bdStrong.withValues(alpha: .5), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 6),
        SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: BuSpace.page, end: 12),
            child: Row(children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: l.kesCommentsTitle, style: tt.titleMedium?.copyWith(color: t.ink, fontWeight: BuType.emphasisWeight)),
                      TextSpan(text: '  ${_c.count}', style: tt.titleMedium?.copyWith(color: t.mut, fontWeight: BuType.emphasisWeight)),
                    ]),
                    key: const ValueKey('commentsTitle'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                key: const ValueKey('commentsSort'),
                tooltip: l.pcmSortLabel,
                color: t.sf3,
                position: PopupMenuPosition.under,
                onSelected: _c.setSort,
                itemBuilder: (_) => [
                  for (final (v, label) in [('top', l.kesCommentsSortTop), ('new', l.kesCommentsSortNew)])
                    PopupMenuItem<String>(
                      key: ValueKey('commentsSort${v == 'top' ? 'Top' : 'New'}'),
                      value: v,
                      child: Row(children: [
                        Expanded(child: Text(label, style: tt.bodyMedium?.copyWith(color: t.ink))),
                        if (_c.sort == v) Icon(BuIcons.check, size: 18, color: t.ink),
                      ]),
                    ),
                ],
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Center(
                    widthFactor: 1,
                    child: Container(
                      padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 8, 6),
                      decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.pill)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(top ? l.kesCommentsSortTop : l.kesCommentsSortNew, style: tt.labelLarge?.copyWith(color: t.ink)),
                        const SizedBox(width: 4),
                        Icon(BuIcons.chevronDown, size: 16, color: t.mut),
                      ]),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
        Divider(height: 1, thickness: .5, color: t.bd),
      ]),
    );
  }

  List<Widget> _content(BuTokens t, AppLocalizations l) {
    final tt = Theme.of(context).textTheme;
    if (_c.loading) {
      return [
        SliverToBoxAdapter(
          child: BuSkeletonScope(
            child: Column(key: const ValueKey('commentsSkeleton'), children: [
              for (var i = 0; i < 5; i++)
                Padding(
                  padding: const EdgeInsets.fromLTRB(BuSpace.page, 12, BuSpace.page, 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const BuSkeleton.circle(36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        BuSkeleton.line(width: 90.0 + (i % 3) * 20, height: 12),
                        const SizedBox(height: 8),
                        const BuSkeleton.line(height: 12),
                        const SizedBox(height: 6),
                        BuSkeleton.line(width: 140.0 + (i % 2) * 40, height: 12),
                      ]),
                    ),
                  ]),
                ),
            ]),
          ),
        ),
      ];
    }
    if (_c.error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: BuSpace.page),
                child: Text(l.kesCommentsLoadFailed,
                    key: const ValueKey('commentsError'), textAlign: TextAlign.center, style: tt.bodyMedium?.copyWith(color: t.mut)),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const ValueKey('commentsRetry'),
                onPressed: _c.load,
                style: TextButton.styleFrom(minimumSize: const Size(BuSize.touch, BuSize.touch), foregroundColor: t.ink),
                child: Text(l.postViewRetry),
              ),
            ]),
          ),
        ),
      ];
    }
    if (_c.roots.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(BuSpace.xxl),
              child: Column(key: const ValueKey('commentsEmpty'), mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle),
                  child: Icon(BuIcons.messageCircle, size: 28, color: t.mut),
                ),
                const SizedBox(height: 16),
                Text(l.pcmEmptyTitle, textAlign: TextAlign.center, style: tt.titleMedium?.copyWith(color: t.ink, fontWeight: BuType.emphasisWeight)),
                const SizedBox(height: 4),
                Text(l.pcmEmptyBody, textAlign: TextAlign.center, style: tt.bodyMedium?.copyWith(color: t.mut)),
              ]),
            ),
          ),
        ),
      ];
    }
    final rows = <Widget>[];
    for (final r in _c.roots) {
      rows.add(_tile(r, compact: false));
      final th = _c.threads[r.id];
      final shown = th != null && th.expanded;
      if (shown) {
        for (final x in th.items) {
          rows.add(Padding(padding: const EdgeInsetsDirectional.only(start: 36), child: _tile(x, compact: true)));
        }
        if (th.loading) {
          rows.add(const _InlineSpinner());
        } else if (th.error) {
          rows.add(_threadLink(t, tt, l.pcmRetry, () => _c.loadReplies(r, more: th.cursor != null && th.loaded), key: ValueKey('threadRetry-${r.id}')));
        } else if (th.cursor != null) {
          rows.add(_threadLink(t, tt, l.pcmMoreReplies, () => _c.loadReplies(r, more: true), key: ValueKey('threadMore-${r.id}')));
        }
        rows.add(_threadLink(t, tt, l.pcmHideReplies, () => _c.toggleReplies(r), key: ValueKey('commentHide-${r.id}')));
      } else if (r.replyCount > 0) {
        rows.add(_threadLink(t, tt, l.kesCommentsMoreReplies('${r.replyCount}'), () => _c.toggleReplies(r), key: ValueKey('commentReplies-${r.id}')));
      }
    }
    if (_c.loadingMore) rows.add(const _InlineSpinner());
    return [
      SliverList(delegate: SliverChildListDelegate(rows, addAutomaticKeepAlives: false)),
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
    ];
  }

  Widget _tile(PostComment c, {required bool compact}) {
    final hl = _c.highlightId == c.id;
    return KeyedSubtree(
      key: hl ? _focusKey : ValueKey('comment-${c.id}'),
      child: CommentTile(
        session: widget.session,
        comment: c,
        compact: compact,
        highlighted: hl,
        replyEnabled: !_disabled,
        onLike: () => _disabled ? _showNotice(context.l10n.pcmCommentsDisabled, error: true) : _c.toggleLike(c),
        onReply: () => _reply(c),
        onMenu: () => _menu(c),
        onRetry: () => _c.retry(c),
      ),
    );
  }

  Widget _threadLink(BuTokens t, TextTheme tt, String label, VoidCallback onTap, {Key? key}) => InkWell(
        key: key,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: BuSpace.page + 46, end: BuSpace.page),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 22, height: 1, color: t.bdStrong),
                const SizedBox(width: 10),
                Flexible(child: Text(label, style: tt.labelMedium?.copyWith(color: t.mut))),
              ]),
            ),
          ),
        ),
      );
}

class _InlineSpinner extends StatelessWidget {
  const _InlineSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 44,
        child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
      );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({super.key, required this.icon, required this.label, required this.onTap, this.danger = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final color = danger ? t.danger : t.ink;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: BuSpace.page),
          child: Row(children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: color))),
          ]),
        ),
      ),
    );
  }
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  _HeaderDelegate({required this.builder});

  final WidgetBuilder builder;

  static const double extent = 10 + 4 + 6 + 52 + 1;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => builder(context);

  // Başlık sayacı/sıralama denetleyicide değişir; her yeniden çizimde yeniden kur.
  @override
  bool shouldRebuild(covariant _HeaderDelegate old) => true;
}
