import 'package:flutter/material.dart';

import '../../../../core/locale_controller.dart';
import '../../../../core/session.dart';
import '../../../../core/theme.dart';
import '../../../../core/theme/bu_motion.dart';
import '../../../../widgets/bu_overlays.dart' show BuToastKind;
import '../../data/forum_api.dart';
import '../widgets/comment_card.dart' show commentAuthorName;
import '../widgets/comment_composer.dart';
import '../widgets/comment_controller.dart';
import '../widgets/comment_interactions.dart';
import '../widgets/comment_section.dart';
import '../widgets/comment_tree.dart';
import '../widgets/topic_detail_menu.dart' show TopicDetailBar;

/// "Yanıt zincirini aç": girinti sınırından derin bir yorumun kendi alt ağacı, ayrı ekranda. Konu ekranıyla AYNI
/// [CommentsController] (ve düğümleri) paylaşılır; bir ekranda yapılan beğeni/yanıt/silme ötekinde de görünür.
/// Kök yorum seviye 0 olarak çizilir; daha derin zincir yine ayrı bir zincir ekranında açılır.
/// Yazma çubuğunun varsayılan hedefi kök yorumdur ("X kişisine yanıt veriyorsun").
class CommentThreadPage extends StatefulWidget {
  const CommentThreadPage({
    super.key,
    required this.session,
    required this.controller,
    required this.root,
    required this.api,
    required this.locked,
    this.focusId,
    this.onTopicChanged,
  });

  final Session session;
  final CommentsController controller;
  final CommentNode root;
  final ForumApi api;
  final bool locked;

  /// Açılışta vurgulanacak/kaydırılacak yorum (bağlantıdan gelen).
  final int? focusId;
  final Future<void> Function()? onTopicChanged;

  @override
  State<CommentThreadPage> createState() => _CommentThreadPageState();
}

class _CommentThreadPageState extends State<CommentThreadPage> with CommentInteractions<CommentThreadPage> {
  final GlobalKey _focusKey = GlobalKey();
  final ScrollController _scroll = ScrollController();
  int? _scrollToId;

  @override
  Session get session => widget.session;
  @override
  CommentsController get cc => widget.controller;
  @override
  ForumApi get api => widget.api;
  @override
  bool get canComment => !widget.locked;

  @override
  Future<void> refreshTopic() async => widget.onTopicChanged?.call();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _scroll.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    if (!mounted) return;
    final c = widget.controller;
    final root = widget.root;
    if (!root.expanded || !root.repliesLoaded) await c.showReplies(root);
    final id = widget.focusId;
    if (id == null || !mounted) return;
    final r = await c.focus(id, from: root);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _focusKey.currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(ctx,
            alignment: .25, duration: BuMotion.of(context, const Duration(milliseconds: 320)), curve: Curves.easeOutCubic);
      }
    });
  }

  @override
  void onCommentCreated(CommentNode n) => _scrollTo(n.id);

  Future<void> _openChain(CommentNode node, {int? focusId}) async {
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'forum_comment_thread'),
      builder: (_) => CommentThreadPage(
        session: widget.session,
        controller: widget.controller,
        root: node,
        api: widget.api,
        locked: widget.locked,
        focusId: focusId,
        onTopicChanged: widget.onTopicChanged,
      ),
    ));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final root = widget.root;
    final rows = flattenComments([root], baseDepth: root.depth);
    final index = {for (var i = 0; i < rows.length; i++) rows[i].key: i};
    return Scaffold(
      backgroundColor: t.bg,
      resizeToAvoidBottomInset: false,
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: CommentComposer(
          locked: widget.locked,
          replyName: replyTo == null ? null : commentAuthorName(context, replyTo!),
          threadReplyName: commentAuthorName(context, root),
          editing: editing != null,
          editText: editing?.body,
          onCancelTarget: cancelTarget,
          onSend: (b, a, k) => sendComment(b, a, k, defaultParent: root),
          onSave: saveEdit,
          onError: composerError,
        ),
      ),
      body: Column(children: [
        TopicDetailBar(onBack: () => Navigator.of(context).maybePop()),
        Expanded(
          child: CustomScrollView(
            key: const ValueKey('commentThread'),
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverList.builder(
                itemCount: rows.length,
                findChildIndexCallback: (k) => k is ValueKey<String> ? index[k.value] : null,
                itemBuilder: (context, i) {
                  final row = rows[i];
                  Widget tile = CommentRowTile(
                    row: row,
                    controller: widget.controller,
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
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ]),
    );
  }
}
