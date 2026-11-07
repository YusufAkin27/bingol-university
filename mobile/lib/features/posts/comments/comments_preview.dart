import 'package:flutter/material.dart';

import '../../../core/locale_controller.dart';
import '../../../core/session.dart';
import '../../../widgets/bu.dart';
import '../post_models.dart';
import 'comment_models.dart';
import 'comment_sheet.dart';
import 'comment_tile.dart';
import 'comments_api.dart';

/// Gönderi detayında gönderinin altındaki yorum önizlemesi: en iyi 2 yorum (salt okunur), "N yorumun tümünü gör" ve
/// "Yorum ekle…" satırı. Hepsi aynı alt sayfayı ([showCommentSheet]) açar; önizleme yüklenemezse sessizce yalnız
/// yazma satırı kalır.
class CommentsPreview extends StatefulWidget {
  const CommentsPreview({
    super.key,
    required this.session,
    required this.postId,
    required this.count,
    this.onCountChanged,
    this.api,
  });

  final Session session;
  final int postId;
  final int count;
  final ValueChanged<int>? onCountChanged;
  final CommentsApi? api;

  @override
  State<CommentsPreview> createState() => _CommentsPreviewState();
}

class _CommentsPreviewState extends State<CommentsPreview> {
  late final CommentsApi _api = widget.api ?? HttpCommentsApi(widget.session);
  List<PostComment> _items = const [];
  bool _loaded = false;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CommentsPreview old) {
    super.didUpdateWidget(old);
    if (old.count != widget.count) _load();
  }

  Future<void> _load() async {
    final gen = ++_gen;
    if (widget.count <= 0) {
      if (mounted) {
        setState(() {
          _items = const [];
          _loaded = true;
        });
      }
      return;
    }
    try {
      final p = await _api.list(widget.postId, size: 2);
      if (!mounted || gen != _gen) return;
      setState(() {
        _items = [for (final c in p.items) if (!c.deleted) c].take(2).toList();
        _loaded = true;
      });
    } catch (_) {
      if (mounted && gen == _gen) setState(() => _loaded = true);
    }
  }

  Future<void> _open({int? focus}) => showCommentSheet(
        context,
        session: widget.session,
        postId: widget.postId,
        commentCount: widget.count,
        api: widget.api,
        focusCommentId: focus,
        onCountChanged: widget.onCountChanged,
      );

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Column(
      key: const ValueKey('commentsPreview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.count > 0)
          InkWell(
            key: const ValueKey('commentsViewAll'),
            onTap: _open,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: BuSpace.page),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(l.pcmViewAll('${widget.count}'), style: tt.bodyMedium?.copyWith(color: t.mut)),
                ),
              ),
            ),
          ),
        if (_loaded)
          for (final c in _items)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _open(focus: c.id),
              child: IgnorePointer(
                child: CommentTile(
                  key: ValueKey('preview-${c.id}'),
                  session: widget.session,
                  comment: c,
                  readOnly: true,
                  onLike: () {},
                  onReply: () {},
                  onMenu: () {},
                  onRetry: () {},
                ),
              ),
            ),
        InkWell(
          key: const ValueKey('commentsAddRow'),
          onTap: _open,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: BuSpace.page, vertical: 8),
              child: Row(children: [
                ValueListenableBuilder<String?>(
                  valueListenable: widget.session.avatarUrl,
                  builder: (_, url, __) => BuAvatar(
                      name: widget.session.displayName, url: url, size: 32, headers: postAuthHeaders(widget.session)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 40),
                    alignment: AlignmentDirectional.centerStart,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.pill)),
                    child: Text(l.pcmWriteHint, style: tt.bodyMedium?.copyWith(color: t.mut)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}
