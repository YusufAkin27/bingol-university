import 'package:flutter/material.dart';

import '../../core/session.dart';
import 'post_detail_page.dart';
import 'post_models.dart';
import 'user_posts_page.dart';

export 'compose_post_page.dart' show openComposePost;

/// Gönderi ekranlarına ince yönlendirme (tek giriş noktası).

/// Gönderi detayı. Sayfa kapanırken güncel [Post] döndürürse çağıran listeyi tazeler.
/// [heroTag] verilirse listedeki fotoğraf detaya paylaşılan öğe olarak uçar (aynı etiket kartta da kullanılmalı).
Future<Post?> openPostDetail(BuildContext context, Session session, int postId, {Post? initial, Object? heroTag}) =>
    Navigator.of(context).push<Post>(MaterialPageRoute<Post>(
        builder: (_) => PostDetailPage(session: session, postId: postId, initial: initial, heroTag: heroTag)));

/// Bir kullanıcının gönderileri.
Future<void> openUserPosts(BuildContext context, Session session, {required int userId, String? name}) =>
    Navigator.push<void>(context,
        MaterialPageRoute<void>(builder: (_) => UserPostsPage(session: session, userId: userId, name: name)));
