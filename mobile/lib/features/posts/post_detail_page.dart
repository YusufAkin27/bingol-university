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
  });

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
                        padding: EdgeInsets.fromLTRB(16, 4, 16,
                            MediaQuery.of(context).padding.bottom + 24),
                        children: [
                          if (p == null)
                            Container(
                              height: 320,
                              decoration: BoxDecoration(
                                  color: t.sf2,
                                  borderRadius: BorderRadius.circular(20)),
                            )
                          else
                            PostCard(
                              session: widget.session,
                              post: p,
                              detail: true,
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

/// "Gönderi bulunamadı (silinmiş veya gizlenmiş olabilir)" bilgi kartı (referans 11/6).
class _NotFound extends StatelessWidget {
  const _NotFound({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.topCenter,
        child: DecoratedBox(
          decoration: BoxDecoration(
              color: t.sf,
              borderRadius: BorderRadius.circular(BuRadius.lg),
              boxShadow: BuElevation.of(context, 1)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle),
                child: Icon(LucideIcons.info, size: 20, color: t.mut),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(context.l10n.p04PostNotFound,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: t.mut))),
            ]),
          ),
        ),
      ),
    );
  }
}
