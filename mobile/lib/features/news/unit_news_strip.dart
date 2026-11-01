import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import '../home/home_parts.dart';
import 'news_tile.dart' show newsLocalDate;
import 'unit_news_models.dart';

/// Ana Sayfa "Bölümümden" şeridi: başlık + yatay kaydırılan kartlar.
///
/// Sessizlik kuralı (kullanıcı kararı): [items] boşsa hiçbir şey çizilmez (başlık, boşluk, yer tutucu YOK).
/// Ana sayfa listeye ancak veri dolu gelince ekler; bu bileşen yine de boş listede [SizedBox.shrink] döner.
class UnitNewsSection extends StatelessWidget {
  const UnitNewsSection({super.key, required this.items, required this.onOpen});

  final List<UnitNewsItem> items;
  final void Function(UnitNewsItem item) onOpen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    return Column(
      key: const ValueKey('unit-news-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: HomeSectionHeader(title: context.l10n.unitNewsTitle),
        ),
        HomeNewsStrip(
          height: UnitNewsCard.heightFor(scale),
          itemExtent: UnitNewsCard.cardWidth,
          itemCount: items.length,
          itemBuilder: (context, i) => UnitNewsCard(item: items[i], onTap: () => onOpen(items[i])),
        ),
      ],
    );
  }
}

/// Şerit kartı: başlık (2 satır), kaynak/birim adı (+ ek varsa küçük dosya simgesi), tarih. Tümü dokunulur.
class UnitNewsCard extends StatelessWidget {
  const UnitNewsCard({super.key, required this.item, required this.onTap});

  static const cardWidth = 240.0;

  static const _titleBox = 37.0; // 14 sp x 1,3 x 2 satır
  static const _lineBox = 16.0; // 12 sp metin satırı
  static const _fixed = 12 + 8 + 4 + 12.0; // iç üst + başlık-kaynak + kaynak-tarih + iç alt
  static const _maxScale = 1.5;

  /// Kartın (çerçeve dahil) yüksekliği; [scale] sistem yazı ölçeği (en çok 1,5 hesaba katılır).
  static double heightFor(double scale) => _fixed + (_titleBox + _lineBox * 2) * scale.clamp(1.0, _maxScale) + 2;

  final UnitNewsItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final source = item.sourceLabel;
    final hasFiles = item.attachments.isNotEmpty;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxScale,
      child: Builder(builder: (context) {
        final scaler = MediaQuery.textScalerOf(context);
        return SizedBox(
          width: cardWidth,
          child: HomeSurface(
            onTap: onTap,
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                height: scaler.scale(_titleBox),
                child: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.body.copyWith(fontWeight: FontWeight.w500, height: 1.3, color: t.ink)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: scaler.scale(_lineBox),
                child: Row(children: [
                  Expanded(
                    child: Text(source ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(fontSize: 12, color: t.mut)),
                  ),
                  if (hasFiles)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 6),
                      child: Semantics(
                        label: l.unitNewsHasAttachments,
                        child: ExcludeSemantics(child: Icon(BuIcons.fileText, key: const ValueKey('unit-news-attach'), size: 16, color: t.mut)),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 4),
              Text(newsLocalDate(context, item.publishedDate), maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(fontSize: 12, color: t.mut)),
            ]),
          ),
        );
      }),
    );
  }
}
