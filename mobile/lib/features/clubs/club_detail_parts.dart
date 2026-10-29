import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart';

export 'club_detail_cards.dart';

/// Kulüp detay sayfasının görsel parçaları (P11): kapak, yuvarlak düğme, sekme başlığı, kartlar, yazma kutusu.

// ---------------------------------------------------------------------------------------------------------------
// Düğme

/// Yuvarlak simge düğmesi (kapak üstü ya da sayfa içi). Görsel 44 dp, dokunma alanı 48 dp.
/// [onCover] true: fotoğraf üstünde koyu saydam zemin; [filled]: marka dolgusu; pasifken (onTap null) soluk.
class ClubRoundButton extends StatelessWidget {
  const ClubRoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.onCover = false,
    this.filled = false,
    this.plain = false,
    this.size = 44,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool onCover;
  final bool filled;

  /// Çerçevesiz, zeminsiz (liste satırı sonundaki ⋯ düğmesi).
  final bool plain;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final enabled = onTap != null;
    final Color bg;
    final Color fg;
    BorderSide side = BorderSide.none;
    if (filled) {
      bg = enabled ? t.pr : t.sf2;
      fg = enabled ? t.onPr : t.mut.withValues(alpha: .6);
    } else if (plain) {
      bg = t.sf.withValues(alpha: 0);
      fg = enabled ? t.mut : t.mut.withValues(alpha: .5);
    } else if (onCover) {
      bg = t.scrim.withValues(alpha: .38);
      fg = t.onMedia;
    } else {
      bg = t.sf;
      fg = enabled ? t.ink : t.mut.withValues(alpha: .6);
      side = BorderSide(color: t.bd);
    }
    final hit = size < 48 ? 48.0 : size;
    void tap() {
      buHaptic(BuHaptic.selection);
      onTap!();
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: BuPressable(
          scale: .92,
          enabled: enabled,
          child: SizedBox(
            width: hit,
            height: hit,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (enabled)
                  ExcludeSemantics(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: tap, child: SizedBox(width: hit, height: hit))),
                Material(
                  color: bg,
                  shape: CircleBorder(side: side),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: enabled ? tap : null,
                    child: SizedBox(width: size, height: size, child: Icon(buDirIcon(context, icon), size: size * .45, color: fg)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Kapak

/// Kapağın altında logonun yarısını taşıyan şerit yüksekliği (logo 88 dp: 44 kapağın üstünde, 44 şeritte).
const double kClubCoverBand = 44;

/// Genişleyen app bar'ın esnek alanı: kapak fotoğrafı (yoksa marka gradyanı + desen), üstte düğme kontrastı için
/// karartma, kapakla çakışan [logo] ve şeritte [trailing]. Daralırken içerik yukarı kayar, sayfa zeminine solar
/// (saydam renk katmanı, `Opacity` yok). Sliver'lar ters sırayla boyandığı için logo burada (app bar içinde) durur.
class ClubCoverSpace extends StatelessWidget {
  const ClubCoverSpace({
    super.key,
    required this.url,
    required this.coverHeight,
    required this.seed,
    required this.logo,
    this.trailing,
  });

  final String? url;

  /// Kapak yüksekliği (durum çubuğu hariç); toplam açık yükseklik = bu + [kClubCoverBand].
  final double coverHeight;
  final int seed;
  final Widget logo;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final top = MediaQuery.paddingOf(context).top;
    final coverH = top + coverHeight;
    final maxH = coverH + kClubCoverBand;
    final minH = top + kToolbarHeight;
    final cover = fileUrl(url);
    return LayoutBuilder(
      builder: (context, c) {
        final p = maxH <= minH ? 1.0 : ((c.maxHeight - minH) / (maxH - minH)).clamp(0.0, 1.0);
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: kClubCoverBand,
                height: coverH,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(BuRadius.xl)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      cover == null
                          ? ExcludeSemantics(
                              child: BuGradientHero(
                                radius: 0,
                                pattern: seed.isEven ? BuHeroPattern.rings : BuHeroPattern.waves,
                                child: const SizedBox.expand(),
                              ),
                            )
                          : BuImage(url, width: double.infinity, height: coverH, maxDecodeWidth: 1200),
                      if (cover != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          height: 112,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [t.scrim.withValues(alpha: .42), t.scrim.withValues(alpha: 0)],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              PositionedDirectional(start: 20, bottom: 0, child: logo),
              if (trailing != null) PositionedDirectional(end: 20, bottom: 4, child: trailing!),
              // Daralırken zemin rengine erir.
              Positioned.fill(child: IgnorePointer(child: ColoredBox(color: t.bg.withValues(alpha: 1 - p)))),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Sekmeler

/// Sabitlenen sekme çubuğu (BuSegmented): kaydırınca app bar'ın altında kalır, çakışınca ince çizgi çıkar.
class ClubTabsDelegate extends SliverPersistentHeaderDelegate {
  ClubTabsDelegate({required this.labels, required this.index, required this.onChanged});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  static const double extent = 68;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final t = context.bu;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(bottom: BorderSide(color: overlapsContent ? t.bd : t.bg)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 8),
        // Büyük yazı ölçeğinde sekme adları birbirine yapışmasın: ölçek 1.1'de sınırlanır.
        child: MediaQuery.withClampedTextScaling(maxScaleFactor: 1.1, child: BuSegmented(items: labels, index: index, onChanged: onChanged)),
      ),
    );
  }

  @override
  bool shouldRebuild(ClubTabsDelegate old) => old.index != index || !_same(old.labels, labels);

  static bool _same(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Açıklama

/// Üç satıra kısaltılan açıklama; taşıyorsa "Devamını göster / Daha az göster".
class ClubExpandableText extends StatefulWidget {
  const ClubExpandableText(this.text, {super.key, this.maxLines = 3});

  final String text;
  final int maxLines;

  @override
  State<ClubExpandableText> createState() => _ClubExpandableTextState();
}

class _ClubExpandableTextState extends State<ClubExpandableText> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final style = tx.bodyLarge!.copyWith(height: 1.5, color: t.ink);
    final l = context.l10n;
    return LayoutBuilder(
      builder: (context, c) {
        final tp = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: widget.maxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: c.maxWidth);
        final overflow = tp.didExceedMaxLines;
        tp.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: BuMotion.of(context, BuMotion.medium),
              curve: BuMotion.emphasized,
              alignment: AlignmentDirectional.topStart,
              child: Text(widget.text,
                  maxLines: _open ? null : widget.maxLines, overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis, style: style),
            ),
            if (overflow)
              InkWell(
                borderRadius: BuRadius.bXs,
                onTap: () => setState(() => _open = !_open),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: 1,
                    child: Text(_open ? l.p11ReadLess : l.p11ReadMore, style: tx.labelLarge!.copyWith(color: t.pr, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Kartlar

/// Etkinlik kartı: tarih karosu (gün + ay), başlık, saat, yer.
class ClubEventCard extends StatelessWidget {
  const ClubEventCard({super.key, required this.event, this.onTap});

  final Map<String, dynamic> event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final e = event;
    final id = (e['id'] as num?)?.toInt() ?? 0;
    final d = DateTime.tryParse((e['startsAt'] ?? '').toString())?.toLocal();
    final tint = t.tint(id);
    final months = [
      l.commonMonth1, l.commonMonth2, l.commonMonth3, l.commonMonth4, l.commonMonth5, l.commonMonth6,
      l.commonMonth7, l.commonMonth8, l.commonMonth9, l.commonMonth10, l.commonMonth11, l.commonMonth12,
    ];
    String two(int n) => n.toString().padLeft(2, '0');
    final when = d == null ? niceDate(e['startsAt']?.toString(), context: context) : '${longDate(d, context: context)} · ${two(d.hour)}:${two(d.minute)}';
    final place = (e['location'] ?? '').toString();
    return BuCard(
      onTap: onTap,
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 14, 12),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 56,
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(color: tint.bg, borderRadius: BuRadius.bMd),
              child: d == null
                  ? Icon(LucideIcons.calendar, color: tint.fg, size: 24)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('${d.day}', style: tx.titleLarge!.copyWith(color: tint.fg, fontWeight: FontWeight.w800, height: 1.1)),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(months[d.month - 1], maxLines: 1, style: tx.labelSmall!.copyWith(color: tint.fg, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((e['title'] ?? '').toString(),
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(color: t.ink)),
                const SizedBox(height: 6),
                _MetaLine(icon: LucideIcons.clock, text: when),
                if (place.isNotEmpty) ...[const SizedBox(height: 2), _MetaLine(icon: LucideIcons.mapPin, text: place)],
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            ExcludeSemantics(child: Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.mut)),
          ],
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Row(
      children: [
        ExcludeSemantics(child: Icon(icon, size: 14, color: t.mut)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: t.mut)),
        ),
      ],
    );
  }
}

/// Bekleyen başvuru özeti (yönetici): tonal kart, sayı + ok.
class ClubRequestsBanner extends StatelessWidget {
  const ClubRequestsBanner({super.key, required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return BuCard(
      onTap: onTap,
      color: t.warnSoft,
      border: false,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: t.warn.withValues(alpha: .18), borderRadius: BuRadius.bSm),
              child: Icon(LucideIcons.userPlus, size: 20, color: t.warn),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(color: t.onWarnSoft, fontWeight: FontWeight.w700)),
          ),
          ExcludeSemantics(child: Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.onWarnSoft)),
        ],
      ),
    );
  }
}
