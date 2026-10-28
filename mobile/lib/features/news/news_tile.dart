import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../../core/typography.dart';
import 'icerik_parts.dart';

/// Haber türü -> rozet metni; duyuru/etkinlik yumuşak kırmızı, haber koyu.
bool _softBadge(String? type) => type != 'HABER';

/// Sunucudan gelen sabit tür kodunun ekranda görünen adı (dile göre).
String newsTypeLabel(BuildContext context, String? type) {
  final l = context.l10n;
  return switch (type) {
    'HABER' || 'NEWS' => l.newsTypeNews,
    'DUYURU' || 'ANNOUNCEMENT' => l.newsTypeAnnouncement,
    'ETKINLIK' || 'EVENT' => l.newsTypeEvent,
    _ => type ?? '',
  };
}

/// Ay adı (1-12), dile göre.
String newsMonthName(BuildContext context, int month) {
  final l = context.l10n;
  return [
    l.newsMonth1,
    l.newsMonth2,
    l.newsMonth3,
    l.newsMonth4,
    l.newsMonth5,
    l.newsMonth6,
    l.newsMonth7,
    l.newsMonth8,
    l.newsMonth9,
    l.newsMonth10,
    l.newsMonth11,
    l.newsMonth12,
  ][month - 1];
}

/// Gün adı (1 Pazartesi - 7 Pazar), dile göre; [short] true ise kısa biçim.
String newsWeekdayName(BuildContext context, int weekday, {bool short = false}) {
  final l = context.l10n;
  final list = short
      ? [l.newsDayShort1, l.newsDayShort2, l.newsDayShort3, l.newsDayShort4, l.newsDayShort5, l.newsDayShort6, l.newsDayShort7]
      : [l.newsDayLong1, l.newsDayLong2, l.newsDayLong3, l.newsDayLong4, l.newsDayLong5, l.newsDayLong6, l.newsDayLong7];
  return list[weekday - 1];
}

/// "26 Ekim 2026" (ISO tarih ya da zaman damgasından); ayrıştırılamazsa sayısal biçim.
String newsLocalDate(BuildContext context, String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  return d == null ? fmtDate(iso) : '${d.day} ${newsMonthName(context, d.month)} ${d.year}';
}

/// Etkinlikte etkinlik tarihi (varsa), aksi halde yayın tarihi.
String newsDateLabel(BuildContext context, Map<String, dynamic> item) {
  final ev = item['eventDate'] as String?;
  if (item['type'] == 'ETKINLIK' && ev != null && ev.isNotEmpty) {
    return context.l10n.newsEventDateShort(newsLocalDate(context, ev));
  }
  return newsLocalDate(context, item['publishedDate'] as String?);
}

/// Kaynak site adı: haber bağlantısından alan adı; yoksa üniversite sitesi.
String newsSourceHost(Map<String, dynamic> item) {
  final u = Uri.tryParse((item['url'] as String?) ?? '');
  final h = u?.host ?? '';
  if (h.isEmpty) return 'bingol.edu.tr';
  return h.startsWith('www.') ? h.substring(4) : h;
}

/// Liste satırı (Ic2/Ic4): küçük resim, rozet, başlık, kaynak + tarih, isteğe bağlı favori düğmesi.
class NewsTile extends StatelessWidget {
  const NewsTile({
    super.key,
    required this.item,
    required this.onTap,
    this.saved = false,
    this.onToggleSave,
    this.thumbSize = 84,
    this.showSource = true,
  });

  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final bool saved;
  final VoidCallback? onToggleSave;
  final double thumbSize;

  /// Meta satırının başına kaynak site adı eklenir (favorilerde yalnız tarih).
  final bool showSource;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final type = item['type'] as String?;
    final date = newsDateLabel(context, item);
    final meta = showSource ? '${newsSourceHost(item)} · $date' : date;
    final hasSave = onToggleSave != null;
    return IcerikCard(
      onTap: onTap,
      padding: EdgeInsetsDirectional.fromSTEB(12, 12, hasSave ? 4 : 12, 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Row(
          crossAxisAlignment: hasSave ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            IcerikThumb(url: item['imageUrl'] as String?, size: thumbSize),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: IcerikBadge(newsTypeLabel(context, type), soft: _softBadge(type)),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 6, bottom: hasSave ? 3 : 6),
                    child: Text(
                      (item['title'] as String?) ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: BuType.bodyStrong.copyWith(fontSize: 15, fontWeight: FontWeight.w700, height: 1.3, color: t.ink),
                    ),
                  ),
                  Text(meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BuType.caption.copyWith(fontSize: 12.5, color: t.mut)),
                ],
              ),
            ),
            if (hasSave) _SaveIcon(saved: saved, onTap: onToggleSave!, size: 20),
          ],
        ),
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
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .15)),
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
                  child:
                      BuBadge(newsTypeLabel(context, item['type'] as String?), color: Colors.white, onColor: BuColors.red800),
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
                      Text(newsDateLabel(context, item), style: BuType.caption.copyWith(color: t.mut)),
                    ],
                  ),
                ),
                if (onToggleSave != null) _SaveIcon(saved: saved, onTap: onToggleSave!, size: 21.5),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Favori simgesi: görünür 20 dp, dokunma alanı 44x44 dp; ekran okuyucuya düğme olarak bildirilir.
class _SaveIcon extends StatelessWidget {
  const _SaveIcon({required this.saved, required this.onTap, required this.size});

  final bool saved;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final label = saved ? context.l10n.newsSaveRemove : context.l10n.newsSaveAdd;
    return Semantics(
      button: true,
      toggled: saved,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child:
                Icon(saved ? LucideIcons.bookmarkCheck : LucideIcons.bookmark, size: size, color: saved ? t.pr : t.mut),
          ),
        ),
      ),
    );
  }
}
