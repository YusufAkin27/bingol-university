import 'package:flutter/material.dart';

import '../../../../core/session.dart';
import 'forum_placeholder_page.dart';

/// Forum ana sayfası (geçici gövde; gerçek sayfa aynı dalda hemen ardından gelir).
class ForumHomePage extends StatelessWidget {
  const ForumHomePage({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) => const ForumPlaceholderPage(name: 'forum_home');
}
