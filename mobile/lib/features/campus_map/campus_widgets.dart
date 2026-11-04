import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale_controller.dart';
import 'campus_map_controller.dart';
import '../../widgets/bu.dart';
import 'campus_geo.dart';
import 'campus_models.dart';

/// Sunucudaki kategori simge adı (`categories[].icon`) -> uygulama simgesi. Bilinmeyen ad güvenle [BuIcons.mapPin]'e düşer.
/// Anahtarlar küçük harf, yalnız harf/rakam (tire/alt çizgi atılır): "graduation-cap" -> "graduationcap".
IconData campusIconFor(String name, {String fallbackKey = ''}) {
  final k = '$name $fallbackKey'.toLowerCase().replaceAll(RegExp('[^a-z0-9 ]'), '');
  bool has(List<String> w) => w.any(k.contains);
  if (has(['graduation', 'faculty', 'fakulte', 'school', 'university'])) return BuIcons.graduationCap;
  if (has(['library', 'kutuphane', 'book'])) return BuIcons.library;
  if (has(['utensil', 'restaurant', 'food', 'yemek', 'cafeteria', 'dining'])) return BuIcons.utensils;
  if (has(['coffee', 'cafe', 'kafe'])) return BuIcons.coffee;
  if (has(['door', 'gate', 'kapi', 'entrance'])) return BuIcons.doorOpen;
  if (has(['parking', 'otopark'])) return BuIcons.parking;
  if (has(['car', 'bus', 'shuttle'])) return BuIcons.car;
  if (has(['music', 'club', 'kulup', 'social', 'sosyal'])) return BuIcons.music;
  if (has(['flask', 'lab', 'science'])) return BuIcons.flaskConical;
  if (has(['dumbbell', 'sport', 'spor', 'gym', 'ball'])) return BuIcons.dumbbell;
  if (has(['landmark', 'admin', 'rektor', 'idari'])) return BuIcons.landmark;
  if (has(['building', 'bina'])) return BuIcons.building2;
  return BuIcons.mapPin;
}

/// Kategori iğne rengi: palet küçük tutulur (RENK-1), ayrım simge + etiketle yapılır; renk kategori sırasından türer.
Color campusPinColor(BuildContext context, int categoryIndex) {
  final t = context.bu;
  final c = [t.pr, t.info, t.ok, t.warn, t.aqua];
  return c[categoryIndex < 0 ? 0 : categoryIndex % c.length];
}

/// Kategorinin sırası (renk için); bilinmiyorsa 0.
int campusCategoryIndex(CampusMapConfig? c, String key) {
  final i = c?.categories.indexWhere((e) => e.key == key) ?? -1;
  return i < 0 ? 0 : i;
}

String campusLang(BuildContext context) => Localizations.localeOf(context).languageCode;

/// Yuvarlak kategori iğnesi: beyaz simge + beyaz halka. Seçili: büyük + dış halka.
class CampusPin extends StatelessWidget {
  const CampusPin({super.key, required this.icon, required this.color, this.selected = false, this.label});

  final IconData icon;
  final Color color;
  final bool selected;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final d = selected ? 46.0 : 36.0;
    final pin = Container(
      width: d,
      height: d,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? t.pr : color,
        shape: BoxShape.circle,
        border: Border.all(color: t.onMedia, width: selected ? 3 : 2.5),
        boxShadow: [BoxShadow(color: t.shadow.withValues(alpha: .35), blurRadius: selected ? 10 : 6, offset: const Offset(0, 2))],
      ),
      child: Icon(icon, size: selected ? 24 : 19, color: t.onMedia),
    );
    return Semantics(
      label: label,
      button: true,
      excludeSemantics: label != null,
      child: selected
          ? Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: t.pr.withValues(alpha: .22), shape: BoxShape.circle),
              child: pin,
            )
          : pin,
    );
  }
}

/// Küme iğnesi: sayı.
class CampusClusterPin extends StatelessWidget {
  const CampusClusterPin({super.key, required this.count, this.label});

