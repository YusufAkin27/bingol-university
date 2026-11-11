import 'package:flutter/material.dart';

import '../../core/academic_catalog.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'club_ref_widgets.dart';

/// Kulüp öneri hedefi: seçilen fakülte/bölüm kanonik (Türkçe) adlarıyla tutulur.
/// Yalnız öneri sıralaması içindir; kulübün görünürlüğünü kısıtlamaz.
class ClubAudience {
  const ClubAudience({this.faculties = const {}, this.departments = const {}});

  final Set<String> faculties;
  final Set<String> departments;

  bool get isEmpty => faculties.isEmpty && departments.isEmpty;
  int get count => faculties.length + departments.length;

  static ClubAudience fromClub(Map<String, dynamic>? club) => ClubAudience(
        faculties: {for (final e in (club?['targetFaculties'] as List? ?? const [])) e.toString()},
        departments: {for (final e in (club?['targetDepartments'] as List? ?? const [])) e.toString()},
      );

  @override
  bool operator ==(Object other) =>
      other is ClubAudience &&
      other.faculties.length == faculties.length &&
      other.departments.length == departments.length &&
      other.faculties.containsAll(faculties) &&
      other.departments.containsAll(departments);

  @override
  int get hashCode => Object.hash(faculties.length, departments.length);
}

/// Alt sayfa: aranabilir fakülte/bölüm çoklu seçimi. Dönüş: yeni seçim (iptalde null).
Future<ClubAudience?> pickClubAudience(BuildContext context, Session session, ClubAudience current) {
  final l = context.l10n;
  return BuSheet.show<ClubAudience>(
    context,
    title: l.clubAudienceSheetTitle,
    subtitle: l.clubAudienceSheetHint,
    scrollable: false,
    maxHeightFactor: .92,
    builder: (_) => _AudienceSheet(session: session, initial: current),
  );
}

class _AudienceSheet extends StatefulWidget {
  const _AudienceSheet({required this.session, required this.initial});

  final Session session;
  final ClubAudience initial;

  @override
  State<_AudienceSheet> createState() => _AudienceSheetState();
}

class _AudienceSheetState extends State<_AudienceSheet> {
  static const _max = 12;

  late final AcademicCatalog _cat = AcademicCatalog.of(widget.session);
  late final Set<String> _fac = {...widget.initial.faculties};
  late final Set<String> _dep = {...widget.initial.departments};
  final _open = <String>{};
  final _q = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cat.addListener(_tick);
    _cat.load();
    _q.addListener(_tick);
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cat.removeListener(_tick);
    _q.dispose();
    super.dispose();
  }

  void _toggle(Set<String> s, String v) {
    setState(() {
      if (!s.remove(v)) {
        if (_fac.length >= _max && identical(s, _fac)) return;
        if (_dep.length >= _max && identical(s, _dep)) return;
        s.add(v);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context);
    final lang = locale.languageCode;
    final h = MediaQuery.sizeOf(context).height * .62;
    final searching = _q.text.trim().isNotEmpty;

    Widget body;
    if (_cat.state == CatalogState.error) {
      body = Center(
        child: ClubBtn(label: l.clubAudienceRetry, onPressed: _cat.retry),
      );
    } else if (!_cat.ready) {
      body = const Center(child: BuSpinner(size: 28));
    } else {
      final rows = <Widget>[];
      for (final f in _cat.faculties) {
        final deps = searching ? _cat.searchDepartments(_q.text, faculty: f, locale: locale) : f.departments;
        final facHit = searching && _cat.searchFaculties(_q.text, locale: locale).contains(f);
        if (searching && deps.isEmpty && !facHit) continue;
        final open = searching || _open.contains(f.name);
        final onF = _fac.contains(f.name);
        rows.add(BuListTile(
          title: f.label(lang),
          subtitle: l.clubAudienceDeptCount(f.departments.length),
          selected: onF,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (onF) Icon(BuIcons.check, size: 18, color: t.ink),
            IconButton(
              tooltip: open ? l.clubAudienceCollapse : l.clubAudienceExpand,
              icon: Icon(open ? BuIcons.chevronUp : BuIcons.chevronDown, size: 20, color: t.mut),
              onPressed: searching ? null : () => setState(() => open ? _open.remove(f.name) : _open.add(f.name)),
            ),
          ]),
          onTap: () => _toggle(_fac, f.name),
        ));
        if (open) {
          for (final d in deps) {
            final onD = _dep.contains(d.name);
            rows.add(BuListTile(
              title: d.label(lang),
              selected: onD,
              padding: const EdgeInsetsDirectional.fromSTEB(36, 8, 16, 8),
              trailing: onD ? Icon(BuIcons.check, size: 18, color: t.ink) : null,
              onTap: () => _toggle(_dep, d.name),
            ));
          }
        }
      }
      body = rows.isEmpty
          ? Center(child: Text(l.clubAudienceNoMatch, style: tx.bodyMedium!.copyWith(color: t.mut)))
          : ListView(children: rows);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _q,
          style: tx.bodyLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w400),
          decoration: clubFill(context, hint: l.clubAudienceSearchHint, prefixIcon: Icon(BuIcons.search, size: 20, color: t.mut)),
        ),
        const SizedBox(height: 8),
        SizedBox(height: h, child: body),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: ClubBtn(
              label: l.clubAudienceClear,
              onPressed: (_fac.isEmpty && _dep.isEmpty) ? null : () => setState(() {
                _fac.clear();
                _dep.clear();
              }),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClubBtn(
              label: l.clubAudienceDone(_fac.length + _dep.length),
              kind: ClubBtnKind.ink,
              onPressed: () => Navigator.of(context).pop(ClubAudience(faculties: {..._fac}, departments: {..._dep})),
            ),
          ),
        ]),
        const SizedBox(height: 8),
      ],
    );
  }
}
