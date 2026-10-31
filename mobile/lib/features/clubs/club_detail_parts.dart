import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart';
import 'clubs_widgets.dart' show ClubTextTabs, ClubsLogo, clubsInitials;

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
    this.size = BuSize.iconBtn,
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

/// Düz kapak (Stitch v3): fotoğraf yoksa `sf2` zemin + çok silik büyük baş harf filigranı; fotoğraf varsa aynı alanı
/// doldurur (üstte düğme kontrastı için hafif karartma). Gölge/gradyan/logo yok. Genişleyen app bar'ın esnek alanıdır.
/// Fotoğraf kaydırmanın %60'ı hızında çıkar (paralaks, yalnız transform; "animasyonları azalt" açıkken yok).
class ClubFlatCover extends StatelessWidget {
  const ClubFlatCover({super.key, required this.url, required this.name, required this.height});

  final String? url;
  final String name;

  /// Kapak yüksekliği (durum çubuğu hariç).
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final top = MediaQuery.paddingOf(context).top;
    final maxH = top + height;
    final cover = fileUrl(url);
    return LayoutBuilder(
      builder: (context, c) {
        final delta = (maxH - c.maxHeight).clamp(0.0, maxH);
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: t.sf2),
              if (cover == null)
                // Filigran: ~96 sp / 800, opaklık ~0.08.
                Align(
                  alignment: const Alignment(0, -.05),
                  child: ExcludeSemantics(
                    child: Text(clubsInitials(name),
                        maxLines: 1,
                        style: TextStyle(fontFamily: BuType.family, fontSize: 88, fontWeight: FontWeight.w800, height: 1, color: t.ink.withValues(alpha: .08))),
                  ),
                )
              else ...[
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: maxH,
                  child: Transform.translate(
                    offset: Offset(0, BuMotion.reduced(context) ? 0 : delta * .4),
                    child: BuImage(url, width: double.infinity, height: maxH, maxDecodeWidth: 1200),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 96,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [t.scrim.withValues(alpha: .38), t.scrim.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
              ],
              // Daralırken zemin rengine erir.
              Positioned.fill(child: IgnorePointer(child: ColoredBox(color: t.bg.withValues(alpha: (delta / (maxH - kToolbarHeight - top).clamp(1.0, double.infinity)).clamp(0.0, 1.0))))),
            ],
          ),
        );
      },
    );
  }
}

/// Üst çubuk düğmesi (geri oku, üç nokta): zeminsiz 24 dp simge, 48 dp dokunma alanı.
class ClubBarIcon extends StatelessWidget {
  const ClubBarIcon({super.key, required this.icon, required this.tooltip, required this.onTap, this.color, this.width = 48});

  final double width;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: tooltip,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: BuPressable(
          scale: .9,
          enabled: onTap != null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap == null
                ? null
                : () {
                    buHaptic(BuHaptic.selection);
                    onTap!();
                  },
            child: SizedBox(width: width, height: 48, child: Icon(buDirIcon(context, icon), size: 24, color: color ?? t.ink)),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Sekmeler

/// Sabitlenen metin sekmeleri (Stitch v3): kaydırınca app bar'ın altında kalır; seçili = marka metni + 2 dp alt çizgi.
class ClubTabsDelegate extends SliverPersistentHeaderDelegate {
  ClubTabsDelegate({required this.labels, required this.index, required this.onChanged, required this.brightness});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  /// Tema parlaklığı: sliver başlığı yalnız yerleşimde kurulur, tema değişince kendiliğinden yenilenmez;
  /// [shouldRebuild] bunu karşılaştırır (açık/koyu geçişte şerit zemini eski temada kalmasın).
  final Brightness brightness;

  static const double extent = ClubTextTabs.height;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final t = context.bu;
    return ColoredBox(
      color: t.bg,
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: ClubTextTabs(labels: labels, index: index, onChanged: onChanged),
      ),
    );
  }

  @override
  bool shouldRebuild(ClubTabsDelegate old) =>
      old.index != index || old.brightness != brightness || !_same(old.labels, labels);

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
    final style = tx.bodyMedium!.copyWith(height: 1.65, color: t.ink, fontWeight: FontWeight.w400);
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
                  constraints: const BoxConstraints(minHeight: 40),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: 1,
                    child: Text(_open ? l.p11ReadLess : l.p11ReadMore, style: tx.bodyMedium!.copyWith(color: t.pr, fontWeight: FontWeight.w700)),
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

/// Bekleyen başvuru özeti (yönetici): amber not satırı (`warnSoft`, 16 dp köşe, ikon yok), sağda chevron.
class ClubRequestsBanner extends StatelessWidget {
  const ClubRequestsBanner({super.key, required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: text,
      excludeSemantics: true,
      onTap: onTap,
      child: BuPressable(
        scale: .985,
        child: Material(
          color: t.warnSoft,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              buHaptic(BuHaptic.selection);
              onTap();
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 10),
                child: Row(
                  children: [
                    Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(color: t.onWarnSoft, fontWeight: FontWeight.w600))),
                    const SizedBox(width: 8),
                    ExcludeSemantics(child: Icon(buDirIcon(context, LucideIcons.chevronRight), size: 20, color: t.onWarnSoft)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Hakkında" etiket-değer satırı: etiket muted solda, değer ink sağda; altında ince ayraç (48 dp).
class ClubAboutRow extends StatelessWidget {
  const ClubAboutRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.bd))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: tx.bodyLarge!.copyWith(color: t.mut, fontWeight: FontWeight.w400)),
          const SizedBox(width: 16),
          Expanded(child: Text(value, textAlign: TextAlign.end, style: tx.bodyLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

/// Üye satırı (detay "Üyeler" sekmesi, Stitch v3): 40 dp baş harf dairesi, ad 16/600, altında muted rol,
/// sağda (yalnız yönetici) dikey üç nokta; altında ince ayraç.
class ClubMemberRow extends StatelessWidget {
  const ClubMemberRow({super.key, required this.member, this.onMenu});

  final Map<String, dynamic> member;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final name = (member['displayName'] ?? l.clubUser).toString();
    final role = member['role']?.toString();
    final roleText = switch (role) {
      'OWNER' || 'ADMIN' => l.clubMgmtRoleManager,
      'MODERATOR' => l.clubMgmtRoleModerator,
      _ => l.p51RoleMember,
    };
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(0, 14, 0, 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.bd))),
      child: Row(
        children: [
          ClubsLogo(name: name, id: (member['userId'] as num?)?.toInt() ?? 0, url: member['avatarUrl']?.toString(), size: 44),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodyLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
                Text(roleText, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut, fontSize: 13)),
              ],
            ),
          ),
          if (onMenu != null) ClubBarIcon(icon: LucideIcons.ellipsisVertical, tooltip: l.clubMgmtMemberActions, onTap: onMenu, color: t.ink, width: 40),
        ],
      ),
    );
  }
}
