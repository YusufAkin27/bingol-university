import 'package:flutter/material.dart';

import '../../../core/academic_catalog.dart';
import '../../../core/locale_controller.dart';
import '../../../widgets/academic_pickers.dart';
import '../../../widgets/bu.dart';
import 'auth_ref.dart';

/// Kayıtta bölüm + sınıf seçimi (Stitch 02 adım 1): iki beyaz seçim kartı, sağda yuvarlak ok düğmesi.
/// Bölüm tam ekran, sınıf alt sayfa seçiciyle seçilir (profil düzenlemedeki ortak [AcademicFields] aynı seçicileri kullanır).
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
    final r = await showDepartmentPicker(context, catalog: catalog, selectedFaculty: faculty, selected: department);
    if (r == null) return;
    // Bölüm seçilince fakülte otomatik dolar.
    onChanged(r.faculty.name, r.name, grade);
  }

  Future<void> _pickGrade(BuildContext context) async {
    if (!_openable()) return;
    final r = await showGradeSheet(context, grades: catalog.grades, selected: grade);
    if (r == null) return;
    onChanged(faculty, department, r);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: catalog,
      builder: (context, _) {
        final loading = catalog.state == CatalogState.loading || catalog.state == CatalogState.idle;
        final failed = catalog.state == CatalogState.error;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SelectCard(
              label: l.pickDepartment,
              value: department == null ? null : catalog.departmentLabel(department, uiLocale(context), faculty: faculty),
              placeholder: loading ? l.pickLoading : l.pickSelectDepartment,
              error: departmentError,
              onTap: enabled ? () => _pickDepartment(context) : null,
            ),
            if (failed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(l.pickListFailed, style: tx.bodySmall!.copyWith(color: t.danger))),
                    RefLink(label: l.pickRetry, onPressed: catalog.retry),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            _SelectCard(
              label: l.pickGrade,
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

/// Seçim kartı: küçük etiket üstte, değer altta; sağda yuvarlak aşağı ok düğmesi.
class _SelectCard extends StatelessWidget {
  const _SelectCard({required this.label, required this.value, required this.placeholder, required this.onTap, this.error});

  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback? onTap;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final has = value != null && value!.isNotEmpty;
    final hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: label,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: t.sf,
              borderRadius: BorderRadius.circular(20),
              boxShadow: BuElevation.of(context, 1),
              border: hasError ? Border.all(color: t.danger.withValues(alpha: .6), width: 1.5) : null,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 72),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 14, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(label, style: tx.bodySmall!.copyWith(color: hasError ? t.danger : t.mut, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 2),
                              Text(
                                has ? value! : placeholder,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: tx.bodyLarge!.copyWith(color: has ? t.ink : t.mut, fontWeight: has ? FontWeight.w600 : FontWeight.w400),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle),
                          child: Icon(LucideIcons.chevronDown, size: 18, color: t.ink),
                        ),
                      ],
                    ),
                  ),
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
                  padding: const EdgeInsetsDirectional.only(top: 8, start: 4),
                  child: Row(
                    children: [
                      Icon(LucideIcons.circleAlert, size: 16, color: t.danger),
                      const SizedBox(width: 8),
                      Expanded(child: Text(error!, style: tx.bodyMedium!.copyWith(color: t.danger, fontWeight: FontWeight.w500))),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
