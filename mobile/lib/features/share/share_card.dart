import 'package:flutter/material.dart';

import '../../core/api.dart' show apiOrigin;
import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import '../chat/chatd_parts.dart' show ChatdPlay;
import 'share_models.dart';

/// Tür etiketi ("Gönderi", "Reels", "Haber", "Duyuru", "Etkinlik").
String shareKindLabel(BuildContext context, ShareType type, {bool announcement = false}) {
  final l = context.l10n;
  return switch (type) {
    ShareType.post => l.shareKindPost,
    ShareType.reel => l.shareKindReel,
    ShareType.news => announcement ? l.shareKindAnnouncement : l.shareKindNews,
    ShareType.event => l.shareKindEvent,
    ShareType.forumTopic => l.forumShareKindTopic,
    ShareType.forumComment => l.forumShareKindComment,
  };
}

IconData shareKindIcon(ShareType type, {bool announcement = false}) => switch (type) {
      ShareType.post => BuIcons.image,
      ShareType.reel => BuIcons.video,
      ShareType.news => announcement ? BuIcons.megaphone : BuIcons.newspaper,
      ShareType.event => BuIcons.calendarDays,
      ShareType.forumTopic => BuIcons.messageSquareText,
      ShareType.forumComment => BuIcons.messageCircle,
    };

BuTint shareKindTint(BuTokens t, ShareType type, {bool announcement = false}) => t.tint(switch (type) {
      ShareType.post => BuTintId.brand,
      ShareType.reel => BuTintId.brand,
      ShareType.news => announcement ? BuTintId.aqua : BuTintId.blue,
      ShareType.event => BuTintId.amber,
      ShareType.forumTopic || ShareType.forumComment => BuTintId.slate,
    });

/// Sohbet listesinde son mesaj önizlemesi ("Gönderi paylaştı"...). Paylaşım yoksa null.
String? sharePreviewText(BuildContext context, Map<dynamic, dynamic>? message) {
  if (message == null) return null;
  final info = ShareInfo.fromMessage(Map<String, dynamic>.from(message));
  // Sunucu `share` yollamadıysa ama yedek metin paylaşım bağlantısıysa türü bağlantıdan al.
  final type = info?.type ?? parseShareLink(message['text'])?.type;
  if (type == null) return null;
  final l = context.l10n;
  return switch (type) {
    ShareType.post => l.shareChatPostShared,
    ShareType.reel => l.shareChatReelShared,
    ShareType.news => (info?.isAnnouncement ?? false) ? l.shareChatAnnouncementShared : l.shareChatNewsShared,
    ShareType.event => l.shareChatEventShared,
    ShareType.forumTopic => l.forumShareChatTopicShared,
    ShareType.forumComment => l.forumShareChatCommentShared,
  };
}

/// Yetkili başlıklar yalnız kendi sunucumuzun `/api/` adreslerine gider (üçüncü taraf görsele Bearer sızmasın).
Map<String, String>? shareImageHeaders(String? url, Map<String, String>? headers) {
  if (url == null || headers == null || headers.isEmpty) return null;
  if (url.startsWith('/api/') || url.startsWith('$apiOrigin/api/')) return headers;
  return null;
}

/// Sohbet balonu içindeki paylaşım ÖNİZLEME KARTI: üstte 16:9 görsel (video/Reels ise oynat rozeti), altında tür
/// etiketi + başlık (2 satır) + kaynak. İçerik kullanılamıyorsa "Bu içerik artık görüntülenemiyor" yer tutucusu.
/// Kart kendi dokunma hedefidir ([onTap]); balon zeminine göre ton ayarlar ([mine]: kırmızı zemin üstünde açık, aksi halde yüzey).
class ShareCard extends StatelessWidget {
  const ShareCard({
    super.key,
    required this.info,
    required this.mine,
    required this.width,
    this.headers,
    this.onTap,
    this.footer,
  });

  final ShareInfo info;
  final bool mine;

  /// Kartın dış genişliği (balon iç genişliği).
  final double width;
  final Map<String, String>? headers;
  final VoidCallback? onTap;

  /// Kartın altında (saat/tik satırı) çizilecek parça; yoksa kart kendi başına durur.
  final Widget? footer;

  static const double _radius = 14;

