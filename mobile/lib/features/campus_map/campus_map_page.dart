import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'campus_category_page.dart';
import 'campus_geo.dart';
import 'campus_location.dart';
import 'campus_map_controller.dart';
import 'campus_map_view.dart';
import 'campus_models.dart';
import 'campus_nav.dart';
import 'campus_place_page.dart';
import 'campus_repository.dart';
import 'campus_search_page.dart';
import 'campus_states.dart';
import 'campus_widgets.dart';

/// Panelin üç aşaması (ekran yüksekliğinin oranı): kısık / yarım / tam.
const campusPanelStages = <double>[0.14, 0.42, 0.92];

/// Kampüs Haritası ana ekranı (Stitch "Harita - Ana"): arama çubuğu, kategori çipleri, harita, 3 aşamalı alt panel.
/// Veri yalnız bu ekran açılınca istenir (`/campus/map` + `/campus/places`); konum yalnız ön planda ve cihazda kalır.
class CampusMapPage extends StatefulWidget {
  const CampusMapPage({
    super.key,
    required this.repository,
    this.categoryHint,
    this.initialPlaceId,
    this.openSearch = false,
    this.controller,
    this.tileProvider,
  });

  final CampusMapRepository repository;
  final String? categoryHint;
  final int? initialPlaceId;

  /// Ana Sayfa "Kampüste ara" şeridinden gelindiyse harita hazır olunca arama ekranı açılır.
  final bool openSearch;

  /// Yalnız test: hazır denetleyici.
  final CampusMapController? controller;

  /// Yalnız test: ağ yerine sahte karo sağlayıcı.
  final TileProvider? tileProvider;

  @override
  State<CampusMapPage> createState() => _CampusMapPageState();
}

