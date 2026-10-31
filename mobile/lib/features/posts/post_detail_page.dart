import 'package:flutter/material.dart';

import '../../core/api.dart' show ApiError;
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart' show ErrorView;
import 'post_api.dart';
import 'post_card.dart';
import 'post_models.dart';

/// Sade gönderi detayı: fotoğraf, yazar, kısa metin, beğeni (yorum yok).
///
/// Sayfa kapanırken güncel [Post] ile pop edilir; ayrıca [onChanged] her değişimde çağrılır
/// (beğeni, düzenleme).
class PostDetailPage extends StatefulWidget {
  const PostDetailPage({
    super.key,
    required this.session,
    required this.postId,
    this.initial,
    this.onChanged,
    this.onDeleted,
    this.heroTag,
  });

  /// Listeden gelen fotoğraf Hero etiketi (yoksa uçuş yok).
  final Object? heroTag;

  final Session session;
  final int postId;
  final Post? initial;
  final ValueChanged<Post>? onChanged;
  final ValueChanged<int>? onDeleted;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  Post? _post;
  Object? _postError;

  @override
  void initState() {
    super.initState();
    _post = widget.initial;
    _loadPost();
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
      if (_post == null || (e is ApiError && e.status == 404)) {
        setState(() => _postError = e);
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final p = _post;
    final fatal = _postError != null && p == null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: t.bg,
        body: Column(
          children: [
            BuHeader(title: context.l10n.postViewPost, onBack: _close),
            const SizedBox(height: 8),
            Expanded(
              child: fatal
                  ? (_postError is ApiError &&
                          (_postError as ApiError).status == 404)
                      ? const _NotFound(key: ValueKey('postNotFound'))
                      : ErrorView(
                          error: _postError!,
                          onRetry: () {
                            setState(() => _postError = null);
                            _loadPost();
                          })
                  : RefreshIndicator(
                      onRefresh: _loadPost,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(0, 4, 0,
                            MediaQuery.of(context).padding.bottom + 24),
                        children: [
                          if (p == null)
                            const Padding(
                              padding: BuSpace.pageH,
                              child: PostCardSkeleton(),
                            )
                          else
                            PostCard(
                              session: widget.session,
                              post: p,
                              detail: true,
                              heroTag: widget.heroTag,
                              onChanged: _onPostChanged,
                              onDeleted: _onPostDeleted,
                            ),
                        ],
                      ),
                    ),
            ),
          ],
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
