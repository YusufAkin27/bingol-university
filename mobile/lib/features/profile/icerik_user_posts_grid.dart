import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';

import '../../widgets/bu.dart';
import '../news/icerik_parts.dart';
import '../posts/post_api.dart';
import '../posts/post_models.dart';
import '../posts/post_routes.dart';

/// Kullanıcı profilindeki "Gönderiler" bölümü (Ic5): 3 sütun, 3 dp aralıklı kare tek fotoğraf ızgarası.
/// Gönderi yoksa, hata olursa ya da engel ilişkisinde (sunucu boş döner) hiçbir şey çizmez.
/// [onCount] toplam (ya da bilinen en az) gönderi sayısını üst sayfadaki sayaca bildirir.
class IcerikUserPostsGrid extends StatefulWidget {
  const IcerikUserPostsGrid({super.key, required this.session, required this.userId, this.name, this.onCount});

  final Session session;
  final int userId;
  final String? name;
  final void Function(String count)? onCount;

  @override
  State<IcerikUserPostsGrid> createState() => _IcerikUserPostsGridState();
}

class _IcerikUserPostsGridState extends State<IcerikUserPostsGrid> {
  static const _size = 9;
  List<Post>? _posts;
  bool _more = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = PostApi(widget.session);
    try {
      final r = widget.userId == widget.session.userId
          ? await api.minePosts(size: _size)
          : await api.userPosts(widget.userId, size: _size);
      final items = r.items.take(_size).toList();
      if (!mounted) return;
      setState(() {
        _posts = items;
        _more = r.hasMore;
      });
      widget.onCount?.call('${r.total ?? items.length}${r.total == null && r.hasMore ? '+' : ''}');
    } catch (_) {
      // Bölüm isteğe bağlıdır: hata sessizce gizler.
    }
  }

  @override
  Widget build(BuildContext context) {
    final posts = _posts;
    if (posts == null || posts.isEmpty) return const SizedBox.shrink();
    final t = context.bu;
    return Padding(
      key: const ValueKey('profile-posts-section'),
      padding: const EdgeInsets.only(top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 26, end: 14),
          child: Row(children: [
            Expanded(
              child: Semantics(header: true, child: Text(context.l10n.icerikPostsHeading, style: icerikSectionStyle(t))),
            ),
            if (_more)
              TextButton(
                key: const ValueKey('profile-posts-all'),
                onPressed: () => openUserPosts(context, widget.session, userId: widget.userId, name: widget.name),
                child: Text(context.l10n.postViewSeeAll, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: t.pr)),
              ),
          ]),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            children: [for (final p in posts) _Tile(session: widget.session, post: p)],
          ),
        ),
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.session, required this.post});

  final Session session;
  final Post post;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final m = post.photo;
    return Semantics(
      button: true,
      label: context.l10n.icerikOpenPost,
      excludeSemantics: true,
      child: BuPressable(
        key: ValueKey('profile-post-${post.id}'),
        scale: .96,
        onTap: () => openPostDetail(context, session, post.id, initial: post),
        child: ClipRRect(
          borderRadius: BuRadius.bXs,
          child: Stack(fit: StackFit.expand, children: [
            ColoredBox(color: t.sf2),
            if (m != null)
              BuImage(m.thumbUrl ?? m.url, headers: postAuthHeaders(session), maxDecodeWidth: 400)
            else
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(post.text ?? '',
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(color: t.ink, height: 1.3)),
              ),
          ]),
        ),
      ),
    );
  }
}