class _CampusMapPageState extends State<CampusMapPage> with WidgetsBindingObserver, TickerProviderStateMixin {
  late final CampusMapController _ctl;
  final _map = MapController();
  final _sheet = DraggableScrollableController();
  final _inset = ValueNotifier<double>(0);
  double _regionH = 600;
  bool _satellite = false;
  bool _flyOnFix = false;
  int? _lastSel;
  bool _searchOpened = false;
  bool _promptShown = false;
  AnimationController? _anim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ctl = widget.controller ??
        CampusMapController(repo: widget.repository, categoryHint: widget.categoryHint, initialPlaceId: widget.initialPlaceId);
    _ctl.addListener(_onCtl);
    if (widget.controller == null) unawaited(_ctl.start());
    // Denetleyici sayfadan önce hazırsa (testler/yeniden giriş) durum tabanlı tetikleyiciler ilk karede değerlendirilir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onCtl();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctl.removeListener(_onCtl);
    if (widget.controller == null) _ctl.dispose();
    _anim?.dispose();
    _sheet.dispose();
    _inset.dispose();
    _map.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Konum YALNIZ ön planda: arka plana giderken akış durur, dönünce izin/servis yeniden okunur.
    if (state == AppLifecycleState.resumed) {
      unawaited(_ctl.resume());
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _ctl.pause();
    }
  }

  void _onCtl() {
    if (widget.openSearch && !_searchOpened && _ctl.load == CampusLoad.ready) {
      _searchOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openSearch();
      });
    }
    if (_ctl.selectedId != _lastSel) {
      _lastSel = _ctl.selectedId;
      final s = _ctl.selected;
      if (s != null) _flyTo(s.point, zoom: math.max(_cameraZoom(), 17));
    }
    if (_ctl.loc == CampusLocState.promptNeeded && !_promptShown) {
      _promptShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_showPermissionSheet());
      });
    }
    if (_flyOnFix && _ctl.fix != null) {
      _flyOnFix = false;
      _flyToUser();
    }
  }

  /// "Konumunuzu kullanalım mı?" alt sayfası: yalnız izin hiç sorulmadıysa ve daha önce "Şimdi değil" denmediyse.
  Future<void> _showPermissionSheet() async {
    final allow = await BuSheet.show<bool>(
      context,
      builder: (ctx) => CampusPermissionCard(
        framed: false,
        onAllow: () => Navigator.pop(ctx, true),
        onLater: () => Navigator.pop(ctx, false),
      ),
    );
    if (!mounted) return;
    if (allow == true) {
      _flyOnFix = true;
      await _ctl.requestLocation();
    } else {
      _ctl.dismissPrompt();
    }
  }

  void _syncInset() {
    final h = _regionH * (_sheet.isAttached ? _sheet.size : campusPanelStages[1]);
    final maxInset = math.max(0.0, _regionH - 260);
    final v = math.min(h, maxInset);
    if ((v - _inset.value).abs() > .5) _inset.value = v;
  }

  double _cameraZoom() {
    try {
      return _map.camera.zoom;
    } catch (_) {
      return _ctl.config?.initialZoom ?? 16;
    }
  }

  void _flyTo(LatLng to, {double? zoom}) {
    final cfg = _ctl.config;
    if (cfg == null) return;
    try {
      final cam = _map.camera;
      final z = (zoom ?? cam.zoom).clamp(cfg.minZoom, cfg.maxZoom).toDouble();
      final target = clampToBounds(to, cfg.bounds);
      if (BuMotion.reduced(context)) {
        _map.move(target, z);
        return;
      }
      _anim?.dispose();
      final c = _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
      final curve = CurvedAnimation(parent: c, curve: Curves.easeInOutCubic);
      final lat = Tween<double>(begin: cam.center.latitude, end: target.latitude);
      final lng = Tween<double>(begin: cam.center.longitude, end: target.longitude);
      final zt = Tween<double>(begin: cam.zoom, end: z);
      c.addListener(() {
        try {
          _map.move(LatLng(lat.evaluate(curve), lng.evaluate(curve)), zt.evaluate(curve));
        } catch (_) {}
      });
      unawaited(c.forward());
    } catch (_) {
      // Harita henüz kurulmadı: sessizce geç.
    }
  }

  void _zoomBy(double d) {
    final cfg = _ctl.config;
    if (cfg == null) return;
    _flyTo(_map.camera.center, zoom: _map.camera.zoom + d);
  }

  void _flyToUser() {
    final f = _ctl.fix;
    final cfg = _ctl.config;
    if (f == null || cfg == null) return;
    if (_ctl.userInside == false) {
      BuToast.show(context, context.l10n.campusOutsideCampus, kind: BuToastKind.info);
      _flyTo(cfg.center, zoom: cfg.initialZoom);
      return;
    }
    _flyTo(f.point, zoom: math.max(_cameraZoom(), 17));
  }

  Future<void> _onLocate() async {
    switch (_ctl.loc) {
      case CampusLocState.deniedForever:
        await CampusLocationService.instance.openAppSettings();
        return;
      case CampusLocState.serviceOff:
        await CampusLocationService.instance.openLocationSettings();
        return;
      case CampusLocState.granted when _ctl.fix != null:
        _flyToUser();
        return;
      default:
        _flyOnFix = true;
        await _ctl.requestLocation();
    }
  }

  void _onClusterTap(CampusCluster c) {
    try {
      _map.fitCamera(CameraFit.coordinates(
        coordinates: [for (final p in c.members) p.point],
        padding: const EdgeInsets.all(72),
        maxZoom: math.min(18, _ctl.config?.maxZoom ?? 18),
      ));
    } catch (_) {}
  }

  void _openSearch() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CampusSearchPage(controller: _ctl),
    ));
  }

  void _openDetail(CampusPlace p) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CampusPlacePage(controller: _ctl, place: p, tileProvider: widget.tileProvider),
    ));
  }

  void _openCategoryList() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CampusCategoryPage(controller: _ctl, category: _ctl.category, tileProvider: widget.tileProvider),
    ));
  }

  void _cycleStage() {
    if (!_sheet.isAttached) return;
    final s = _sheet.size;
    final next = s < (campusPanelStages[0] + campusPanelStages[1]) / 2
        ? campusPanelStages[1]
        : s < (campusPanelStages[1] + campusPanelStages[2]) / 2
            ? campusPanelStages[2]
            : campusPanelStages[0];
    unawaited(_sheet.animateTo(next, duration: BuMotion.of(context, BuMotion.medium), curve: BuMotion.emphasized));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _ctl,
          builder: (context, _) => Column(children: [
            _header(context),
            if (_ctl.load == CampusLoad.ready) ...[
              _searchBlock(context),
              _chips(context),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: switch (_ctl.load) {
                CampusLoad.loading => _loading(context),
                CampusLoad.error => Center(child: CampusMapErrorCard(onRetry: () => unawaited(_ctl.refresh(force: true)))),
                CampusLoad.maintenance => Center(child: CampusMapErrorCard(maintenance: true, onRetry: () => unawaited(_ctl.refresh(force: true)))),
                CampusLoad.ready => _body(context),
              },
            ),
          ]),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 16, 8),
      child: Row(children: [
        BuIconButton(icon: BuIcons.arrowLeft, tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: () => Navigator.of(context).maybePop()),
        const SizedBox(width: 12),
        ExcludeSemantics(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: t.soft, borderRadius: BuRadius.bSm),
            child: Icon(BuIcons.graduationCap, size: 22, color: t.pr),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Semantics(
            header: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(l.campusTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w800, height: 1.1)),
              Text(l.campusBrand, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelSmall!.copyWith(color: t.mut, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _searchBlock(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BuSearchField(hint: l.campusSearchHint, readOnly: true, onTap: _openSearch),
        const SizedBox(height: 6),
        Row(children: [
          ExcludeSemantics(child: Container(width: 6, height: 6, decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle))),
          const SizedBox(width: 6),
          Flexible(child: Text(l.campusOnlyCampus, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: t.mut))),
        ]),
        const SizedBox(height: 4),
      ]),
    );
  }

  Widget _chips(BuildContext context) {
    final cats = _ctl.config?.categories ?? const <CampusCategory>[];
    if (cats.isEmpty) return const SizedBox.shrink();
    final l = context.l10n;
    final sel = _ctl.category == null ? 0 : (cats.indexWhere((c) => c.key == _ctl.category) + 1).clamp(0, cats.length);
    return BuChipRow(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      labels: [l.campusAll, for (final c in cats) c.label],
      icons: [BuIcons.map, for (final c in cats) campusIconFor(c.icon, fallbackKey: c.key)],
      selected: sel,
      onSelected: (i) => _ctl.selectCategory(i == 0 ? null : cats[i - 1].key),
    );
  }

  Widget _loading(BuildContext context) {
    final t = context.bu;
    return BuSkeletonScope(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(children: [
          const BuSkeleton(height: 52, radius: BuRadius.pill),
          const SizedBox(height: 12),
          const Expanded(child: BuSkeleton(radius: 20)),
          const SizedBox(height: 12),
          Container(
            height: 176,
            decoration: BoxDecoration(color: t.sf, borderRadius: BuRadius.topXl),
            padding: const EdgeInsets.all(16),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              BuSkeleton(width: 160, height: 18),
              SizedBox(height: 14),
              BuSkeleton(height: 44, radius: 12),
              SizedBox(height: 8),
              BuSkeleton(height: 44, radius: 12),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final cfg = _ctl.config!;
    final t = context.bu;
    return LayoutBuilder(builder: (context, box) {
      _regionH = box.maxHeight;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncInset();
      });
      final maxInset = math.max(0.0, box.maxHeight - 260);
      return NotificationListener<DraggableScrollableNotification>(
        onNotification: (n) {
          _inset.value = math.min(n.extent * _regionH, maxInset);
          return false;
        },
        child: Stack(children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BuRadius.bLg,
              child: CampusMapView(
                controller: _ctl,
                mapController: _map,
                config: cfg,
                satellite: _satellite,
                bottomInset: _inset,
                tileProvider: widget.tileProvider,
                onPlaceTap: (p) => _ctl.select(p.id),
                onClusterTap: _onClusterTap,
                onBackgroundTap: () => _ctl.select(null),
              ),
            ),
          ),
          if (_ctl.tilesFailing)
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: CampusTilesBand(onRetry: () {
                _ctl.clearTileErrors();
                unawaited(_ctl.refresh(force: true));
              }),
            ),
          ValueListenableBuilder<double>(
            valueListenable: _inset,
            builder: (context, inset, _) => PositionedDirectional(
              end: 12,
              bottom: math.min(inset, maxInset) + 12,
              child: _mapButtons(context, cfg),
            ),
          ),
          Positioned.fill(
            child: DraggableScrollableSheet(
              controller: _sheet,
              initialChildSize: campusPanelStages[1],
              minChildSize: campusPanelStages[0],
              maxChildSize: campusPanelStages[2],
              snap: true,
              snapSizes: campusPanelStages,
              builder: (context, sc) => DecoratedBox(
                key: const ValueKey('campus-panel'),
                decoration: BoxDecoration(
                  color: t.sf,
                  borderRadius: BuRadius.topXl,
                  border: Border.all(color: t.bd),
                  boxShadow: BuElevation.of(context, 3),
                ),
                child: ClipRRect(borderRadius: BuRadius.topXl, child: _panel(context, sc)),
              ),
            ),
          ),
        ]),
      );
    });
  }

  Widget _mapButtons(BuildContext context, CampusMapConfig cfg) {
    final l = context.l10n;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      CampusMapButton(icon: BuIcons.plus, tooltip: l.campusZoomIn, onTap: () => _zoomBy(1)),
      const SizedBox(height: 8),
      CampusMapButton(icon: BuIcons.minus, tooltip: l.campusZoomOut, onTap: () => _zoomBy(-1)),
      const SizedBox(height: 8),
      CampusMapButton(icon: BuIcons.locateFixed, tooltip: l.campusMyLocation, active: _ctl.fix != null, onTap: () => unawaited(_onLocate())),
      // Uydu katmanı YALNIZ sunucu uydu karosu verirse: ölü düğme yok.
      if (cfg.satelliteTiles != null) ...[
        const SizedBox(height: 8),
        CampusMapButton(
          icon: BuIcons.layers,
          tooltip: '${l.campusLayers}: ${_satellite ? l.campusLayerStandard : l.campusLayerSatellite}',
          active: _satellite,
          onTap: () => setState(() => _satellite = !_satellite),
        ),
      ],
    ]);
  }

  Widget _panel(BuildContext context, ScrollController sc) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final lang = campusLang(context);
    final hasNear = _ctl.hasFix && _ctl.userInside != false;
    final list = _ctl.nearby();
    final remotes = _ctl.remotes;
    final sel = _ctl.selected;
    final loc = _ctl.loc;
    final showBand = loc == CampusLocState.deniedForever || (loc == CampusLocState.denied && !_ctl.promptDismissed);
    return CustomScrollView(
      controller: sc,
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Semantics(
            button: true,
            label: l.campusPanelHandle,
            onTap: _cycleStage,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _cycleStage,
              child: SizedBox(
                height: 28,
                child: Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: t.bdStrong.withValues(alpha: .5), borderRadius: BuRadius.bPill))),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(children: [
              Expanded(
                child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
                  Semantics(
                    header: true,
                    child: Text(hasNear ? l.campusNearby : l.campusPlacesTitle, style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                  ),
                  BuBadge(l.campusPlaceCount('${list.length}'), soft: true),
                ]),
              ),
              TextButton(
                onPressed: _openCategoryList,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: t.prText),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(l.campusSeeAll, style: tx.labelLarge!.copyWith(color: t.prText, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 2),
                  Icon(buDirIcon(context, BuIcons.chevronRight), size: 16, color: t.prText),
                ]),
              ),
            ]),
          ),
        ),
        if (loc == CampusLocState.serviceOff)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: CampusServiceOffCard(onOpenSettings: () => unawaited(CampusLocationService.instance.openLocationSettings())),
            ),
          ),
        if (showBand)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: CampusLocationBand(
                state: loc,
                onOpenSettings: () => unawaited(CampusLocationService.instance.openAppSettings()),
                onRetry: () => unawaited(_ctl.requestLocation()),
              ),
            ),
          ),
        if (_ctl.userInside == false)
          SliverToBoxAdapter(
            child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: CampusInfoBand(text: l.campusOutsideCampus, icon: BuIcons.mapPin)),
          ),
        if (_ctl.stale)
          SliverToBoxAdapter(
            child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: CampusInfoBand(text: l.campusStaleNote, icon: BuIcons.cloudOff)),
          ),
        if (sel != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _SelectedCard(
                place: sel,
                category: _ctl.categoryOf(sel),
                distance: _ctl.distanceTo(sel),
                lang: lang,
                onClose: () => _ctl.select(null),
                onDetail: () => _openDetail(sel),
                onDirections: () => unawaited(openDirections(context, sel)),
              ),
            ),
          ),
        if (list.isEmpty && remotes.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Center(
                child: Text(_ctl.places.isEmpty ? l.campusNoPlacesAll : l.campusNoPlaces, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut)),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final p = list[i];
                final d = _ctl.distanceTo(p);
                return CampusPlaceTile(
                  place: p,
                  icon: campusIconFor(_ctl.categoryOf(p)?.icon ?? '', fallbackKey: p.category),
                  categoryLabel: _ctl.categoryOf(p)?.label ?? '',
                  distanceText: d == null ? null : formatDistance(d, lang: lang),
                  selected: p.id == _ctl.selectedId,
                  onTap: () => _openDetail(p),
                  trailing: CampusWalkButton(tooltip: l.campusWalkTo(p.name), onTap: () => unawaited(openDirections(context, p))),
                );
              },
            ),
          ),
        if (remotes.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(delegate: SliverChildListDelegate(campusRemoteSection(context, _ctl, remotes, _openDetail))),
          ),
      ],
    );
  }
}

