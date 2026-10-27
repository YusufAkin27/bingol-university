import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../widgets/bu_widgets.dart' show LucideIcons;
import 'paged_posts_page.dart';
import 'social_api.dart';

/// `#etiket` akışı (`GET /hashtags/{tag}/posts`).
Future<void> openHashtagPosts(BuildContext context, Session session, String tag) =>
    Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => HashtagPostsPage(session: session, tag: tag)));

class HashtagPostsPage extends StatelessWidget {
  const HashtagPostsPage({super.key, required this.session, required this.tag});

  final Session session;
  final String tag;

  @override
  Widget build(BuildContext context) {
    final api = SocialApi(session);
    final clean = tag.replaceFirst('#', '');
    return PagedPostsPage(
      session: session,
      title: '#$clean',
      fetch: (cursor) => api.hashtagPosts(clean, cursor: cursor),
      emptyText: '#$clean etiketli gönderi yok.',
      emptyIcon: LucideIcons.hash,
    );
  }
}
