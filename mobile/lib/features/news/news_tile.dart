import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart';
import 'icerik_parts.dart';

/// Tür rozeti tonu: haber koyu mavi (null = varsayılan), duyuru su mavisi, etkinlik amber (tarihli/hatırlatma).
BuTint? newsTypeTint(BuTokens t, String? type) => switch (type) {
      'DUYURU' || 'ANNOUNCEMENT' => t.tint(BuTintId.aqua),
      'ETKINLIK' || 'EVENT' => t.tint(BuTintId.amber),
      _ => null,
    };

/// Tür simgesi (görseli olmayan haberin karosu ve rozet).
IconData newsTypeIcon(String? type) => switch (type) {
      'DUYURU' || 'ANNOUNCEMENT' => LucideIcons.megaphone,
      'ETKINLIK' || 'EVENT' => LucideIcons.calendar,
      _ => LucideIcons.newspaper,
    };

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

/// Liste satırı (Ic2/Ic4): sade, çerçevesiz satır: küçük görsel (yoksa nötr karo), başlık, tarih (+ gerekirse tür),
/// isteğe bağlı sakin favori düğmesi. Görsel, detay sayfasının kapağına paylaşılan geçişle (Hero) uçar.
class NewsTile extends StatelessWidget {
  const NewsTile({
    super.key,
    required this.item,
    required this.onTap,
    this.saved = false,
    this.onToggleSave,
    this.thumbSize = 84,
    this.showSource = true,
    this.showType = true,
  });

  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final bool saved;
  final VoidCallback? onToggleSave;
  final double thumbSize;

  /// Kaynak site adı yalnız üniversitenin ana sitesinden farklıysa meta satırına eklenir (aynı ad her satırda gürültüdür).
  final bool showSource;

