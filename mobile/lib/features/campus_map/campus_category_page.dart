import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'campus_geo.dart';
import 'campus_map_controller.dart';
import 'campus_map_view.dart';
import 'campus_place_page.dart';
import 'campus_search_page.dart';
import 'campus_widgets.dart';

/// Kategori listesi (Stitch "Harita - Kategori listesi"): üstte küçük harita, altında yerler (mesafe hapı + ok),
/// "Yakınlık / Ad" sıralaması ve "Kampüste ara" kartı. [category] null ise tüm kampüs yerleri.
class CampusCategoryPage extends StatefulWidget {
  const CampusCategoryPage({super.key, required this.controller, this.category, this.tileProvider});

  final CampusMapController controller;
  final String? category;
  final TileProvider? tileProvider;

  @override
  State<CampusCategoryPage> createState() => _CampusCategoryPageState();
}

class _CampusCategoryPageState extends State<CampusCategoryPage> {
  final _map = MapController();
  bool _byName = false;

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
    final cfg = ctl.config;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: ctl,
          builder: (context, _) {
            final cat = cfg?.category(widget.category);
            final inCat = widget.category == null ? ctl.places : [for (final p in ctl.places) if (p.category == widget.category) p];
            final base = [for (final p in inCat) if (!ctl.isRemote(p)) p];
            final remotes = [for (final p in inCat) if (ctl.isRemote(p)) p];
            final byDistance = ctl.hasFix && !_byName;
            final list = _byName
                ? ([...base]..sort((a, b) => normalizeTr(a.name).compareTo(normalizeTr(b.name))))
                : sortByDistance(base, ctl.fix?.point);
            final lang = campusLang(context);
            return Column(children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 8),
                child: Row(children: [
                  BuIconButton(icon: BuIcons.arrowLeft, tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: () => Navigator.of(context).maybePop()),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(cat?.label ?? l.campusPlacesTitle, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 44),
                ]),
              ),
              if (cfg != null)
                SizedBox(
                  height: 170,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BuRadius.bLg,
                      child: CampusMapView(
                        controller: ctl,
                        mapController: _map,
                        config: cfg,
                        interactive: false,
                        showScale: false,
                        showSelection: false,
                        places: base,
                        tileProvider: widget.tileProvider,
                        onPlaceTap: (_) {},
                        onClusterTap: (_) {},
                        onBackgroundTap: () {},
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Expanded(
                    child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
                      Text(cat?.label ?? l.campusPlacesTitle, style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                      BuBadge(l.campusPlaceCount('${list.length + remotes.length}'), soft: true),
                    ]),
                  ),
                  if (ctl.hasFix) ...[
                    BuChip(label: l.campusSortNear, selected: byDistance, icon: BuIcons.navigation, onTap: () => setState(() => _byName = false)),
                    const SizedBox(width: 6),
                    BuChip(label: l.campusSortName, selected: _byName, onTap: () => setState(() => _byName = true)),
                  ],
                ]),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: (list.isEmpty && remotes.isEmpty)
                    ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l.campusNoPlaces, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut))))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                        itemCount: list.length + 2,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          if (i == list.length) {
                            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: campusRemoteSection(context, ctl, remotes, (p) => Navigator.of(context).push(MaterialPageRoute<void>(settings: const RouteSettings(name: 'campus_place'), 
                                  builder: (_) => CampusPlacePage(controller: ctl, place: p, tileProvider: widget.tileProvider),
                                ))));
                          }
                          if (i == list.length + 1) return _findMore(context);
                          final p = list[i];
                          final d = ctl.distanceTo(p);
                          final c = ctl.categoryOf(p);
                          return CampusPlaceTile(
                            place: p,
                            strongIcon: true,
                            icon: campusIconFor(c?.icon ?? '', fallbackKey: p.category),
                            categoryLabel: l.campusMainCampus,
                            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(settings: const RouteSettings(name: 'campus_place'), 
                              builder: (_) => CampusPlacePage(controller: ctl, place: p, tileProvider: widget.tileProvider),
                            )),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              if (d != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(color: i == 0 && byDistance ? t.soft : t.sf2, borderRadius: BuRadius.bPill),
                                  child: Text(
                                    formatDistance(d, lang: lang),
                                    style: tx.labelMedium!.copyWith(color: i == 0 && byDistance ? t.onSoft : t.ink, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              const SizedBox(width: 4),
                              Icon(buDirIcon(context, BuIcons.chevronRight), size: 20, color: t.mut),
                            ]),
                          );
                        },
                      ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _findMore(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: t.infoSoft, borderRadius: BuRadius.bMd),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle),
            child: Icon(BuIcons.compass, size: 22, color: t.onPr),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.campusFindMoreTitle, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
              Text(l.campusFindMoreBody, style: tx.bodySmall!.copyWith(color: t.onInfoSoft)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        BuButton(
          label: l.campusSearchHint,
          icon: BuIcons.search,
          kind: BuButtonKind.soft,
          onPressed: () => unawaited(Navigator.of(context).push(MaterialPageRoute<void>(settings: const RouteSettings(name: 'campus_search'), 
            builder: (_) => CampusSearchPage(controller: widget.controller, tileProvider: widget.tileProvider),
          ))),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Icon(BuIcons.info, size: 14, color: t.onInfoSoft),
          const SizedBox(width: 6),
          Expanded(child: Text(l.campusOnlyCampusShown, style: tx.bodySmall!.copyWith(color: t.onInfoSoft))),
        ]),
      ]),
    );
  }
}
