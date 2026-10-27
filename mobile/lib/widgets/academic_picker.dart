import 'package:flutter/material.dart';

import '../core/academic_catalog.dart';
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
  final String? facultyError;
  final String? departmentError;
  final String? gradeError;
  final bool enabled;

  Future<void> _pickFaculty(BuildContext context) async {
    if (!_openable(context)) return;
    final r = await Navigator.push<AcademicFaculty>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FacultyPicker(catalog: catalog, selected: faculty),
      ),
    );
    if (r == null) return;
    if (r.name == faculty) return;
    // Seçilen fakülteyle uyuşmayan bölüm temizlenir.
    final d = catalog.departmentByName(department, faculty: r);
    onChanged(r.name, d?.name, grade);
  }

  Future<void> _pickDepartment(BuildContext context) async {
    if (!_openable(context)) return;
    final r = await Navigator.push<AcademicDepartment>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _DepartmentPicker(
          catalog: catalog,
          faculty: catalog.facultyByName(faculty),
          selected: department,
        ),
      ),
    );
    if (r == null) return;
    // Bölüm seçilince fakülte otomatik dolar.
    onChanged(r.faculty.name, r.name, grade);
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
            const _FieldLabel('Fakülte'),
            _SelectBox(
              text: faculty,
              placeholder: loading ? 'Yükleniyor…' : 'Fakülte seçin',
              error: facultyError != null,
              onTap: enabled ? () => _pickFaculty(context) : null,
            ),
            if (facultyError != null) _FieldError(facultyError!),
            const SizedBox(height: 14),
            const _FieldLabel('Bölüm'),
            _SelectBox(
              text: department,
              placeholder: loading ? 'Yükleniyor…' : 'Bölüm seçin',
              error: departmentError != null,
              onTap: enabled ? () => _pickDepartment(context) : null,
            ),
            if (departmentError != null) _FieldError(departmentError!),
            if (failed) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text('Fakülte ve bölüm listesi yüklenemedi.',
                        style: BuType.caption.copyWith(color: t.danger)),
                  ),
                  TextButton(onPressed: catalog.retry, child: const Text('Yeniden dene')),
                ],
              ),
            ],
            const SizedBox(height: 14),
            const _FieldLabel('Sınıf'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in gradeOptions)
                  BuChip(
                    label: g.name,
                    selected: g.id == grade,
                    onTap: enabled ? () => onChanged(faculty, department, g.id) : null,
                  ),
              ],
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
                Icon(LucideIcons.chevronDown, size: 18, color: t.mut),
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
    this.header,
  });

  final String title;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Widget? header;

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
            child: BuSearchField(hint: 'Ara', controller: controller, onChanged: onChanged),
          ),
          if (header != null) header!,
          Expanded(
            child: itemCount == 0
                ? Center(child: Text('Sonuç bulunamadı.', style: BuType.body.copyWith(color: t.mut)))
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
            if (selected) Icon(LucideIcons.check, size: 20, color: t.pr),
          ],
        ),
      ),
    );
  }
}

class _FacultyPicker extends StatefulWidget {
  const _FacultyPicker({required this.catalog, required this.selected});

  final AcademicCatalog catalog;
  final String? selected;

  @override
  State<_FacultyPicker> createState() => _FacultyPickerState();
}

class _FacultyPickerState extends State<_FacultyPicker> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.catalog.searchFaculties(_q.text);
    final sel = widget.selected == null ? null : foldTr(widget.selected!);
    return _SearchScaffold(
      title: 'Fakülte',
      controller: _q,
      onChanged: (_) => setState(() {}),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final f = items[i];
        return _PickRow(
          title: f.name,
          subtitle: '${f.departments.length} bölüm',
          selected: sel == foldTr(f.name),
          onTap: () => Navigator.pop(context, f),
        );
      },
    );
  }
}

class _DepartmentPicker extends StatefulWidget {
  const _DepartmentPicker({required this.catalog, required this.faculty, required this.selected});

  final AcademicCatalog catalog;
  final AcademicFaculty? faculty;
  final String? selected;

  @override
  State<_DepartmentPicker> createState() => _DepartmentPickerState();
}

class _DepartmentPickerState extends State<_DepartmentPicker> {
  final _q = TextEditingController();
  late bool _all = widget.faculty == null;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final scoped = widget.faculty != null && !_all;
    final items = widget.catalog.searchDepartments(_q.text, faculty: scoped ? widget.faculty : null);
    final sel = widget.selected == null ? null : foldTr(widget.selected!);
    return _SearchScaffold(
      title: 'Bölüm',
      controller: _q,
      onChanged: (_) => setState(() {}),
      itemCount: items.length,
      header: widget.faculty == null
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Tüm bölümlerde ara', style: BuType.label.copyWith(color: t.mut)),
                  ),
                  Switch(
                    value: _all,
                    onChanged: (v) => setState(() => _all = v),
                    activeThumbColor: Colors.white,
                    activeTrackColor: t.pr,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: t.sf2,
                    trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                  ),
                ],
              ),
            ),
      itemBuilder: (_, i) {
        final d = items[i];
        return _PickRow(
          title: d.name,
          subtitle: scoped ? null : d.faculty.name,
          selected: sel == foldTr(d.name),
          onTap: () => Navigator.pop(context, d),
        );
      },
    );
  }
}
