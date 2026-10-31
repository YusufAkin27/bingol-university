import 'package:flutter/material.dart';

import '../../core/session.dart';
import 'post_detail_page.dart';
import 'post_models.dart';
import 'post_stream.dart';
import 'user_posts_page.dart';

export 'compose_post_page.dart' show openComposePost;
export 'post_stream.dart' show PostStreamSeed;

/// Gönderi ekranlarına ince yönlendirme (tek giriş noktası).

/// Gönderi sayfası (dikey akış). Sayfa kapanırken açılan gönderinin güncel [Post] hâlini döndürür; akıştaki diğer
/// gönderilerde olan beğeni/düzenleme/silme [onChanged] / [onDeleted] ile anında bildirilir.
/// [heroTag] verilirse listedeki fotoğraf sayfaya paylaşılan öğe olarak uçar (aynı etiket kutuda da kullanılmalı).
/// [stream] verilirse gönderinin altında akış sürer ([PostStreamSeed]); verilmezse yalnız o gönderi gösterilir.
Future<Post?> openPostDetail(
  BuildContext context,
  Session session,
  int postId, {
  Post? initial,
  Object? heroTag,
  PostStreamSeed? stream,
  ValueChanged<Post>? onChanged,
  ValueChanged<int>? onDeleted,
}) =>
    Navigator.of(context).push<Post>(MaterialPageRoute<Post>(
        builder: (_) => PostDetailPage(
              session: session,
              postId: postId,
              initial: initial,
              heroTag: heroTag,
              stream: stream,
              onChanged: onChanged,
              onDeleted: onDeleted,
            )));

/// Bir kullanıcının gönderileri.
Future<void> openUserPosts(BuildContext context, Session session, {required int userId, String? name}) =>
    Navigator.push<void>(context,
        MaterialPageRoute<void>(builder: (_) => UserPostsPage(session: session, userId: userId, name: name)));
