import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
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
          Expanded(child: Text('Gönderiler', style: BuType.heading.copyWith(color: t.ink))),
          TextButton(
            key: const ValueKey('profile-posts-all'),
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => UserPostsPage(session: widget.session, userId: widget.userId, name: widget.name)),
            ),
            child: const Text('Tümünü gör'),
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
    final m = post.media.isEmpty ? null : post.media.first;
    const shadow = [Shadow(blurRadius: 6, color: Colors.black54)];
    return Semantics(
      button: true,
      label: 'Gönderi',
      child: GestureDetector(
        key: ValueKey('profile-post-${post.id}'),
        onTap: () => openPostDetail(context, session, post.id, initial: post),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(fit: StackFit.expand, children: [
            ColoredBox(color: t.sf2),
            if (m != null)
              Image.network(m.thumbUrl ?? m.url,
                  headers: postAuthHeaders(session),
                  cacheWidth: 400,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(child: Icon(LucideIcons.image, color: t.mut)))
            else
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(post.text ?? '',
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: BuType.caption.copyWith(color: t.ink, height: 1.3)),
              ),
            if (m != null && m.isVideo)
              const Positioned(
                  top: 6, right: 6, child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20, shadows: shadow))
            else if (post.media.length > 1)
              const Positioned(
                  top: 6, right: 6, child: Icon(LucideIcons.images, color: Colors.white, size: 16, shadows: shadow)),
          ]),
        ),
      ),
    );
  }
}
