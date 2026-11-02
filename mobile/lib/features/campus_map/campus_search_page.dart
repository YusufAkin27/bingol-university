import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'campus_category_page.dart';
import 'campus_geo.dart';
import 'campus_local_store.dart';
import 'campus_map_controller.dart';
import 'campus_models.dart';
import 'campus_nav.dart';
import 'campus_place_page.dart';
import 'campus_widgets.dart';

/// Kampüs içi arama (Stitch "Harita - Arama"): YALNIZ kampüs yerleri, istemcide, Türkçe aksan duyarsız.
/// Boş sorguda son aramalar (yerel) + kategoriler; sonuçlar kategori gruplarıyla ve vurgulu eşleşmeyle.
class CampusSearchPage extends StatefulWidget {
  const CampusSearchPage({super.key, required this.controller, this.tileProvider});

  final CampusMapController controller;
  final TileProvider? tileProvider;

  @override
  State<CampusSearchPage> createState() => _CampusSearchPageState();
}

class _CampusSearchPageState extends State<CampusSearchPage> {
  final _text = TextEditingController();
  List<String> _recent = const [];

  CampusMapController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    unawaited(CampusLocalStore.loadRecent().then((r) {
      if (mounted) setState(() => _recent = r);
    }));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _remember(String term) async {
    final next = CampusLocalStore.pushRecent(_recent, term, (s) => normalizeTr(s).trim());
    if (next == _recent) return;
    setState(() => _recent = next);
    await CampusLocalStore.saveRecent(next);
  }

  void _setQuery(String q) {
    _text.value = TextEditingValue(text: q, selection: TextSelection.collapsed(offset: q.length));
    setState(() {});
  }

  Future<void> _removeRecent(String s) async {
    setState(() => _recent = [for (final e in _recent) if (e != s) e]);
    await CampusLocalStore.saveRecent(_recent);
  }

  Future<void> _clearRecent() async {
    setState(() => _recent = const []);
    await CampusLocalStore.saveRecent(const []);
  }

