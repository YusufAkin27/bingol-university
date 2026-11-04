import 'package:flutter/material.dart';

import 'chat_avatar_preview.dart';

/// GEÇİCİ yerel sarmalayıcı: SR-MB ajanının `lib/widgets/profile_photo_viewer.dart` bileşeni
/// (`ProfilePhotoViewer.show(context, {required String? imageUrl, String? thumbUrl, String? heroTag})`)
/// birleşene kadar sohbet bilgisi sayfası aynı imzayla bunu çağırır. Birleşmede tek çağrı yeri
/// (`chat_info_page.dart` `_openAvatar`) gerçek bileşene çevrilir, bu dosya silinir.
///
/// Fotoğraf yoksa (`imageUrl` boş) hiçbir şey açılmaz: gizli/kapalı avatar gösterilmez.
abstract final class ChatInfoPhotoViewer {
  static Future<void> show(
    BuildContext context, {
    required String? imageUrl,
    String? thumbUrl,
    String? heroTag,
    String name = '',
    Map<String, String>? headers,
  }) async {
    if (imageUrl == null || imageUrl.isEmpty) return;
    await showChatAvatarPreview(context,
        name: name, url: imageUrl, headers: headers);
  }
}
