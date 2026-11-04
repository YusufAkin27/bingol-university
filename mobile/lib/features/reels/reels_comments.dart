import 'package:flutter/material.dart';

import '../../core/api.dart' show ApiError;
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import '../posts/avatar_preview.dart';
import '../posts/post_media_uploader.dart' show postErrorText;
import '../../widgets/report_sheet.dart';
import '../posts/post_models.dart';
import '../profile/user_profile_page.dart' show openUserProfile;

/// Tek yorum (ya da yanıt). Alanlar `KS-BE2` yorum sözleşmesine göre okunur; eksik alan güvenli varsayılanlara düşer.
class ReelComment {
  const ReelComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.text,
    this.createdAt,
    this.likeCount = 0,
    this.likedByMe = false,
    this.replyCount = 0,
    this.mine = false,
    this.parentId,
    this.byPostAuthor = false,
    this.canDelete = false,
    this.replyToName,
  });

  factory ReelComment.fromJson(Map<String, dynamic> j) {
    final a = j['author'] is Map ? Map<String, dynamic>.from(j['author'] as Map) : const <String, dynamic>{};
    int n(Object? v) => v is num ? v.toInt() : 0;
    return ReelComment(
      id: n(j['id']),
      authorId: n(a['id']),
      authorName: a['displayName'] is String ? a['displayName'] as String : '',
      authorAvatarUrl: a['avatarUrl'] is String ? a['avatarUrl'] as String : null,
      text: j['text'] is String ? j['text'] as String : '',
      createdAt: j['createdAt'] is String ? j['createdAt'] as String : null,
      likeCount: n(j['likeCount']),
      likedByMe: j['likedByMe'] == true,
      replyCount: n(j['replyCount']),
      mine: j['mine'] == true,
      parentId: j['parentId'] is num ? (j['parentId'] as num).toInt() : null,
      byPostAuthor: j['byPostAuthor'] == true,
      canDelete: j['canDelete'] == true || j['mine'] == true,
      replyToName: j['replyTo'] is Map && (j['replyTo'] as Map)['displayName'] is String ? (j['replyTo'] as Map)['displayName'] as String : null,
    );
  }

  final int id;
  final int authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final String text;
  final String? createdAt;
  final int likeCount;
  final bool likedByMe;
  final int replyCount;
  final bool mine;
  final int? parentId;

  /// Yorumu gönderi sahibi yazdı ("Yazar" rozeti).
  final bool byPostAuthor;

  /// Kendi yorumun, gönderi sahibisin ya da yetkili yöneticisin.
  final bool canDelete;

  /// Yanıta verilen yanıtta asıl muhatap ("@ad"); ust yoruma doğrudan yanıtta null.
  final String? replyToName;

  ReelComment copyWith({int? likeCount, bool? likedByMe}) => ReelComment(
        id: id,
        authorId: authorId,
        authorName: authorName,
        authorAvatarUrl: authorAvatarUrl,
        text: text,
        createdAt: createdAt,
        likeCount: likeCount ?? this.likeCount,
        likedByMe: likedByMe ?? this.likedByMe,
        replyCount: replyCount,
        mine: mine,
        parentId: parentId,
        byPostAuthor: byPostAuthor,
        canDelete: canDelete,
        replyToName: replyToName,
      );
}

class ReelCommentPage {
  const ReelCommentPage(this.items, this.nextCursor);

  final List<ReelComment> items;
  final String? nextCursor;
}

/// Yorum erişimi: arayüz [ReelsCommentsSheet]'ten ayrıdır (testlerde sahtesi verilir; sözleşme değişirse yalnız bu sınıf
/// güncellenir). Gerçek uygulama yalnız sunucu yorumu sunuyorsa (gönderide `commentCount` varsa) bu sayfayı açar.
abstract class CommentsRepository {
  Future<ReelCommentPage> list(int postId, {String? cursor, String sort = 'top'});
  Future<ReelCommentPage> replies(int commentId, {String? cursor});
  Future<ReelComment> add(int postId, String text, {int? parentId});
  Future<void> delete(int commentId);
  Future<void> setLiked(int commentId, bool liked);
}

/// KS-BE2 yorum uçları (docs/changes/post.md "KS-BE2 (V1230)"): `GET|POST /posts/{id}/comments` (`sort=top|new`),
/// `GET /post-comments/{cid}/replies`, `DELETE /post-comments/{cid}`, `PUT|DELETE /post-comments/{cid}/like`;
/// şikâyet `POST /reports {targetType: COMMENT}`.
class ApiCommentsRepository implements CommentsRepository {
  ApiCommentsRepository(this.session);

  final Session session;

