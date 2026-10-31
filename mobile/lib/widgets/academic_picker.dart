import 'package:flutter/material.dart';

import '../core/academic_catalog.dart';
import '../core/locale_controller.dart';
import '../core/theme.dart';
import '../core/typography.dart';
import 'academic_pickers.dart';
import 'bu_widgets.dart';

/// Fakülte, bölüm ve sınıf seçimi. Fakülte/bölüm adları serbest metin olabilir (katalogda olmayan eski kayıtlar
/// olduğu gibi gösterilir). Değişiklikler [onChanged] ile bildirilir; durum üst widget'ta tutulur.
class AcademicFields extends StatelessWidget {
  const AcademicFields({
    super.key,
    required this.catalog,
    required this.faculty,
    required this.department,
    required this.grade,
    required this.onChanged,
    this.facultyError,
    this.departmentError,
    this.gradeError,
    this.enabled = true,
  });

  final AcademicCatalog catalog;
  final String? faculty;
  final String? department;

  /// Sınıf kimliği (PREP, 1..6, MASTER, PHD).
  final String? grade;
  final void Function(String? faculty, String? department, String? grade) onChanged;

  /// Eski imza uyumu için korunur; fakülte artık seçilmediğinden gösterilmez.
  final String? facultyError;
  final String? departmentError;
  final String? gradeError;
  final bool enabled;

  String? _gradeName(BuildContext context, List<AcademicGrade> options) {
    if ((grade ?? '').isEmpty) return null;
    for (final g in options) {
      if (g.id == grade) {
        final loc = gradeLabelL(context.l10n, g.id);
        return loc == g.id ? g.name : loc;
      }
    }
    return grade;
  }

  Future<void> _pickDepartment(BuildContext context) async {
    if (!_openable(context)) return;
    final r = await showDepartmentPicker(context, catalog: catalog, selectedFaculty: faculty, selected: department);
    if (r == null) return;
    // Bölüm seçilince fakülte otomatik dolar.
    onChanged(r.faculty.name, r.name, grade);
  }

  Future<void> _pickGrade(BuildContext context) async {
    if (!_openable(context)) return;
    final r = await showGradeSheet(context, grades: catalog.grades, selected: grade);
    if (r == null) return;
    onChanged(faculty, department, r);
  }

  bool _openable(BuildContext context) {
    if (!enabled) return false;
    if (catalog.state == CatalogState.error) {
      catalog.retry();
      return false;
    }
    return catalog.ready;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return ListenableBuilder(
      listenable: catalog,
      builder: (context, _) {
        final loading = catalog.state == CatalogState.loading || catalog.state == CatalogState.idle;
        final failed = catalog.state == CatalogState.error;
        final gradeOptions = catalog.grades;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FieldLabel(context.l10n.pickDepartment),
            _SelectBox(
              text: department == null
                  ? null
                  : catalog.departmentLabel(department, uiLocale(context), faculty: faculty),
              placeholder: loading ? context.l10n.pickLoading : context.l10n.pickSelectDepartment,
              error: departmentError != null,
              onTap: enabled ? () => _pickDepartment(context) : null,
            ),
            if (departmentError != null) _FieldError(departmentError!),
            // Fakülte seçilemez: bölümden otomatik gelir (dokunulamaz bilgi satırı).
            if ((faculty ?? '').isNotEmpty) _FacultyInfo(catalog.facultyLabel(faculty, uiLocale(context))),
            if (failed) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(context.l10n.pickListFailed,
                        style: BuType.caption.copyWith(color: t.danger)),
                  ),
                  TextButton(onPressed: catalog.retry, child: Text(context.l10n.pickRetry)),
                ],
              ),
            ],
            const SizedBox(height: 14),
            _FieldLabel(context.l10n.pickGrade),
            _SelectBox(
              text: _gradeName(context, gradeOptions),
              placeholder: context.l10n.pickSelectGrade,
              error: gradeError != null,
              onTap: enabled ? () => _pickGrade(context) : null,
            ),
            if (gradeError != null) _FieldError(gradeError!),
          ],
        );
      },
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: BuType.label.copyWith(color: context.bu.mut)),
      );
}

class _FieldError extends StatelessWidget {
  const _FieldError(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Text(text, style: BuType.caption.copyWith(color: context.bu.danger)),
      );
}

class _SelectBox extends StatelessWidget {
  const _SelectBox({required this.text, required this.placeholder, required this.onTap, this.error = false});

  final String? text;
  final String placeholder;
  final VoidCallback? onTap;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final has = text != null && text!.isNotEmpty;
    return Semantics(
      button: true,
      child: Material(
        color: t.sf,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: error ? t.danger : t.bd),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    has ? text! : placeholder,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: (has ? BuType.bodyStrong : BuType.body).copyWith(color: has ? t.ink : t.mut),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(LucideIcons.chevronDown, size: 16, color: t.mut),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FacultyInfo extends StatelessWidget {
  const _FacultyInfo(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
      child: Row(
        children: [
          Icon(LucideIcons.building2, size: 12.5, color: t.mut),
          const SizedBox(width: 6),
          Expanded(child: Text(name, style: BuType.caption.copyWith(color: t.mut))),
        ],
      ),
    );
  }
}
