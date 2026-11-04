import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'campus_geo.dart';
import 'campus_map_controller.dart';
import 'campus_models.dart';
import 'campus_widgets.dart';

/// Paket adı: karo sunucularına gönderilen User-Agent'ın parçası (OSM karo politikası: kimlikli UA).
const campusUserAgentPackage = 'tr.com.bukampus.app';

/// Koyu temada karoların üstüne uygulanan renk filtresi (sunucu koyu stil vermiyorsa): ters çevir + hafif soğut + kıs.
const ColorFilter campusDarkTileFilter = ColorFilter.matrix(<double>[
  -0.62, 0, 0, 0, 198, //
  0, -0.64, 0, 0, 204, //
  0, 0, -0.70, 0, 216, //
  0, 0, 0, 1, 0,
]);

/// Yer iğnelerine dokunma geri çağrıları + seçili yer.
typedef CampusPlaceCallback = void Function(CampusPlace p);
typedef CampusClusterCallback = void Function(CampusCluster c);

/// Harita gövdesi: karolar, kampüs maskesi + kesikli sınır, bina izi, iğneler/kümeler, kullanıcı konumu, ölçek, atıf.
/// Ekran (denetleyici/durum) bağımlılığı yalnız [controller] üzerindendir.
class CampusMapView extends StatelessWidget {
  const CampusMapView({
    super.key,
    required this.controller,
    required this.mapController,
    required this.config,
    required this.onPlaceTap,
    required this.onClusterTap,
    required this.onBackgroundTap,
    this.satellite = false,
    this.interactive = true,
    this.showScale = true,
    this.bottomInset,
    this.tileProvider,
    this.places,
    this.initialCenter,
    this.initialZoom,
    this.focus,
    this.showSelection = true,
  });

  final CampusMapController controller;
  final MapController mapController;
  final CampusMapConfig config;
  final CampusPlaceCallback onPlaceTap;
  final CampusClusterCallback onClusterTap;
  final VoidCallback onBackgroundTap;
  final bool satellite;
  final bool interactive;
  final bool showScale;

  /// Alt panelin kapladığı yükseklik: ölçek çubuğu/atıf panelin üstünde kalır.
  final ValueListenable<double>? bottomInset;

  /// Yalnız test: ağ yerine sahte karo sağlayıcı.
  final TileProvider? tileProvider;

  /// null ise denetleyicinin süzülmüş yerleri.
  final List<CampusPlace>? places;
  final LatLng? initialCenter;
  final double? initialZoom;

  /// Verilirse (yer detayı küçük haritası) yalnız bu yer, seçili biçimde çizilir.
  final CampusPlace? focus;

  /// false: denetleyicideki seçili yer bu haritada vurgulanmaz (kategori listesi küçük haritası).
  final bool showSelection;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tiles = (satellite && config.satelliteTiles != null) ? config.satelliteTiles! : config.tiles;
    final b = config.bounds;
    final shown = places ?? (focus != null ? [focus!] : controller.filtered);

    Widget tileLayer = TileLayer(
      urlTemplate: tiles.urlTemplate,
      subdomains: const ['a', 'b', 'c'],
      userAgentPackageName: campusUserAgentPackage,
      maxNativeZoom: tiles.maxNativeZoom,
      maxZoom: config.maxZoom,
      tileProvider: tileProvider,
      errorTileCallback: (tile, error, stack) => controller.noteTileError(),
    );
    // Sunucu ayrı bir koyu karo stili vermediği için koyu temada filtre uygulanır (uydu karosuna uygulanmaz).
    if (dark && !(satellite && config.satelliteTiles != null)) {
      tileLayer = ColorFiltered(colorFilter: campusDarkTileFilter, child: tileLayer);
    }

    final outer = <LatLng>[
      LatLng((b.south - 5).clamp(-85, 85).toDouble(), (b.west - 5).clamp(-180, 180).toDouble()),
      LatLng((b.south - 5).clamp(-85, 85).toDouble(), (b.east + 5).clamp(-180, 180).toDouble()),
      LatLng((b.north + 5).clamp(-85, 85).toDouble(), (b.east + 5).clamp(-180, 180).toDouble()),
      LatLng((b.north + 5).clamp(-85, 85).toDouble(), (b.west - 5).clamp(-180, 180).toDouble()),
    ];
    final ring = config.boundary.length >= 3
        ? config.boundary
        : [LatLng(b.south, b.west), LatLng(b.south, b.east), LatLng(b.north, b.east), LatLng(b.north, b.west)];

