import 'package:flutter/material.dart';

import '../core/academic_catalog.dart';
import '../core/locale_controller.dart';
import '../core/theme.dart';
import '../core/typography.dart';
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
    final r = await Navigator.push<AcademicDepartment>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _DepartmentPicker(
          catalog: catalog,
          selectedFaculty: faculty,
          selected: department,
        ),
      ),
    );
    if (r == null) return;
    // Bölüm seçilince fakülte otomatik dolar.
    onChanged(r.faculty.name, r.name, grade);
  }

  Future<void> _pickGrade(BuildContext context) async {
    if (!_openable(context)) return;
    final r = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _GradePicker(grades: catalog.grades, selected: grade),
      ),
    );
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
              text: department,
              placeholder: loading ? context.l10n.pickLoading : context.l10n.pickSelectDepartment,
              error: departmentError != null,
              onTap: enabled ? () => _pickDepartment(context) : null,
            ),
            if (departmentError != null) _FieldError(departmentError!),
            // Fakülte seçilemez: bölümden otomatik gelir (dokunulamaz bilgi satırı).
            if ((faculty ?? '').isNotEmpty) _FacultyInfo(faculty!),
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

/// Aranabilir tam ekran liste iskeleti.
class _SearchScaffold extends StatelessWidget {
  const _SearchScaffold({
    required this.title,
    required this.controller,
    required this.onChanged,
    required this.itemCount,
    required this.itemBuilder,
  });

  final String title;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(title: title, onBack: () => Navigator.maybePop(context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: BuSearchField(hint: context.l10n.pickSearch, controller: controller, onChanged: onChanged),
          ),
          Expanded(
            child: itemCount == 0
                ? Center(child: Text(context.l10n.pickNoResults, style: BuType.body.copyWith(color: t.mut)))
                : ListView.builder(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: itemCount,
                    itemBuilder: itemBuilder,
                  ),
          ),
        ],
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({required this.title, this.subtitle, required this.selected, required this.onTap});

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.bd.withValues(alpha: 0.5)))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: BuType.bodyStrong.copyWith(color: selected ? t.pr : t.ink)),
                  if (subtitle != null)
                    Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BuType.caption.copyWith(color: t.mut)),
                ],
              ),
            ),
            if (selected) Icon(LucideIcons.check, size: 18, color: t.pr),
          ],
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

class _DepartmentPicker extends StatefulWidget {
  const _DepartmentPicker({required this.catalog, required this.selectedFaculty, required this.selected});

  final AcademicCatalog catalog;
  final String? selectedFaculty;
  final String? selected;

  @override
  State<_DepartmentPicker> createState() => _DepartmentPickerState();
}

class _DepartmentPickerState extends State<_DepartmentPicker> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tüm bölümler (her fakültedeki ayrı satır); yazdıkça aksan duyarsız süzülür.
    final items = widget.catalog.searchDepartments(_q.text);
    final sel = widget.selected == null ? null : foldTr(widget.selected!);
    final selF = widget.selectedFaculty == null ? null : foldTr(widget.selectedFaculty!);
    return _SearchScaffold(
      title: context.l10n.pickDepartment,
      controller: _q,
      onChanged: (_) => setState(() {}),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final d = items[i];
        return _PickRow(
          title: d.name,
          subtitle: d.faculty.name,
          selected: sel == foldTr(d.name) && (selF == null || selF == foldTr(d.faculty.name)),
          onTap: () => Navigator.pop(context, d),
        );
      },
    );
  }
}

/// Sınıf seçimi: kısa liste (arama yok), bölüm seçicisiyle aynı satır görünümü.
class _GradePicker extends StatelessWidget {
  const _GradePicker({required this.grades, required this.selected});

  final List<AcademicGrade> grades;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(title: context.l10n.pickGrade, onBack: () => Navigator.maybePop(context)),
          Expanded(
            child: ListView.builder(
              itemCount: grades.length,
              itemBuilder: (_, i) => _PickRow(
                title: () {
                  final loc = gradeLabelL(context.l10n, grades[i].id);
                  return loc == grades[i].id ? grades[i].name : loc;
                }(),
                selected: grades[i].id == selected,
                onTap: () => Navigator.pop(context, grades[i].id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
