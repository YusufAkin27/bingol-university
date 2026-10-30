import 'package:flutter/material.dart';

import '../core/academic_catalog.dart';
import '../core/locale_controller.dart';
import '../features/auth/widgets/auth_ref.dart';
import 'bu.dart';

/// Bölüm seçici (Stitch 02 "Bölüm seçici"): tam ekran; arama alanı + fakülte grupları (kart), seçili satır tonlu
/// ve işaretli. Sonuç yoksa "Sonuç bulunamadı.", liste yüklenemediyse "Bölüm listesi yüklenemedi." + "Yeniden dene".
/// Seçilen [AcademicDepartment] ile kapanır.
Future<AcademicDepartment?> showDepartmentPicker(
  BuildContext context, {
  required AcademicCatalog catalog,
  String? selectedFaculty,
  String? selected,
}) {
  return Navigator.push<AcademicDepartment>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => DepartmentPickerPage(catalog: catalog, selectedFaculty: selectedFaculty, selected: selected),
    ),
  );
}

class DepartmentPickerPage extends StatefulWidget {
  const DepartmentPickerPage({super.key, required this.catalog, this.selectedFaculty, this.selected});

  final AcademicCatalog catalog;
  final String? selectedFaculty;
  final String? selected;

  @override
  State<DepartmentPickerPage> createState() => _DepartmentPickerPageState();
}

class _DepartmentPickerPageState extends State<DepartmentPickerPage> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  /// Aksan duyarsız süzülen bölümleri fakülte sırasını koruyarak gruplar.
  List<(AcademicFaculty, List<AcademicDepartment>)> _groups() {
    final out = <AcademicFaculty, List<AcademicDepartment>>{};
    for (final d in widget.catalog.searchDepartments(_q.text)) {
      out.putIfAbsent(d.faculty, () => []).add(d);
    }
    return [for (final e in out.entries) (e.key, e.value)];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final sel = widget.selected == null ? null : foldTr(widget.selected!);
    final selF = widget.selectedFaculty == null ? null : foldTr(widget.selectedFaculty!);
    return ListenableBuilder(
      listenable: widget.catalog,
      builder: (context, _) {
        final failed = widget.catalog.state == CatalogState.error;
        final groups = _groups();
        return RefPage(
          children: [
            Semantics(
              header: true,
              child: Text(l.pickDepartment, style: tx.headlineMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 16),
            BuSearchField(hint: l.pickSearch, controller: _q, onChanged: (_) => setState(() {})),
            const SizedBox(height: 16),
            for (final g in groups) ...[
              RefCard(
                radius: 24,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(LucideIcons.building2, size: 20, color: t.pr),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            trUpper(g.$1.name),
                            style: tx.labelLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w800, letterSpacing: .3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(l.p02FacultyCount(g.$2.length), style: tx.labelMedium!.copyWith(color: t.mut)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < g.$2.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: t.bd),
                      _DeptRow(
                        name: g.$2[i].name,
                        query: _q.text,
                        selected: sel == foldTr(g.$2[i].name) && (selF == null || selF == foldTr(g.$2[i].faculty.name)),
                        onTap: () => Navigator.pop(context, g.$2[i]),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (groups.isEmpty && !failed) _InfoRow(icon: LucideIcons.searchX, text: l.pickNoResults),
            if (failed)
              _InfoRow(
                icon: LucideIcons.refreshCcw,
                text: l.pickListFailed,
                action: l.pickRetry,
                onAction: widget.catalog.retry,
              ),
          ],
        );
      },
    );
  }
}

/// Bölüm satırı: eşleşen parça vurgulanır; sağda boş daire / seçiliyse dolu işaretli daire.
class _DeptRow extends StatelessWidget {
  const _DeptRow({required this.name, required this.query, required this.selected, required this.onTap});

  final String name;
  final String query;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final base = tx.bodyLarge!.copyWith(color: selected ? t.pr : t.ink, fontWeight: selected ? FontWeight.w700 : FontWeight.w500);
    final q = foldTr(query);
    final at = q.isEmpty ? -1 : foldTr(name).indexOf(q);
    final Widget title = at < 0 || at + q.length > name.length
        ? Text(name, style: base)
        : Text.rich(TextSpan(style: base, children: [
            TextSpan(text: name.substring(0, at)),
            TextSpan(
              text: name.substring(at, at + q.length),
              style: TextStyle(backgroundColor: t.soft, color: t.onSoft, fontWeight: FontWeight.w800),
            ),
            TextSpan(text: name.substring(at + q.length)),
          ]));
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? t.soft.withValues(alpha: .6) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 12),
                  _Radio(selected: selected),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? t.pr : Colors.transparent,
        border: selected ? null : Border.all(color: t.bd, width: 1.6),
      ),
      child: selected ? Icon(LucideIcons.check, size: 15, color: t.onPr) : null,
    );
  }
}

/// Liste altı bilgi satırı: simge karosu + metin (+ sağda küçük eylem).
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, this.action, this.onAction});

  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return RefCard(
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: action == null ? t.sf2 : t.soft, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: action == null ? t.mut : t.pr),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: tx.bodyMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w600))),
          if (action != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                backgroundColor: t.soft,
                foregroundColor: t.onSoft,
                minimumSize: const Size(48, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: const StadiumBorder(),
              ),
              child: Text(action!, style: tx.labelLarge!.copyWith(color: t.onSoft, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Sınıf seçici (Stitch 02 "Sınıf seçici"): alt sayfa; başlık + kapat, satırlar, seçili satır tonlu + işaretli.
Future<String?> showGradeSheet(BuildContext context, {required List<AcademicGrade> grades, String? selected}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final t = ctx.bu;
      final l = ctx.l10n;
      final tx = Theme.of(ctx).textTheme;
      return DecoratedBox(
        decoration: BoxDecoration(color: t.sf3, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: t.bd, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(l.pickGrade, style: tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    IconButton(
                      tooltip: l.commonClose,
                      style: IconButton.styleFrom(backgroundColor: t.sf2),
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      icon: Icon(LucideIcons.x, size: 20, color: t.ink),
                      onPressed: () => Navigator.maybePop(ctx),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                  children: [
                    for (final g in grades)
                      Builder(builder: (_) {
                        final isSel = g.id == selected;
                        final loc = gradeLabelL(l, g.id);
                        return Semantics(
                          button: true,
                          selected: isSel,
                          child: Material(
                            color: isSel ? t.soft.withValues(alpha: .6) : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => Navigator.pop(ctx, g.id),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 56),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          loc == g.id ? g.name : loc,
                                          style: tx.bodyLarge!.copyWith(
                                              color: isSel ? t.pr : t.ink, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500),
                                        ),
                                      ),
                                      if (isSel) const _Radio(selected: true),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