  ReelCommentPage _page(Object? body) {
    final m = body is Map ? body : const {};
    final items = m['items'] is List ? m['items'] as List : const [];
    return ReelCommentPage(
      [for (final e in items) if (e is Map) ReelComment.fromJson(Map<String, dynamic>.from(e))],
      m['nextCursor']?.toString(),
    );
  }

  String _q(String? cursor, [String? sort]) {
    final p = [if (sort != null) 'sort=$sort', if (cursor != null) 'cursor=${Uri.encodeQueryComponent(cursor)}'];
    return p.isEmpty ? '' : '?${p.join('&')}';
  }

  @override
  Future<ReelCommentPage> list(int postId, {String? cursor, String sort = 'top'}) async =>
      _page(await session.api.get('/posts/$postId/comments${_q(cursor, sort)}', force: cursor == null));

  @override
  Future<ReelCommentPage> replies(int commentId, {String? cursor}) async =>
      _page(await session.api.get('/post-comments/$commentId/replies${_q(cursor)}'));

  @override
  Future<ReelComment> add(int postId, String text, {int? parentId}) async {
    final r = await session.api.post('/posts/$postId/comments', {'text': text, if (parentId != null) 'parentId': parentId});
    return ReelComment.fromJson(r is Map ? Map<String, dynamic>.from(r) : const {});
  }

  @override
  Future<void> delete(int commentId) => session.api.delete('/post-comments/$commentId');

  @override
  Future<void> setLiked(int commentId, bool liked) async {
    liked ? await session.api.put('/post-comments/$commentId/like') : await session.api.delete('/post-comments/$commentId/like');
  }
}

/// Yorum metni üst sınırı (sunucu kuralı: en çok 300 karakter).
const int kCommentMaxChars = 300;