  /// Gönderi/Reels için sunucu nedeni söylemez (silinmiş, gizli hesap, engel ayırt edilmez); metin yalnız ihtimali anar.
  String _unavailableText(BuildContext context) {
    final l = context.l10n;
    return info.type == ShareType.post || info.type == ShareType.reel ? l.shareUnavailablePost : l.shareUnavailable;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    // Giden balon kırmızı: kart zemini onPr'nin saydam tonu; gelen balon yüzey: kart zemini sf2.
    final cardBg = mine ? t.onPr.withValues(alpha: .14) : t.sf2;
    final fg = mine ? t.onPr : t.ink;
    final sub = mine ? t.onPr.withValues(alpha: .8) : t.mut;
    // Forum kartında tür etiketi yerine kategori adı (varsa); başlık konu başlığı, alt satır yazar (anonimde sunucu vermez).
    final isForum = info.type == ShareType.forumTopic || info.type == ShareType.forumComment;
    final kindLabel = shareKindLabel(context, info.type, announcement: info.isAnnouncement);
    final label = isForum && (info.category ?? '').isNotEmpty ? info.category! : kindLabel;
    final tint = shareKindTint(t, info.type, announcement: info.isAnnouncement);
    final icon = shareKindIcon(info.type, announcement: info.isAnnouncement);
    final ready = info.available;
    final title = (info.title ?? '').trim();
    final source = (info.subtitle ?? '').trim();
    final hasImage = ready && info.imageUrl != null;
    // Gönderi/Reels: yalnız görsel + sahibinin adı (tür etiketi, açıklama yok). Görsel gönderiye sadık, kareye yakın.
    final authorOnly = ready && (info.type == ShareType.post || info.type == ShareType.reel);
    final imgH = authorOnly ? width : width * 9 / 16;

    Widget media;
    if (!ready) {
      media = SizedBox(
        height: imgH * .62,
        child: ColoredBox(
          color: mine ? t.onPr.withValues(alpha: .1) : t.sf3,
          child: Center(child: Icon(BuIcons.imageOff, size: 28, color: sub)),
        ),
      );
    } else if (hasImage) {
      media = SizedBox(
        height: imgH,
        child: Stack(fit: StackFit.expand, children: [
          BuImage(info.imageUrl,
              width: width,
              height: imgH,
              headers: shareImageHeaders(info.imageUrl, headers),
              maxDecodeWidth: 700,
              placeholderIcon: icon),
          if (info.showPlay) const Center(child: ChatdPlay(size: 44)),
        ]),
      );
    } else {
      // Görseli olmayan içerik (haber, bazı duyurular/etkinlikler): tonlu türsel karo.
      media = SizedBox(
        height: imgH * .62,
        child: ColoredBox(
          color: tint.bg,
          child: Center(child: Icon(icon, size: 30, color: tint.fg)),
        ),
      );
    }

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(_radius),
      child: ColoredBox(
        color: cardBg,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          media,
          if (authorOnly)
            (source.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 10),
                    child: Text(source,
                        key: const ValueKey('share-card-source'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tx.bodyMedium!.copyWith(color: fg, fontWeight: FontWeight.w400)),
                  ))
          else
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                ExcludeSemantics(child: Icon(icon, size: 14, color: sub)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(trUpper(label),
                      key: const ValueKey('share-card-kind'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // letterSpacing yok: Arapçada harf bağlantısını koparır.
                      style: tx.labelSmall!.copyWith(color: sub, fontWeight: FontWeight.w400)),
                ),
              ]),
              const SizedBox(height: 4),
              if (!ready)
                Text(_unavailableText(context),
                    key: const ValueKey('share-card-unavailable'),
                    style: tx.bodyMedium!.copyWith(color: fg, fontWeight: FontWeight.w400, height: 1.3))
              else if (title.isNotEmpty)
                Text(title,
                    key: const ValueKey('share-card-title'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tx.bodyMedium!.copyWith(color: fg, fontWeight: FontWeight.w400, height: 1.3)),
              if (ready && source.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(source,
                    key: const ValueKey('share-card-source'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tx.bodySmall!.copyWith(color: sub)),
              ],
            ]),
          ),
        ]),
      ),
    );

    final tappable = BuPressable(
      scale: .985,
      onTap: onTap,
      enabled: onTap != null,
      semanticLabel: ready ? '$label, ${authorOnly ? source : (title.isNotEmpty ? title : source)}' : '$label, ${_unavailableText(context)}',
      child: card,
    );
    return SizedBox(
      width: width,
      child: footer == null
          ? tappable
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [tappable, footer!]),
    );
  }
}
