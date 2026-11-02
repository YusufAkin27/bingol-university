import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/analytics.dart';
import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'campus_geo.dart';
import 'campus_map_controller.dart';
import 'campus_map_view.dart';
import 'campus_models.dart';
import 'campus_nav.dart';
import 'campus_widgets.dart';

/// Yer detayı (Stitch "Harita - Yer detayı"): üstte küçük harita (bina izi + iğne), altında fotoğraf, kategori, ad + favori kalbi,
/// Konum / Birimler / Yürüyerek süre, "Yol tarifi", "Haritada aç", "Paylaş". Favori YEREL kalır (sunucuya gitmez).
class CampusPlacePage extends StatefulWidget {
  const CampusPlacePage({super.key, required this.controller, required this.place, this.tileProvider});

  final CampusMapController controller;
  final CampusPlace place;
  final TileProvider? tileProvider;

  @override
  State<CampusPlacePage> createState() => _CampusPlacePageState();
}

class _CampusPlacePageState extends State<CampusPlacePage> {
  final _map = MapController();

  @override
  void initState() {
    super.initState();
    // Kullanım istatistiği: yalnız kategori (yer adı/kimliği/konum gönderilmez).
    Analytics.instance.track('map_place_open', props: {'kind': campusKindLabel(widget.place.category)});
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final ctl = widget.controller;
    final p = widget.place;
    final cfg = ctl.config;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: ctl,
          builder: (context, _) {
            final cat = ctl.categoryOf(p);
            final d = ctl.distanceTo(p);
            final lang = campusLang(context);
            final fav = ctl.isFavorite(p.id);
            final remote = ctl.isRemote(p);
            final showMap = cfg != null && !remote;
            return Column(children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 8),
                child: Row(children: [
                  BuIconButton(icon: BuIcons.arrowLeft, tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: () => Navigator.of(context).maybePop()),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(l.campusDetailTitle, textAlign: TextAlign.center, style: tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 44),
                ]),
              ),
              Expanded(
                child: Stack(children: [
                  if (showMap)
                    PositionedDirectional(
                      top: 0,
                      start: 0,
                      end: 0,
                      height: 280,
                      child: CampusMapView(
                        controller: ctl,
                        mapController: _map,
                        config: cfg,
                        interactive: false,
                        showScale: false,
                        focus: p,
                        initialCenter: p.point,
                        initialZoom: (cfg.maxZoom < 18 ? cfg.maxZoom : 18),
                        tileProvider: widget.tileProvider,
                        onPlaceTap: (_) {},
                        onClusterTap: (_) {},
                        onBackgroundTap: () {},
                      ),
                    ),
                  ListView(
                    padding: EdgeInsets.only(top: showMap ? 230 : 8),
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                        decoration: BoxDecoration(
                          color: t.sf,
                          borderRadius: BuRadius.topXl,
                          border: Border.all(color: t.bd),
                          boxShadow: BuElevation.of(context, 3),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: t.bdStrong.withValues(alpha: .5), borderRadius: BuRadius.bPill))),
                          const SizedBox(height: 14),
                          _photo(context, cat),
                          const SizedBox(height: 14),
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Expanded(
                              child: Semantics(
                                header: true,
                                child: Text(p.name, style: tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w800, height: 1.2)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            BuPop(
                              trigger: fav,
                              child: BuIconButton(
                                icon: fav ? BuIcons.heartFilled : BuIcons.heart,
                                tooltip: fav ? l.campusFavRemove : l.campusFavAdd,
                                filled: fav,
                                onTap: () {
                                  BuHaptics.light();
                                  unawaited(ctl.toggleFavorite(p.id));
                                },
                              ),
                            ),
                          ]),
                          if (p.summary.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(p.summary, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5)),
                          ],
                          const SizedBox(height: 14),
                          CampusInfoRow(icon: BuIcons.mapPin, label: l.campusLocationLabel, value: remote ? l.campusOtherCampuses : l.campusMainCampus, tint: BuTintId.slate),
                          if (p.units.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            CampusInfoRow(icon: BuIcons.building2, label: l.campusUnits, value: p.units.join(', '), tint: BuTintId.blue),
                          ],
                          if (!remote) ...[
                          const SizedBox(height: 8),
                          CampusInfoRow(
                            icon: BuIcons.footprints,
                            label: l.campusWalkTime,
                            value: d == null ? l.campusWalkUnknown : l.campusWalkValue('${walkMinutes(d)}', formatDistance(d, lang: lang)),
                            tint: BuTintId.brand,
                            onTap: d == null ? () => unawaited(ctl.requestLocation()) : null,
                          ),
                          ],
                          if (p.webUrl != null) _WebLink(url: p.webUrl!, label: l.campusUnitPage),
                          const SizedBox(height: 16),
                          BuButton(label: l.campusDirections, icon: BuIcons.cornerUpRight, onPressed: () => unawaited(openDirections(context, p))),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(child: BuButton(label: l.campusOpenInMaps, icon: BuIcons.map, kind: BuButtonKind.soft, onPressed: () => unawaited(openPlaceInMaps(context, p)))),
                            const SizedBox(width: 8),
                            Expanded(child: BuButton(label: l.campusShare, icon: BuIcons.share2, kind: BuButtonKind.soft, onPressed: () => unawaited(sharePlace(context, p)))),
                          ]),
                          const SizedBox(height: 12),
                          Text(l.campusDistanceNote, textAlign: TextAlign.center, style: tx.bodySmall!.copyWith(color: t.mut)),
                        ]),
                      ),
                    ],
                  ),
                ]),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _photo(BuildContext context, CampusCategory? cat) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final p = widget.place;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(fit: StackFit.expand, children: [
        BuImage(fileUrl(p.photoUrl), radius: 20, semanticLabel: p.name, placeholderIcon: campusIconFor(cat?.icon ?? '', fallbackKey: p.category)),
        if (cat != null)
          PositionedDirectional(
            start: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsetsDirectional.fromSTEB(10, 5, 12, 5),
              decoration: BoxDecoration(color: t.sf.withValues(alpha: .94), borderRadius: BuRadius.bPill),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(cat.label, style: tx.labelMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Birim sayfası bağlantısı: küçük metin bağlantısı (tasarım dilini bozmaz); dış tarayıcıda açılır.
class _WebLink extends StatelessWidget {
  const _WebLink({required this.url, required this.label});

  final Uri url;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        link: true,
        label: '$label, ${url.host}',
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BuRadius.bSm,
          onTap: () => unawaited(launchUrl(url, mode: LaunchMode.externalApplication).then((_) {}, onError: (_) {})),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(BuIcons.squareArrowOutUpRight, size: 16, color: t.info),
                const SizedBox(width: 8),
                Flexible(
                  child: Text('$label · ${url.host}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelLarge!.copyWith(color: t.info, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, decorationColor: t.info)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