/// Alttan açılan yorum paneli: yorumlar + iç içe yanıtlar (bir seviye gösterilir), beğeni, yanıtla, silme (kendi
/// yorumu), yazma alanı (klavyede bozulmaz), yukarı sürükleyerek genişler. Yüklenemezse "Yeniden dene".
Future<void> showReelsComments(
  BuildContext context, {
  required Session session,
  required Post post,
  CommentsRepository? repository,
  ValueChanged<int>? onCountChanged,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.bu.sf3,
      builder: (_) => ReelsCommentsSheet(
        session: session,
        post: post,
        repository: repository ?? ApiCommentsRepository(session),
        onCountChanged: onCountChanged,
      ),
    );

class ReelsCommentsSheet extends StatefulWidget {
  const ReelsCommentsSheet({super.key, required this.session, required this.post, required this.repository, this.onCountChanged});

  final Session session;
  final Post post;
  final CommentsRepository repository;
  final ValueChanged<int>? onCountChanged;

  @override
  State<ReelsCommentsSheet> createState() => _ReelsCommentsSheetState();
}

class _ReelsCommentsSheetState extends State<ReelsCommentsSheet> {
  final _items = <ReelComment>[];
  final _replies = <int, List<ReelComment>>{};
  final _input = TextEditingController();
  final _focus = FocusNode();

  String? _cursor;
  String _sort = 'top';
  bool _loading = true;
  bool _more = false;
  Object? _error;
  bool _sending = false;
  ReelComment? _replyTo;
  late int _count = widget.post.commentCount ?? 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_more || _cursor == null)) return;
    setState(() {
      if (more) {
        _more = true;
      } else {
        _loading = true;
        _error = null;
      }
    });
    try {
      final p = await widget.repository.list(widget.post.id, cursor: more ? _cursor : null, sort: _sort);
      if (!mounted) return;
      setState(() {
        if (!more) _items.clear();
        final have = {for (final c in _items) c.id};
        _items.addAll(p.items.where((c) => have.add(c.id)));
        _cursor = p.nextCursor;
        _loading = false;
        _more = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _more = false;
        if (!more) _error = e;
      });
    }
  }

  void _setSort(String s) {
    if (s == _sort) return;
    _sort = s;
    _replies.clear();
    _load();
  }

  Future<void> _showReplies(ReelComment c) async {
    try {
      final p = await widget.repository.replies(c.id);
      if (mounted) setState(() => _replies[c.id] = p.items);
    } catch (e) {
      if (mounted) BuToast.show(context, postErrorText(e, context.l10n), kind: BuToastKind.error);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final parent = _replyTo;
      final c = await widget.repository.add(widget.post.id, text, parentId: parent?.id);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _input.clear();
        _replyTo = null;
        _count++;
        if (parent == null) {
          _items.insert(0, c);
        } else {
          (_replies[parent.id] ??= []).add(c);
        }
      });
      widget.onCountChanged?.call(_count);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      BuToast.show(context, postErrorText(e, context.l10n), kind: BuToastKind.error);
    }
  }

  Future<void> _report(ReelComment c) async {
    await ReportSheet.show(context, widget.session,
        targetType: 'COMMENT', targetId: c.id);
  }

  Future<void> _toggleLike(ReelComment c, {int? parent}) async {
    final want = !c.likedByMe;
    final next = c.copyWith(likedByMe: want, likeCount: (c.likeCount + (want ? 1 : -1)).clamp(0, 1 << 30));
    void put(ReelComment x) {
      final list = parent == null ? _items : _replies[parent]!;
      final i = list.indexWhere((e) => e.id == c.id);
      if (i >= 0) list[i] = x;
    }

    setState(() => put(next));
    try {
      await widget.repository.setLiked(c.id, want);
    } catch (_) {
      if (mounted) setState(() => put(c));
    }
  }

  Future<void> _delete(ReelComment c, {int? parent}) async {
    try {
      await widget.repository.delete(c.id);
      if (!mounted) return;
      setState(() {
        (parent == null ? _items : _replies[parent]!).removeWhere((e) => e.id == c.id);
        if (_count > 0) _count--;
      });
      widget.onCountChanged?.call(_count);
    } catch (e) {
      if (mounted) BuToast.show(context, postErrorText(e, context.l10n), kind: BuToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final h = MediaQuery.sizeOf(context).height;
    return AnimatedPadding(
      // Klavye açılınca yazma alanı yukarı çıkar, liste bozulmaz.
      duration: BuMotion.of(context, BuMotion.short),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: h * .8, minHeight: h * .5),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(BuSpace.page, 0, BuSpace.page, 8),
            child: Row(children: [
              Expanded(child: Semantics(header: true, child: Text('${l.kesCommentsTitle} ($_count)', style: tt.titleMedium?.copyWith(color: t.ink, fontWeight: FontWeight.w700)))),
              // Sıralama: En iyi (beğeni) | Yeni. Sıralama değişince liste baştan, imleçsiz yüklenir.
              BuChip(
                  key: const ValueKey('commentsSortTop'), label: l.kesCommentsSortTop, selected: _sort == 'top', onTap: () => _setSort('top')),
              BuGap.w8,
              BuChip(
                  key: const ValueKey('commentsSortNew'), label: l.kesCommentsSortNew, selected: _sort == 'new', onTap: () => _setSort('new')),
            ]),
          ),
          Divider(height: 1, color: t.bd),
          Expanded(child: _body(t, tt, l)),
          Divider(height: 1, color: t.bd),
          _composer(t, tt, l),
        ]),
      ),
    );
  }

  Widget _body(BuTokens t, TextTheme tt, AppLocalizations l) {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l.kesCommentsLoadFailed, style: tt.bodyMedium?.copyWith(color: t.mut)),
          TextButton(
              key: const ValueKey('commentsRetry'),
              onPressed: _load,
              style: TextButton.styleFrom(minimumSize: const Size(BuSize.touch, BuSize.touch)),
              child: Text(l.postViewRetry)),
        ]),
      );
    }
    if (_items.isEmpty) {
      return Center(child: Text(l.kesCommentsEmpty, key: const ValueKey('commentsEmpty'), style: tt.bodyMedium?.copyWith(color: t.mut)));
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 240) _load(more: true);
        return false;
      },
      child: ListView.builder(
        key: const ValueKey('commentsList'),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final c = _items[i];
          final rs = _replies[c.id];
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _CommentRow(
              session: widget.session,
              comment: c,
              onLike: () => _toggleLike(c),
              onReply: () {
                setState(() => _replyTo = c);
                _focus.requestFocus();
              },
              onDelete: c.canDelete ? () => _delete(c) : null,
              onReport: c.mine ? null : () => _report(c),
            ),
            if (rs != null)
              for (final r in rs)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 44),
                  child: _CommentRow(
                    session: widget.session,
                    comment: r,
                    compact: true,
                    onLike: () => _toggleLike(r, parent: c.id),
                    onReply: () {
                      // Yanıta yanıt: sunucu ust yoruma yassılar, asıl muhatap replyTo ile döner.
                      setState(() => _replyTo = r);
                      _focus.requestFocus();
                    },
                    onDelete: r.canDelete ? () => _delete(r, parent: c.id) : null,
                    onReport: r.mine ? null : () => _report(r),
                  ),
                )
            else if (c.replyCount > 0)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 64),
                child: TextButton(
                  key: ValueKey('commentReplies-${c.id}'),
                  onPressed: () => _showReplies(c),
                  style: TextButton.styleFrom(minimumSize: const Size(BuSize.touch, 36), foregroundColor: t.mut),
                  child: Text(l.kesCommentsMoreReplies('${c.replyCount}')),
                ),
              ),
          ]);
        },
      ),
    );
  }

  Widget _composer(BuTokens t, TextTheme tt, AppLocalizations l) {
    final reply = _replyTo;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(BuSpace.page, 8, 8, 8),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (reply != null)
            Row(children: [
              Expanded(
                  child: Text(l.kesCommentsReplyingTo(reply.authorName),
                      key: const ValueKey('commentReplyingTo'), maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.bodySmall?.copyWith(color: t.mut))),
              IconButton(
                  tooltip: l.postComposeClose,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  icon: Icon(BuIcons.x, size: 16, color: t.mut),
                  onPressed: () => setState(() => _replyTo = null)),
            ]),
          Row(children: [
            Expanded(
              child: TextField(
                key: const ValueKey('commentInput'),
                controller: _input,
                focusNode: _focus,
                minLines: 1,
                maxLines: 4,
                maxLength: kCommentMaxChars,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(hintText: l.kesCommentsWrite, isDense: true),
              ),
            ),
            IconButton(
              key: const ValueKey('commentSend'),
              tooltip: l.kesCommentsSend,
              constraints: const BoxConstraints(minWidth: BuSize.touch, minHeight: BuSize.touch),
              icon: _sending
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: t.pr))
                  : Icon(BuIcons.send, size: 22, color: _input.text.trim().isEmpty ? t.mut : t.pr),
              onPressed: _input.text.trim().isEmpty || _sending ? null : _send,
            ),
          ]),
        ]),
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({
    required this.session,
    required this.comment,
    required this.onLike,
    required this.onReply,
    this.onDelete,
    this.onReport,
    this.compact = false,
  });

  final Session session;
  final ReelComment comment;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final c = comment;
    final size = compact ? 28.0 : 36.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(BuSpace.page, 6, 8, 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AvatarPreviewTap(
          session: session,
          url: c.authorAvatarUrl,
          name: c.authorName,
          onTap: () => openUserProfile(context, session, userId: c.authorId, name: c.authorName, avatarUrl: c.authorAvatarUrl),
          child: BuAvatar(name: c.authorName, url: c.authorAvatarUrl, size: size, headers: postAuthHeaders(session)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(text: c.authorName, style: tt.titleSmall?.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
                if (c.byPostAuthor) TextSpan(text: '  ${l.kesCommentsAuthorBadge}', style: tt.labelSmall?.copyWith(color: t.prText, fontWeight: FontWeight.w700)),
                TextSpan(text: '  ${postRelativeTime(context, c.createdAt)}', style: tt.bodySmall?.copyWith(color: t.mut)),
              ]),
            ),
            const SizedBox(height: 2),
            Text.rich(TextSpan(children: [
              if (c.replyToName != null) TextSpan(text: '@${c.replyToName} ', style: tt.bodyMedium?.copyWith(color: t.prText, fontWeight: FontWeight.w600)),
              TextSpan(text: c.text),
            ]), style: tt.bodyMedium?.copyWith(color: t.ink, height: 1.35)),
            Row(children: [
              TextButton(
                onPressed: onReply,
                style: TextButton.styleFrom(minimumSize: const Size(BuSize.touch, 36), foregroundColor: t.mut, padding: EdgeInsets.zero),
                child: Text(l.kesCommentsReply, style: tt.labelMedium?.copyWith(color: t.mut, fontWeight: FontWeight.w600)),
              ),
              if (onReport != null)
                IconButton(
                  tooltip: l.postComposeReport,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
                  icon: Icon(BuIcons.flag, size: 16, color: t.mut),
                  onPressed: onReport,
                ),
              if (onDelete != null)
                IconButton(
                  tooltip: l.kesCommentsDelete,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
                  icon: Icon(BuIcons.trash2, size: 16, color: t.mut),
                  onPressed: onDelete,
                ),
            ]),
          ]),
        ),
        InkResponse(
          key: ValueKey('commentLike-${c.id}'),
          onTap: onLike,
          radius: 24,
          child: SizedBox(
            width: BuSize.touch,
            height: BuSize.touch,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(c.likedByMe ? BuIcons.heartFilled : BuIcons.heart, size: 18, color: c.likedByMe ? t.pr : t.mut),
              if (c.likeCount > 0)
                Text('${c.likeCount}', style: tt.labelSmall?.copyWith(color: t.mut, fontFeatures: const [FontFeature.tabularFigures()])),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Hata kodunu kısa mesaja çevirir (yorum yazarken); yeniden kullanım için dışa açık.
String commentErrorText(Object e, BuildContext context) => e is ApiError && e.code == 'CONTENT_PROFANITY'
    ? context.l10n.postComposeErrProfanity
    : postErrorText(e, context.l10n);