    final sel = focus ?? (showSelection ? controller.selected : null);
    final fix = controller.fix;

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: initialCenter ?? config.center,
        initialZoom: initialZoom ?? config.initialZoom,
        minZoom: config.minZoom,
        maxZoom: config.maxZoom,
        // Kamera kampüs sınır kutusunun dışına çıkamaz.
        cameraConstraint: CameraConstraint.contain(bounds: LatLngBounds(LatLng(b.south, b.west), LatLng(b.north, b.east))),
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none,
        ),
        backgroundColor: t.sf2,
        onTap: (_, __) => onBackgroundTap(),
      ),
      children: [
        tileLayer,
        // Dışarısı soluk (maske) + kırmızı kesikli kampüs sınırı.
        PolygonLayer(polygons: [
          Polygon(
            points: outer,
            holePointsList: [ring],
            color: (dark ? t.scrim : t.ink).withValues(alpha: dark ? .38 : .16),
            disableHolesBorder: true,
          ),
        ]),
        PolygonLayer(polygons: [
          Polygon(
            points: ring,
            borderColor: t.pr,
            borderStrokeWidth: 2.4,
            pattern: StrokePattern.dashed(segments: const [9, 7]),
          ),
        ]),
        if (sel?.footprint != null)
          PolygonLayer(polygons: [
            Polygon(points: sel!.footprint!, color: t.pr.withValues(alpha: .20), borderColor: t.pr, borderStrokeWidth: 2.4),
          ]),
        if (fix != null && fix.accuracy > 0)
          CircleLayer(circles: [
            CircleMarker(
              point: fix.point,
              radius: fix.accuracy.clamp(5, 200).toDouble(),
              useRadiusInMeter: true,
              color: t.info.withValues(alpha: .12),
              borderColor: t.info.withValues(alpha: .4),
              borderStrokeWidth: 1,
            ),
          ]),
        _PinsLayer(
          controller: controller,
          config: config,
          places: shown,
          selectedId: focus?.id ?? (showSelection ? controller.selectedId : null),
          onPlaceTap: onPlaceTap,
          onClusterTap: onClusterTap,
        ),
        if (fix != null)
          MarkerLayer(markers: [
            Marker(point: fix.point, width: 56, height: 56, child: CampusUserDot(heading: fix.heading)),
          ]),
        ValueListenableBuilder<double>(
            valueListenable: bottomInset ?? const AlwaysStoppedAnimation<double>(0),
            builder: (context, inset, _) => Align(
              alignment: AlignmentDirectional.bottomStart,
              child: Padding(
                padding: EdgeInsetsDirectional.only(start: 10, bottom: inset + 8),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (showScale) ...[const CampusScaleBar(), const SizedBox(height: 4)],
                  CampusAttribution(serverText: tiles.attribution),
                ]),
              ),
            ),
          ),
      ],
    );
  }
}

/// İğneler + kümeler. [MapCamera] değişince (yakınlaştırma/kaydırma) yeniden kümelenir.
class _PinsLayer extends StatelessWidget {
  const _PinsLayer({
    required this.controller,
    required this.config,
    required this.places,
    required this.selectedId,
    required this.onPlaceTap,
    required this.onClusterTap,
  });

  final CampusMapController controller;
  final CampusMapConfig config;
  final List<CampusPlace> places;
  final int? selectedId;
  final CampusPlaceCallback onPlaceTap;
  final CampusClusterCallback onClusterTap;

  /// Bu yakınlaştırmanın üstünde kümeleme yapılmaz (her yer ayrı iğne).
  static const clusterBelowZoom = 17.0;

  @override
  Widget build(BuildContext context) {
    final cam = MapCamera.of(context);
    final l = context.l10n;
    final clusters = cam.zoom >= clusterBelowZoom
        ? [for (final p in places) CampusCluster([p], p.point)]
        : clusterPlaces(places, cam.projectAtZoom, cellPx: 52, keep: selectedId);
    // Seçili iğne en üstte çizilsin.
    clusters.sort((a, b) {
      final as = a.members.any((p) => p.id == selectedId) ? 1 : 0;
      final bs = b.members.any((p) => p.id == selectedId) ? 1 : 0;
      return as.compareTo(bs);
    });
    return MarkerLayer(markers: [
      for (final c in clusters)
        if (c.isSingle)
          Marker(
            point: c.first.point,
            width: c.first.id == selectedId ? 64 : 48,
            height: c.first.id == selectedId ? 64 : 48,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onPlaceTap(c.first),
              child: Center(
                child: CampusPin(
                  icon: campusIconFor(config.category(c.first.category)?.icon ?? '', fallbackKey: c.first.category),
                  color: campusPinColor(context, campusCategoryIndex(config, c.first.category)),
                  selected: c.first.id == selectedId,
                  label: l.campusPinLabel(c.first.name, config.category(c.first.category)?.label ?? ''),
                ),
              ),
            ),
          )
        else
          Marker(
            point: c.center,
            width: 48,
            height: 48,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onClusterTap(c),
              child: Center(child: CampusClusterPin(count: c.members.length, label: l.campusClusterLabel('${c.members.length}'))),
            ),
          ),
    ]);
  }
}
