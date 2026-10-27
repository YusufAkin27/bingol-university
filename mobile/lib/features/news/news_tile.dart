import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../../core/typography.dart';

/// Haber türü -> rozet metni; duyuru/etkinlik yumuşak kırmızı, haber koyu.
bool _softBadge(String? type) => type != 'HABER';

/// Etkinlikte etkinlik tarihi (varsa), aksi halde yayın tarihi.
String newsDateLabel(Map<String, dynamic> item) {
  final ev = item['eventDate'] as String?;
  if (item['type'] == 'ETKINLIK' && ev != null && ev.isNotEmpty) return 'Etkinlik: ${niceDate(ev)}';
  return niceDate(item['publishedDate'] as String?);
}

/// 76x76 küçük resim; çözümleme boyutu sınırlı (bellek/kaydırma performansı).
class _Thumb extends StatelessWidget {
  const _Thumb(this.url);

  final String? url;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final box = Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(14)),
      child: Icon(LucideIcons.image, color: t.mut),
    );
    final u = url;
    if (u == null || u.isEmpty) return box;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        u,
        width: 76,
        height: 76,
        cacheWidth: 228,
        cacheHeight: 228,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => box,
        loadingBuilder: (_, child, p) => p == null ? child : box,
      ),
    );
  }
}

/// Liste satırı: küçük resim, rozet, başlık, tarih, favori düğmesi.
class NewsTile extends StatelessWidget {
  const NewsTile({
    super.key,
    required this.item,
    required this.onTap,
    this.saved = false,
    this.onToggleSave,
  });

  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final bool saved;
  final VoidCallback? onToggleSave;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final type = item['type'] as String?;
    return BuCard(
      padding: const EdgeInsets.all(12),
      radius: 20,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Thumb(item['imageUrl'] as String?),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BuBadge(TypeBadge.label(type), soft: _softBadge(type)),
                const SizedBox(height: 6),
                Text(
                  (item['title'] as String?) ?? '',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: BuType.bodyStrong.copyWith(height: 1.35, color: t.ink),
                ),
                const SizedBox(height: 4),
                Text(newsDateLabel(item), style: BuType.caption.copyWith(color: t.mut)),
              ],
            ),
          ),
          if (onToggleSave != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggleSave,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 8),
                child: Tooltip(
                  message: saved ? 'Favorilerden çıkar' : 'Favorilere ekle',
                  child: Icon(saved ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
                      size: 22,
                      color: saved ? t.pr : t.mut),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Keşfet'in öne çıkan büyük kartı: gradyan/görsel üst alan + başlık + tarih.
class NewsFeaturedCard extends StatelessWidget {
  const NewsFeaturedCard({
    super.key,
    required this.item,
    required this.onTap,
    this.saved = false,
    this.onToggleSave,
  });

  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final bool saved;
  final VoidCallback? onToggleSave;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final img = item['imageUrl'] as String?;
    return BuCard(
      padding: EdgeInsets.zero,
      radius: 20,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 150,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(decoration: BoxDecoration(gradient: t.hero)),
                Positioned(
                  right: -30,
                  top: -40,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: Colors.white.withValues(alpha: .15)),
                  ),
                ),
                if (img != null && img.isNotEmpty)
                  Image.network(img,
                      fit: BoxFit.cover,
                      cacheWidth: 800,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      loadingBuilder: (_, child, p) => p == null ? child : const SizedBox.shrink()),
                Positioned(
                  left: 14,
                  top: 14,
                  child: BuBadge(TypeBadge.label(item['type'] as String?),
                      color: Colors.white, onColor: BuColors.red800),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((item['title'] as String?) ?? '',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: BuType.heading.copyWith(height: 1.3, color: t.ink)),
                      const SizedBox(height: 6),
                      Text(newsDateLabel(item), style: BuType.caption.copyWith(color: t.mut)),
                    ],
                  ),
                ),
                if (onToggleSave != null)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onToggleSave,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Icon(saved ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
                          size: 24, color: saved ? t.pr : t.mut),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