  final int count;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      label: label,
      button: true,
      excludeSemantics: label != null,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.nav,
          shape: BoxShape.circle,
          border: Border.all(color: t.onMedia, width: 2.5),
          boxShadow: [BoxShadow(color: t.shadow.withValues(alpha: .35), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Text('$count', style: BuType.label.copyWith(color: t.onNav, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

/// Kullanıcı konumu: mavi nokta + beyaz halka; hareket yönü biliniyorsa yön konisi.
class CampusUserDot extends StatelessWidget {
  const CampusUserDot({super.key, this.heading});

  final double? heading;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      label: context.l10n.campusYouAreHere,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Stack(alignment: Alignment.center, children: [
          if (heading != null)
            Transform.rotate(
              angle: heading! * math.pi / 180,
              child: CustomPaint(size: const Size(56, 56), painter: _ConePainter(t.info.withValues(alpha: .35))),
            ),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: t.info,
              shape: BoxShape.circle,
              border: Border.all(color: t.onMedia, width: 3),
              boxShadow: [BoxShadow(color: t.shadow.withValues(alpha: .3), blurRadius: 5)],
            ),
          ),
        ]),
      ),
    );
  }
}

class _ConePainter extends CustomPainter {
  _ConePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final p = Paint()..color = color;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2 - .5, 1.0, true, p);
  }

  @override
  bool shouldRepaint(_ConePainter old) => old.color != color;
}

/// Ölçek çubuğu (haritanın çocuğu: [MapCamera] değişince kendiliğinden güncellenir).
class CampusScaleBar extends StatelessWidget {
  const CampusScaleBar({super.key});

  @override
  Widget build(BuildContext context) {
    final cam = MapCamera.of(context);
    final s = niceScale(metersPerPixel(cam.center.latitude, cam.zoom));
    final t = context.bu;
    final label = s.meters >= 1000 ? '${(s.meters / 1000).round()} km' : '${s.meters.round()} m';
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 4),
        decoration: BoxDecoration(color: t.sf.withValues(alpha: .88), borderRadius: BuRadius.bXs),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: s.px,
            height: 6,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: t.ink, width: 1.5),
                right: BorderSide(color: t.ink, width: 1.5),
                bottom: BorderSide(color: t.ink, width: 1.5),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: BuType.caption.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

/// Harita üstündeki zorunlu atıf (OSM lisansı): sunucu metni OSM değilse onu, değilse yerelleştirilmiş OSM metnini gösterir.
class CampusAttribution extends StatelessWidget {
  const CampusAttribution({super.key, required this.serverText});

  final String serverText;

  static const copyrightUrl = 'https://www.openstreetmap.org/copyright';

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final isOsm = serverText.trim().isEmpty || serverText.toLowerCase().contains('openstreetmap');
    final text = isOsm ? context.l10n.campusAttribution : serverText.trim();
    return Semantics(
      link: true,
      label: text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => launchUrl(Uri.parse(copyrightUrl), mode: LaunchMode.externalApplication).catchError((_) => false),
        child: Container(
          constraints: const BoxConstraints(minHeight: 24),
          padding: const EdgeInsetsDirectional.fromSTEB(8, 3, 8, 3),
          decoration: BoxDecoration(color: t.sf.withValues(alpha: .88), borderRadius: BuRadius.bXs),
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(color: t.mut)),
        ),
      ),
    );
  }
}

