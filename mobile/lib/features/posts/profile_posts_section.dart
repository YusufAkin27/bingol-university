import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';

import '../../widgets/bu.dart';
import 'post_api.dart';
import 'post_models.dart';
import 'post_routes.dart';
import 'user_posts_page.dart';

/// Profil sayfasındaki "Gönderiler" bölümü: son 6 gönderinin kare küçük resim ızgarası + "Tümünü gör".
/// Gönderi yoksa, hata olursa ya da engel ilişkisinde (sunucu boş döner) hiçbir şey çizmez.
class ProfilePostsSection extends StatefulWidget {
  const ProfilePostsSection({super.key, required this.session, required this.userId, this.name});

  final Session session;
  final int userId;
  final String? name;

  @override
  State<ProfilePostsSection> createState() => _ProfilePostsSectionState();
}

class _ProfilePostsSectionState extends State<ProfilePostsSection> {
  List<Post>? _posts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = PostApi(widget.session);
    try {
      final r = widget.userId == widget.session.userId
          ? await api.minePosts(size: 6)
          : await api.userPosts(widget.userId, size: 6);
      if (mounted) setState(() => _posts = r.items.take(6).toList());
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
      padding: const EdgeInsets.only(top: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(context.l10n.postViewPosts, style: Theme.of(context).textTheme.titleMedium!.copyWith(color: t.ink))),
          TextButton(
            key: const ValueKey('profile-posts-all'),
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => UserPostsPage(session: widget.session, userId: widget.userId, name: widget.name)),
            ),
            child: Text(context.l10n.postViewSeeAll),
          ),
        ]),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [for (final p in posts) _Tile(session: widget.session, post: p)],
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
      label: context.l10n.postViewPost,
      child: BuPressable(
        key: ValueKey('profile-post-${post.id}'),
        scale: .96,
        onTap: () => openPostDetail(context, session, post.id, initial: post),
        child: ClipRRect(
          borderRadius: BuRadius.bSm,
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
