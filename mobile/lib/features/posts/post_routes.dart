import 'package:flutter/material.dart';

import '../../core/session.dart';
import 'likers_sheet.dart';
import 'post_detail_page.dart';
import 'post_models.dart';
import 'user_posts_page.dart';

export 'compose_post_page.dart' show openComposePost;

/// Gönderi ekranlarına ince yönlendirme (tek giriş noktası).

/// Gönderi detayı. Sayfa kapanırken güncel [Post] döndürürse çağıran listeyi tazeler.
Future<Post?> openPostDetail(BuildContext context, Session session, int postId,
    {Post? initial, int? focusCommentId}) =>
    Navigator.of(context).push<Post>(MaterialPageRoute<Post>(
        builder: (_) => PostDetailPage(
            session: session, postId: postId, initial: initial, focusCommentId: focusCommentId)));

/// Bir kullanıcının gönderileri.
Future<void> openUserPosts(BuildContext context, Session session, {required int userId, String? name}) =>
    Navigator.push<void>(context,
        MaterialPageRoute<void>(builder: (_) => UserPostsPage(session: session, userId: userId, name: name)));

/// Beğenenler listesi.
Future<void> openLikers(BuildContext context, Session session, int postId) =>
    showLikersSheet(context, session, postId);
