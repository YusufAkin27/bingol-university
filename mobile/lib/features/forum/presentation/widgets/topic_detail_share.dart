import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// Forum bağlantısını sistem paylaşım sayfasıyla paylaşır (konu: `/s/f/{id}`, yorum: `/s/fc/{id}`).
typedef ForumShareFn = Future<void> Function(String text);

/// Test kancası: sistem paylaşım sayfası çağrısı. Varsayılan `share_plus`.
@visibleForTesting
ForumShareFn? debugForumShare;

/// Paylaşım açılamazsa sessizce `false` döner (çağıran toast gösterebilir).
Future<bool> shareForumLink(String url) async {
  try {
    await (debugForumShare ?? (t) => SharePlus.instance.share(ShareParams(text: t)))(url);
    return true;
  } catch (_) {
    return false;
  }
}
