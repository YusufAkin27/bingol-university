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
            const SizedBox(height: 24),
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

/// Seçim alanı (çizgili): küçük etiket üstte, iri değer altta, ince alt çizgi, sağda aşağı ok.
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
        Text(label, style: tx.labelLarge!.copyWith(color: hasError ? t.danger : t.mut, fontWeight: FontWeight.w400)),
        Semantics(
          button: true,
          label: label,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Container(
                  alignment: AlignmentDirectional.centerStart,
                  padding: const EdgeInsetsDirectional.only(top: 10, bottom: 10),
                  // Çizgili alan (giriş ile aynı dil): kutu yok, altta ince çizgi; hatada danger.
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: hasError ? t.danger : t.bdStrong, width: hasError ? 1.5 : 1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          has ? value! : placeholder,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tx.titleLarge!.copyWith(color: has ? t.ink : t.mutSoft, fontWeight: has ? FontWeight.w400 : FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(BuIcons.chevronDown, size: 22, color: t.mut),
                    ],
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
                  child: Text(error!, style: tx.bodySmall!.copyWith(color: t.danger, fontWeight: FontWeight.w500)),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
