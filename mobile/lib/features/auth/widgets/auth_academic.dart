import 'package:flutter/material.dart';

import '../../../core/academic_catalog.dart';
import '../../../core/locale_controller.dart';
import '../../../core/theme.dart';
import '../../../core/typography.dart';
import '../../../widgets/bu_widgets.dart';
import 'auth_controls.dart';
import 'auth_fields.dart';
import 'auth_sheets.dart';

/// Kayıtta bölüm + sınıf seçimi (profil düzenleme ekranındaki ortak [AcademicFields]'e dokunmaz).
/// Seçiciler aranabilir, sürüklenebilir alt sayfalardır; bölüm seçilince fakülte rozet olarak belirir.
class AuthAcademicFields extends StatelessWidget {
  const AuthAcademicFields({
    super.key,
    required this.catalog,
    required this.faculty,
    required this.department,
    required this.grade,
    required this.onChanged,
    this.departmentError,
    this.gradeError,
    this.enabled = true,
  });

  final AcademicCatalog catalog;
  final String? faculty;
  final String? department;
  final String? grade;
  final void Function(String? faculty, String? department, String? grade) onChanged;
  final String? departmentError;
  final String? gradeError;
  final bool enabled;

  String? _gradeName(BuildContext context) {
    if ((grade ?? '').isEmpty) return null;
    for (final g in catalog.grades) {
      if (g.id == grade) {
        final loc = gradeLabelL(context.l10n, g.id);
        return loc == g.id ? g.name : loc;
      }
    }
    return grade;
  }

  bool _openable() {
    if (!enabled) return false;
    if (catalog.state == CatalogState.error) {
      catalog.retry();
      return false;
    }
    return catalog.ready;
  }

  Future<void> _pickDepartment(BuildContext context) async {
    if (!_openable()) return;
    final sel = department == null ? null : foldTr(department!);
    final selF = faculty == null ? null : foldTr(faculty!);
    final r = await showAuthPickerSheet<AcademicDepartment>(
      context,
      title: context.l10n.pickDepartment,
      itemsFor: (q) => [
        for (final d in catalog.searchDepartments(q)) AuthPickerItem(d, d.name, subtitle: d.faculty.name),
      ],
      isSelected: (d) => sel == foldTr(d.name) && (selF == null || selF == foldTr(d.faculty.name)),
    );
    if (r == null) return;
    // Bölüm seçilince fakülte otomatik dolar.
    onChanged(r.faculty.name, r.name, grade);
  }

  Future<void> _pickGrade(BuildContext context) async {
    if (!_openable()) return;
    final l = context.l10n;
    final r = await showAuthPickerSheet<String>(
      context,
      title: l.pickGrade,
      searchable: false,
      itemsFor: (_) => [
        for (final g in catalog.grades)
          AuthPickerItem(g.id, () {
            final loc = gradeLabelL(l, g.id);
            return loc == g.id ? g.name : loc;
          }()),
      ],
      isSelected: (v) => v == grade,
    );
    if (r == null) return;
    onChanged(faculty, department, r);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return ListenableBuilder(
      listenable: catalog,
      builder: (context, _) {
        final loading = catalog.state == CatalogState.loading || catalog.state == CatalogState.idle;
        final failed = catalog.state == CatalogState.error;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AuthSelect(
              label: l.pickDepartment,
              icon: LucideIcons.graduationCap,
              value: department,
              placeholder: loading ? l.pickLoading : l.pickSelectDepartment,
              error: departmentError,
              onTap: enabled ? () => _pickDepartment(context) : null,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: (faculty ?? '').isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(999)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.building2, size: 14, color: t.onSoft),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(faculty!,
                                    style: BuType.label.copyWith(color: t.onSoft, fontSize: 12.5, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            if (failed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(l.pickListFailed, style: BuType.caption.copyWith(color: t.danger, fontSize: 12.5))),
                    AuthTextAction(label: l.pickRetry, onPressed: catalog.retry),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            _AuthSelect(
              label: l.pickGrade,
              icon: LucideIcons.layers,
              value: _gradeName(context),
              placeholder: l.pickSelectGrade,
              error: gradeError,
              onTap: enabled ? () => _pickGrade(context) : null,
            ),
          ],
        );
      },
    );
  }
}

/// Seçim kutusu: alanlarla aynı görünüm; değer varsa küçük etiket üstte, değer altta.
class _AuthSelect extends StatelessWidget {
  const _AuthSelect({
    required this.label,
    required this.icon,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.error,
  });

  final String label;
  final IconData icon;
  final String? value;
  final String placeholder;
  final VoidCallback? onTap;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final has = value != null && value!.isNotEmpty;
    final hasError = error != null;
    final border = hasError ? t.danger : (has ? t.ink.withValues(alpha: .25) : t.bd);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          child: Material(
            color: t.sf,
            borderRadius: BorderRadius.circular(kAuthRadius),
            child: InkWell(
              borderRadius: BorderRadius.circular(kAuthRadius),
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 14, 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(kAuthRadius),
                  border: Border.all(color: border, width: hasError ? 1.4 : 1),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: hasError ? t.danger : (has ? t.pr : t.mut)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (has)
                            Text(label, style: BuType.label.copyWith(color: t.mut, fontSize: 12.5, fontWeight: FontWeight.w600)),
                          Text(
                            has ? value! : placeholder,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: has
                                ? BuType.bodyStrong.copyWith(color: t.ink, fontSize: 16, fontWeight: FontWeight.w600)
                                : BuType.body.copyWith(color: t.mut, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(LucideIcons.chevronDown, size: 18, color: t.mut),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: hasError
              ? Padding(
                  padding: const EdgeInsetsDirectional.only(top: 6, start: 6),
                  child: Text(error!, style: BuType.caption.copyWith(color: t.danger, fontSize: 12.5, fontWeight: FontWeight.w500)),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
