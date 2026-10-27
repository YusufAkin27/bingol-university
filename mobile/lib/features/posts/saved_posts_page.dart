import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../widgets/bu_widgets.dart' show LucideIcons;
import 'paged_posts_page.dart';
import 'social_api.dart';

/// Profil > Kaydedilen gönderiler. Yer imi kaldırılan gönderi listeden düşer.
class SavedPostsPage extends StatelessWidget {
  const SavedPostsPage({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final api = SocialApi(session);
    return PagedPostsPage(
      session: session,
      title: 'Kaydedilen gönderiler',
      fetch: (cursor) => api.savedPosts(cursor: cursor),
      emptyText: 'Henüz kaydettiğin bir gönderi yok.',
      emptyIcon: LucideIcons.bookmark,
      removeWhenUnsaved: true,
    );
  }
}