/// Harita sağ kenar düğmesi (yuvarlak, 48 dp).
class CampusMapButton extends StatelessWidget {
  const CampusMapButton({super.key, required this.icon, required this.tooltip, required this.onTap, this.active = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: BuElevation.of(context, 2)),
          child: Material(
            color: active ? t.soft : t.sf,
            shape: CircleBorder(side: BorderSide(color: active ? t.selectedBorder : t.bd)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                BuHaptics.selection();
                onTap();
              },
              child: SizedBox(width: 48, height: 48, child: Icon(icon, size: 22, color: active ? t.onSoft : t.ink)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Liste satırı (panel, kategori, arama): simge karosu + ad + kategori · mesafe + sağda eylem.
class CampusPlaceTile extends StatelessWidget {
  const CampusPlaceTile({
    super.key,
    required this.place,
    required this.icon,
    required this.categoryLabel,
    required this.onTap,
    this.distanceText,
    this.trailing,
    this.strongIcon = false,
    this.highlight,
    this.selected = false,
  });

  final CampusPlace place;
  final IconData icon;
  final String categoryLabel;
  final String? distanceText;
  final VoidCallback onTap;
  final Widget? trailing;

  /// Koyu simge karosu (kategori listesi tasarımı).
  final bool strongIcon;

  /// Arama vurgusu: ad içinde bu aralık kalın + marka rengi.
  final ({int start, int end})? highlight;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final base = tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w700);
    Widget title = Text(place.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: base);
    final h = highlight;
    if (h != null && h.end <= place.name.length && h.start < h.end) {
      title = Text.rich(
        TextSpan(style: base, children: [
          TextSpan(text: place.name.substring(0, h.start)),
          TextSpan(text: place.name.substring(h.start, h.end), style: base.copyWith(color: t.prText)),
          TextSpan(text: place.name.substring(h.end)),
        ]),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    return BuPressable(
      onTap: onTap,
      semanticLabel: '${place.name}, $categoryLabel${distanceText == null ? '' : ', $distanceText'}',
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: selected ? t.soft.withValues(alpha: .6) : t.sf,
          borderRadius: BuRadius.bMd,
          border: Border.all(color: selected ? t.selectedBorder : t.bd),
        ),
        child: Row(children: [
          ExcludeSemantics(
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: strongIcon ? t.nav : t.sf2, borderRadius: BuRadius.bSm),
              child: Icon(icon, size: 24, color: strongIcon ? t.onNav : t.ink),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              title,
              const SizedBox(height: 3),
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 2, children: [
                Text(categoryLabel, style: tx.bodySmall!.copyWith(color: t.mut)),
                if (distanceText != null) ...[
                  Icon(BuIcons.navigation, size: 14, color: t.info),
                  Text(distanceText!, style: tx.bodySmall!.copyWith(color: t.info, fontWeight: FontWeight.w600)),
                ],
              ]),
            ]),
          ),
          if (trailing != null) trailing!,
        ]),
      ),
    );
  }
}

/// Yürüyüş/yol tarifi düğmesi (satır sonu).
class CampusWalkButton extends StatelessWidget {
  const CampusWalkButton({super.key, required this.tooltip, required this.onTap});

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        onTap: onTap,
        child: InkResponse(
          onTap: onTap,
          radius: 26,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: t.infoSoft, borderRadius: BuRadius.bSm),
                child: Icon(BuIcons.footprints, size: 20, color: t.onInfoSoft),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bilgi satırı (Konum / Birimler / Yürüyerek süre): ikon karosu + küçük etiket + değer.
class CampusInfoRow extends StatelessWidget {
  const CampusInfoRow({super.key, required this.icon, required this.label, required this.value, this.tint = 0, this.onTap});

  final IconData icon;
  final String label;
  final String value;
  final int tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final c = t.tint(tint);
    final row = Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 14, 10),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bMd),
      child: Row(children: [
        ExcludeSemantics(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.bg, borderRadius: BuRadius.bSm),
            child: Icon(icon, size: 20, color: c.fg),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(trUpper(label), style: tx.labelSmall!.copyWith(color: t.mut, letterSpacing: .6, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
    return onTap == null ? row : BuPressable(onTap: onTap, child: row);
  }
}

/// "Diğer yerleşkeler" bölümü (ana yerleşke dışındaki birimler): başlık + satırlar. Haritada iğne YOK; dokununca detay.
List<Widget> campusRemoteSection(BuildContext context, CampusMapController ctl, List<CampusPlace> remotes, ValueChanged<CampusPlace> onOpen) {
  if (remotes.isEmpty) return const [];
  final t = context.bu;
  final l = context.l10n;
  final tx = Theme.of(context).textTheme;
  return [
    Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 0, 8),
      child: Row(children: [
        Icon(BuIcons.mapPin, size: 16, color: t.mut),
        const SizedBox(width: 6),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(trUpper(l.campusOtherCampuses), style: tx.labelMedium!.copyWith(color: t.mut, letterSpacing: .8, fontWeight: FontWeight.w800)),
          ),
        ),
        Padding(padding: const EdgeInsetsDirectional.only(end: 4), child: Text(l.campusResultCount('${remotes.length}'), style: tx.labelMedium!.copyWith(color: t.mut))),
      ]),
    ),
    for (final p in remotes)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: CampusPlaceTile(
          place: p,
          icon: campusIconFor(ctl.categoryOf(p)?.icon ?? '', fallbackKey: p.category),
          categoryLabel: ctl.categoryOf(p)?.label ?? '',
          onTap: () => onOpen(p),
          trailing: Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: Icon(buDirIcon(context, BuIcons.chevronRight), size: 20, color: t.mut)),
        ),
      ),
  ];
}
