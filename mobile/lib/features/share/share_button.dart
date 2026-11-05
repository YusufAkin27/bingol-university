import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../news/news_tile.dart' show newsSourceHost;
import '../posts/post_models.dart';
import 'share_models.dart';
import 'share_sheet.dart';

/// Gönderi/Reels için paylaşım içeriği. Başlık: gönderi metni (yoksa yazar adı); kaynak: yazar.
/// Gizli hesabın (başkasına ait) gönderisi [ShareContent.restricted] olur: bağlantı/harici paylaşım kapalı.
ShareContent shareContentForPost(Session session, Post p) {
  final caption = (p.text ?? '').trim();
  final mine = p.mine || p.author.id == session.userId;
  final thumb = p.photo?.thumbUrl ?? p.photo?.url;
  return ShareContent(
    type: p.isVideo ? ShareType.reel : ShareType.post,
    id: p.id,
    title: caption.isNotEmpty ? caption : p.author.displayName,
    source: caption.isNotEmpty ? p.author.displayName : null,
    imageUrl: thumb,
    imageHeaders: postAuthHeaders(session),
    isVideo: p.isVideo,
    restricted: p.author.isPrivate && !mine,
    authorId: mine ? null : p.author.id,
  );
}

/// Haber/duyuru için paylaşım içeriği. [item] liste öğesi, [detail] varsa `GET /news/{id}` yanıtı (alanlar birleşir).
ShareContent shareContentForNews(Map<String, dynamic> item, {Map<String, dynamic>? detail}) {
  final m = <String, dynamic>{...item, ...?detail};
  final type = '${m['type'] ?? ''}'.toUpperCase();
  String? str(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
  return ShareContent(
    type: ShareType.news,
    id: (m['id'] as num).toInt(),
    title: str(m['title']),
    source: newsSourceHost(m),
    imageUrl: str(m['imageUrl']),
    isAnnouncement: type == 'DUYURU' || type == 'ANNOUNCEMENT',
  );
}

/// Etkinlik için paylaşım içeriği (`GET /events/{id}` yanıtı).
ShareContent shareContentForEvent(Map<String, dynamic> ev) {
  String? str(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
  final org = ev['organizer'] is Map ? Map<String, dynamic>.from(ev['organizer'] as Map) : null;
  return ShareContent(
    type: ShareType.event,
    id: (ev['id'] as num).toInt(),
    title: str(ev['title']),
    source: str(ev['communityName']) ?? str(org?['displayName']) ?? str(ev['organizerName']),
    imageUrl: str(ev['coverUrl']),
  );
}

/// Paylaş düğmesi: 44 dp dokunma alanı, çizgi simge; ekran okuyucuya "Paylaş".
class ShareIconButton extends StatelessWidget {
  const ShareIconButton({super.key, required this.onTap, this.color, this.size = 22, this.label});

  final VoidCallback onTap;
  final Color? color;
  final double size;

  /// Verilirse simgenin yanında görünür etiket de çizilir.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tip = context.l10n.shareTitle;
    final c = color ?? t.ink;
    return Semantics(
      button: true,
      label: tip,
      excludeSemantics: true,
      child: Tooltip(
        message: tip,
        child: BuPressable(
          onTap: onTap,
          haptic: BuHaptic.light,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: BuSize.touch, minHeight: BuSize.touch),
            child: Center(child: Icon(BuIcons.share2, size: size, color: c)),
          ),
        ),
      ),
    );
  }
}

/// Gönderi kartı / detay paylaş düğmesi.
class PostShareButton extends StatelessWidget {
  const PostShareButton({super.key, required this.session, required this.post, this.color, this.size = 22});

  final Session session;
  final Post post;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) => ShareIconButton(
        key: ValueKey('post-share-${post.id}'),
        color: color,
        size: size,
        onTap: () => showShareSheet(context, session, shareContentForPost(session, post)),
      );
}