  /// Meta satırının başında tür adı (sekmeyle zaten belli olan listede kapatılır). Rozet çizilmez.
  final bool showType;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final type = item['type'] as String?;
    final host = newsSourceHost(item);
    final meta = [
      if (showType) newsTypeLabel(context, type),
      newsDateLabel(context, item),
      if (showSource && host != 'bingol.edu.tr') host,
    ].join(' • ');
    final hasSave = onToggleSave != null;
    final img = item['imageUrl'] as String?;
    final id = (item['id'] as num?)?.toInt();
    final evDate = type == 'ETKINLIK' ? DateTime.tryParse((item['eventDate'] as String?) ?? '') : null;
    final noImg = img == null || img.isEmpty;
    // Görselsiz etkinlik: nötr tarih karosu ("18 KAS"); diğerleri nötr tür simgeli karo (kategori başına renk yok).
    Widget thumb = (noImg && evDate != null)
        ? _EventDateTile(date: evDate, size: thumbSize)
        : IcerikThumb(url: img, size: thumbSize, radius: BuRadius.sm, fallbackIcon: newsTypeIcon(type));
    if (id != null && img != null && img.isNotEmpty) thumb = newsHero(id: id, radius: BuRadius.sm, child: thumb);
    return BuPressable(
      scale: .985,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              thumb,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (item['title'] as String?) ?? '',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w600, height: 1.32, color: t.ink),
                    ),
                    const SizedBox(height: 6),
                    Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
                  ],
                ),
              ),
              if (hasSave) _SaveIcon(saved: saved, onTap: onToggleSave!),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keşfet'in öne çıkan büyük kartı: kapak görseli (yoksa marka gradyanı) + altta başlık ve tarih.
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
    final tx = Theme.of(context).textTheme;
    final img = item['imageUrl'] as String?;
    final hasImg = img != null && img.isNotEmpty;
    final type = item['type'] as String?;
    final id = (item['id'] as num?)?.toInt();
    final tint = newsTypeTint(t, type);
    final r = BorderRadius.circular(24);
    Widget cover = hasImg
        ? BuImage(img, height: 220, width: double.infinity, maxDecodeWidth: 1200)
        : DecoratedBox(
            decoration: BoxDecoration(gradient: t.hero),
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: Align(
                alignment: AlignmentDirectional.topEnd,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 28, top: 56),
                  child: Icon(newsTypeIcon(type), size: 84, color: t.onMedia.withValues(alpha: .16)),
                ),
              ),
            ),
          );
    if (id != null && hasImg) cover = newsHero(id: id, radius: 24, child: cover);
    return BuPressable(
      scale: .98,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: r, boxShadow: BuElevation.of(context, 1)),
        child: ClipRRect(
          borderRadius: r,
          child: SizedBox(
            height: 220,
            child: Stack(
              fit: StackFit.expand,
              children: [
                cover,
                // Yazı okunurluğu için alt kısımda durağan karartma (saveLayer/blur yok).
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [.3, 1],
                          colors: [t.scrim.withValues(alpha: 0), t.scrim.withValues(alpha: .82)],
                        ),
                      ),
                    ),
                  ),
                ),
                // Dokunma yüzeyi: görselin üstünde; başlık/rozet/kaydet bunun üstüne çizilir.
                Positioned.fill(
                  child: Semantics(
                    button: true,
                    label: (item['title'] as String?) ?? '',
                    excludeSemantics: true,
                    onTap: onTap,
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(onTap: onTap, child: const SizedBox.expand()),
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: 16,
                  end: 16,
                  bottom: 16,
                  child: IgnorePointer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text((item['title'] as String?) ?? '',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, height: 1.25, color: t.onMedia)),
                        const SizedBox(height: 8),
                        Text(newsDateLabel(context, item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tx.bodySmall!.copyWith(color: t.onMedia.withValues(alpha: .86))),
                      ],
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: 14,
                  top: 14,
                  child: IgnorePointer(child: IcerikBadge(newsTypeLabel(context, type), soft: tint == null, tint: tint)),
                ),
                if (onToggleSave != null)
                  PositionedDirectional(top: 4, end: 4, child: _SaveIcon(saved: saved, onTap: onToggleSave!, overlay: true)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Favori simgesi: görünür 22 dp, dokunma alanı 48x48 dp; ekran okuyucuya düğme olarak bildirilir.
/// Durum değişince simge ölçekle belirir (kısa "pop").
class _SaveIcon extends StatelessWidget {
  const _SaveIcon({required this.saved, required this.onTap, this.overlay = false});

  final bool saved;
  final VoidCallback onTap;
  final bool overlay;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final label = saved ? context.l10n.newsSaveRemove : context.l10n.newsSaveAdd;
    final fg = overlay ? (saved ? t.pr : t.onMedia) : (saved ? t.pr : t.mut.withValues(alpha: .8));
    final icon = Icon(
      saved ? Icons.bookmark : LucideIcons.bookmark,
      key: ValueKey(saved),
      size: 20,
      color: fg,
    );
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
          onTap: () {
            buHaptic(BuHaptic.selection);
            onTap();
          },
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: overlay ? 40 : 36,
                height: overlay ? 40 : 36,
                alignment: Alignment.center,
                decoration: overlay
                    ? BoxDecoration(shape: BoxShape.circle, color: saved ? t.sf : t.scrim.withValues(alpha: .42))
                    : null,
                child: AnimatedSwitcher(
                  duration: BuMotion.of(context, BuMotion.medium),
                  switchInCurve: Curves.easeOutBack,
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: icon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Görselsiz etkinlik karosu: nötr zemin, büyük gün + kısa ay ("18 KAS").
class _EventDateTile extends StatelessWidget {
  const _EventDateTile({required this.date, required this.size});

  final DateTime date;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final month = trUpper(newsMonthName(context, date.month)).characters.take(3).toString();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.sm)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${date.day}',
              maxLines: 1,
              style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w700, height: 1.1, color: t.ink, fontFeatures: const [FontFeature.tabularFigures()])),
          Text(month, maxLines: 1, style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w600, color: t.mut)),
        ]),
      ),
    );
  }
}