/// Seçili yer kartı (iğneye dokununca): kısa bilgi + Detay / Yol tarifi.
class _SelectedCard extends StatelessWidget {
  const _SelectedCard({
    required this.place,
    required this.category,
    required this.distance,
    required this.lang,
    required this.onClose,
    required this.onDetail,
    required this.onDirections,
  });

  final CampusPlace place;
  final CampusCategory? category;
  final double? distance;
  final String lang;
  final VoidCallback onClose, onDetail, onDirections;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final sub = [
      if (category != null) category!.label,
      if (distance != null) l.campusWalkValue('${walkMinutes(distance!)}', formatDistance(distance!, lang: lang)),
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.soft.withValues(alpha: .55), borderRadius: BuRadius.bMd, border: Border.all(color: t.selectedBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: t.pr, borderRadius: BuRadius.bSm),
            child: Icon(campusIconFor(category?.icon ?? '', fallbackKey: place.category), size: 22, color: t.onPr),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(place.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
              if (sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
            ]),
          ),
          BuIconButton(icon: BuIcons.x, tooltip: l.campusCloseCard, onTap: onClose, size: 40),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: BuButton(label: l.campusDetails, kind: BuButtonKind.soft, compact: true, onPressed: onDetail)),
          const SizedBox(width: 8),
          Expanded(child: BuButton(label: l.campusDirections, icon: BuIcons.cornerUpRight, compact: true, onPressed: onDirections)),
        ]),
      ]),
    );
  }
}