  void _open(CampusPlace p) {
    unawaited(_remember(_text.text));
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CampusPlacePage(controller: _c, place: p, tileProvider: widget.tileProvider),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _c,
          builder: (context, _) {
            final q = _text.text.trim();
            return Column(children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 16, 4),
                child: Row(children: [
                  BuIconButton(icon: BuIcons.arrowLeft, tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: () => Navigator.of(context).maybePop()),
                  const SizedBox(width: 8),
                  Expanded(
                    child: BuSearchField(
                      hint: l.campusSearchHint,
                      controller: _text,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (v) => unawaited(_remember(v)),
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 12, 4),
                    decoration: BoxDecoration(color: t.soft, borderRadius: BuRadius.bPill),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(BuIcons.shieldCheck, size: 14, color: t.onSoft),
                      const SizedBox(width: 6),
                      Text(l.campusOnlyCampus, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: t.onSoft, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ]),
              ),
              Expanded(child: q.isEmpty ? _idle(context) : _results(context, q)),
            ]);
          },
        ),
      ),
    );
  }

  /// Sorgu yok: son aramalar + kategoriler.
  Widget _idle(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final cats = _c.config?.categories ?? const <CampusCategory>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        if (_recent.isNotEmpty) ...[
          _SectionHead(icon: BuIcons.history, title: l.campusRecent, action: l.campusClear, onAction: () => unawaited(_clearRecent())),
          for (final s in _recent)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: BuPressable(
                onTap: () => _setQuery(s),
                semanticLabel: s,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
                  decoration: BoxDecoration(color: t.sf, borderRadius: BuRadius.bMd, border: Border.all(color: t.bd)),
                  child: Row(children: [
                    ExcludeSemantics(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: t.infoSoft, borderRadius: BuRadius.bSm),
                        child: Icon(BuIcons.clock, size: 20, color: t.onInfoSoft),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w600))),
                    IconButton(
                      tooltip: l.campusRemoveRecent,
                      onPressed: () => unawaited(_removeRecent(s)),
                      icon: Icon(BuIcons.x, size: 18, color: t.mut),
                    ),
                  ]),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
        if (cats.isNotEmpty) ...[
          _SectionHead(icon: BuIcons.map, title: l.campusCategoriesTitle),
          for (final c in cats)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: BuPressable(
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => CampusCategoryPage(controller: _c, category: c.key, tileProvider: widget.tileProvider),
                )),
                semanticLabel: c.label,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 4),
                  decoration: BoxDecoration(color: t.sf, borderRadius: BuRadius.bMd, border: Border.all(color: t.bd)),
                  child: Row(children: [
                    ExcludeSemantics(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: t.nav, borderRadius: BuRadius.bSm),
                        child: Icon(campusIconFor(c.icon, fallbackKey: c.key), size: 20, color: t.onNav),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(c.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w700))),
                    Icon(buDirIcon(context, BuIcons.chevronRight), size: 18, color: t.mut),
                  ]),
                ),
              ),
            ),
        ],
        const SizedBox(height: 8),
        Text(l.campusOutsideNote, textAlign: TextAlign.center, style: tx.bodySmall!.copyWith(color: t.mut)),
      ],
    );
  }

  Widget _results(BuildContext context, String q) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final lang = campusLang(context);
    final hits = searchPlaces(_c.places, q);
    if (hits.isEmpty) {
      return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: t.infoSoft, borderRadius: BuRadius.bMd),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: t.sf.withValues(alpha: .7), borderRadius: BuRadius.bSm),
              child: Icon(BuIcons.searchX, size: 22, color: t.onInfoSoft),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Semantics(liveRegion: true, child: Text(l.campusNoResult, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800))),
                const SizedBox(height: 2),
                Text(l.campusOutsideNote, style: tx.bodySmall!.copyWith(color: t.onInfoSoft)),
              ]),
            ),
          ]),
        ),
      ]);
    }
    // Kategori sırasına göre gruplar.
    final cats = _c.config?.categories ?? const <CampusCategory>[];
    final groups = <(String, List<CampusPlace>)>[];
    final main = [for (final p in hits) if (!_c.isRemote(p)) p];
    final far = [for (final p in hits) if (_c.isRemote(p)) p];
    for (final c in cats) {
      final m = [for (final p in main) if (p.category == c.key) p];
      if (m.isNotEmpty) groups.add((c.label, m));
    }
    final known = {for (final c in cats) c.key};
    final rest = [for (final p in main) if (!known.contains(p.category)) p];
    if (rest.isNotEmpty) groups.add((l.campusPlacesTitle, rest));
    // Ana yerleşke dışındakiler ayrı grupta (haritada iğnesi yok).
    if (far.isNotEmpty) groups.add((l.campusOtherCampuses, far));
    final nearest = _nearest(main);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        for (final g in groups) ...[
          _SectionHead(title: trUpper(g.$1), trailing: l.campusResultCount('${g.$2.length}')),
          for (final p in g.$2)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CampusPlaceTile(
                place: p,
                icon: campusIconFor(_c.categoryOf(p)?.icon ?? '', fallbackKey: p.category),
                categoryLabel: _c.categoryOf(p)?.label ?? '',
                distanceText: _c.distanceTo(p) == null ? null : formatDistance(_c.distanceTo(p)!, lang: lang),
                highlight: matchRange(p.name, q),
                onTap: () => _open(p),
                trailing: CampusWalkButton(tooltip: l.campusWalkTo(p.name), onTap: () => unawaited(openDirections(context, p))),
              ),
            ),
        ],
        if (nearest != null) _QuickRoute(place: nearest.$1, minutes: nearest.$2, onStart: () => unawaited(openDirections(context, nearest.$1))),
      ],
    );
  }

  /// En yakın sonuç (yalnız konum varsa ve kullanıcı kampüsteyse).
  (CampusPlace, int)? _nearest(List<CampusPlace> hits) {
    if (!_c.hasFix || _c.userInside != true || hits.isEmpty) return null;
    final s = sortByDistance(hits, _c.fix!.point).first;
    return (s, walkMinutes(_c.distanceTo(s)!));
  }
}

class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.title, this.icon, this.trailing, this.action, this.onAction});

  final String title;
  final IconData? icon;
  final String? trailing;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 0, 6),
      child: Row(children: [
        if (icon != null) ...[Icon(icon, size: 16, color: t.mut), const SizedBox(width: 6)],
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: tx.labelMedium!.copyWith(color: t.mut, letterSpacing: .8, fontWeight: FontWeight.w800)),
          ),
        ),
        if (trailing != null) Padding(padding: const EdgeInsetsDirectional.only(end: 4), child: Text(trailing!, style: tx.labelMedium!.copyWith(color: t.mut))),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(minimumSize: const Size(48, 40), foregroundColor: t.mut),
            child: Text(action!, style: tx.labelMedium!.copyWith(color: t.mut, fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }
}

/// "HIZLI ROTA / En yakın yer / Başlat" kartı.
class _QuickRoute extends StatelessWidget {
  const _QuickRoute({required this.place, required this.minutes, required this.onStart});

  final CampusPlace place;
  final int minutes;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: t.infoSoft, borderRadius: BuRadius.bMd),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.campusQuickRoute, style: tx.labelSmall!.copyWith(color: t.pr, letterSpacing: .8, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(l.campusNearestTitle, style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(l.campusNearestBody(place.name, '$minutes'), style: tx.bodySmall!.copyWith(color: t.onInfoSoft)),
          ]),
        ),
        const SizedBox(width: 12),
        BuButton(label: l.campusStart, icon: BuIcons.navigation, compact: true, onPressed: onStart),
      ]),
    );
  }
}
