import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../widgets/profile_photo_viewer.dart';
import 'post_models.dart';

/// Avatar/ad üzerinde: dokunma = [onTap] (ör. profil), UZUN BASMA = ortak blur önizleme ([AvatarLongPress] /
/// [ProfilePhotoViewer], SR-MB). Keşfet/Reels/gönderi/yorum satırlarında tek çağrı noktasıdır; fotoğraf yoksa uzun basma
/// hiçbir şey açmaz (gizlilik).
class AvatarPreviewTap extends StatelessWidget {
  const AvatarPreviewTap({super.key, required this.session, required this.url, required this.onTap, required this.child, this.name});

  final Session session;
  final String? url;
  final String? name;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => AvatarLongPress(
        imageUrl: url == null || url!.isEmpty ? null : postMediaUrl(url!),
        thumbUrl: url == null || url!.isEmpty ? null : postMediaUrl(url!),
        headers: postAuthHeaders(session),
        title: name,
        onTap: onTap,
        child: child,
      );
}
