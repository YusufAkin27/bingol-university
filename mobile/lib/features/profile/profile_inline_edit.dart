import '../chat/emoji_presentation.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/academic_catalog.dart';
import '../../core/analytics.dart';
import '../../core/locale_controller.dart';
import '../../core/name_format.dart';
import '../../core/session.dart';
import '../../widgets/academic_pickers.dart';
import '../../widgets/bu.dart';

/// Profilim'deki SATIR İÇİ düzenleme: ayrı "Profili düzenle" sayfası yok; kimlik kartındaki her alan yerinde düzenlenir.
///
/// * Ad soyad ve Hakkımda: dokununca alanın yerinde metin kutusu açılır (klavye, sayaç, ✓ kaydet / ✕ vazgeç).
/// * Bölüm ve Sınıf: dokunulabilir çipler; mevcut seçici alt sayfa açılır, seçimle KAYDEDİLİR.
///
/// "E-postamı göster" anahtarı Ayarlar > Gizlilik ve veriler sayfasındadır (profil kartında yok).
///
/// Kayıt alan başınadır (kısmi `PATCH /users/me`), iyimser güncellenir; hata olursa eski değere dönülür ve toast gösterilir.
/// Tek anda tek alan düzenlenir; kayıt sürerken yeni düzenleme/kayıt başlamaz (çift istek yok).
class InlineProfileHero extends StatefulWidget {
  const InlineProfileHero({
    super.key,
    required this.session,
    required this.profile,
    required this.avatar,
    required this.onPatch,
  });

  final Session session;
  final Map<String, dynamic> profile;

  /// Üstteki dokunulabilir avatar (hızlı fotoğraf menüsü üst sayfada kalır).
  final Widget avatar;

  /// Alanlar profil yanıtına birleştirilir (iyimser güncelleme ve geri alma için de çağrılır).
  final void Function(Map<String, dynamic> patch) onPatch;

  @override
  State<InlineProfileHero> createState() => _InlineProfileHeroState();
}

enum _Field { name, bio }

class _InlineProfileHeroState extends State<InlineProfileHero> {
  static const _nameMax = 80;
  static const _bioMax = 300;

  late final AcademicCatalog _catalog = AcademicCatalog.of(widget.session);
  // Her alanın kendi denetleyicisi/odağı var: geçiş solarken eski kutu yenisiyle aynı odağı paylaşmaz.
  final _nameCtrl = EmojiTextEditingController();
  final _bioCtrl = EmojiTextEditingController();
  final _nameFocus = FocusNode();
  final _bioFocus = FocusNode();

  _Field? _editing;
  String? _error;

  /// Sürmekte olan kaydın alanı (name, bio, dept, grade); null = boşta.
  String? _busyKey;

  @override
  void initState() {
    super.initState();
    _catalog.load();
    _catalog.addListener(_onCatalog);
  }

  @override
  void dispose() {
    _catalog.removeListener(_onCatalog);
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _nameFocus.dispose();
    _bioFocus.dispose();
    super.dispose();
  }

  void _onCatalog() {
    if (mounted) setState(() {});
  }

  Map<String, dynamic> get _p => widget.profile;

  String _str(String k) => ((_p[k] as String?) ?? '').trim();

  String? get _grade {
    final g = _p['grade'];
    if (g is String && g.isNotEmpty) return g;
    if (g is num && g > 0) return g.toInt().toString();
    final y = (_p['classYear'] as num?)?.toInt();
    return (y != null && y >= 1 && y <= 6) ? '$y' : null;
  }

  TextEditingController _ctrlOf(_Field f) => f == _Field.name ? _nameCtrl : _bioCtrl;

  FocusNode _focusOf(_Field f) => f == _Field.name ? _nameFocus : _bioFocus;

  String _current(_Field f) => f == _Field.name ? _str('displayName') : _str('bio');

  // ---------------------------------------------------------------------------------------------------------------
  // Kayıt

  /// Alan başına kısmi PATCH; iyimser uygular, hata olursa eski değere döner. Başarıyı döndürür.
  Future<bool> _commit(String key, Map<String, dynamic> patch) async {
    if (_busyKey != null) return false;
    final old = {for (final k in patch.keys) k: _p[k]};
    setState(() => _busyKey = key);
    widget.onPatch(patch);
    try {
      await widget.session.api.patch('/users/me', patch);
      widget.session.api.invalidate('/users/me');
      if (patch.containsKey('displayName')) unawaited(widget.session.refreshName());
      Analytics.instance.action('profile_edit');
      if (mounted) setState(() => _busyKey = null);
      return true;
    } catch (e) {
      widget.onPatch(old);
      if (mounted) {
        setState(() => _busyKey = null);
        BuToast.show(context, errorText(e), kind: BuToastKind.error);
      }
      return false;
    }
  }

  // ---------------------------------------------------------------------------------------------------------------
  // Metin alanları (ad, hakkımda)

  Future<void> _startEdit(_Field f) async {
    if (_busyKey != null || _editing == f) return;
    // Başka alan düzenleniyorsa önce o kaydedilir (geçersizse yerinde kalır).
    if (_editing != null && !await _finish()) return;
    if (!mounted) return;
    setState(() {
      _editing = f;
      _error = null;
      _ctrlOf(f).value = TextEditingValue(text: _current(f), selection: TextSelection.collapsed(offset: _current(f).length));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editing == f) _focusOf(f).requestFocus();
    });
  }

  void _cancel() {
    if (_editing == null) return;
    _focusOf(_editing!).unfocus();
    setState(() {
      _editing = null;
      _error = null;
    });
  }

  /// Açık düzenlemeyi kaydeder. Düzenleme kapandıysa true; doğrulama/sunucu hatasında false (alan açık kalır).
  Future<bool> _finish() async {
    final f = _editing;
    if (f == null) return true;
    if (_busyKey != null) return false;
    final l = context.l10n;
    final value = _ctrlOf(f).text.trim();
    if (f == _Field.name && value.characters.length < 2) {
      setState(() => _error = l.profileNameMin);
      return false;
    }
    if (value == _current(f)) {
      _cancel();
      return true;
    }
    _focusOf(f).unfocus();
    setState(() {
      _editing = null;
      _error = null;
    });
    final ok = await _commit(f == _Field.name ? 'name' : 'bio', {f == _Field.name ? 'displayName' : 'bio': value});
    if (!ok && mounted && _editing == null) {
      // Eski değere dönüldü; yazılan metin kaybolmasın diye alan tekrar açılır.
      setState(() {
        _editing = f;
        _ctrlOf(f).value = TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length));
      });
    }
    return ok;
  }

  // ---------------------------------------------------------------------------------------------------------------
  // Seçiciler (bölüm, sınıf) ve anahtar

  Future<void> _pickDepartment() async {
    if (_busyKey != null) return;
    if (_editing != null && !await _finish()) return;
    if (!mounted) return;
    if (_catalog.state == CatalogState.error || _catalog.state == CatalogState.idle) await _catalog.retry();
    if (!mounted) return;
    if (!_catalog.ready) {
      final l = context.l10n;
      BuToast.show(context, _catalog.state == CatalogState.loading ? l.pickLoading : l.pickListFailed,
          kind: _catalog.state == CatalogState.loading ? BuToastKind.info : BuToastKind.error);
      return;
    }
    final dept = _str('department');
    final r = await showDepartmentPicker(context,
        catalog: _catalog, selectedFaculty: _str('faculty').isEmpty ? null : _str('faculty'), selected: dept.isEmpty ? null : dept);
    if (r == null || !mounted) return;
    if (r.name == dept && r.faculty.name == _str('faculty')) return;
    // Bölüm seçilince fakülte de birlikte gider.
    await _commit('dept', {'faculty': r.faculty.name, 'department': r.name});
  }

  Future<void> _pickGrade() async {
    if (_busyKey != null) return;
    if (_editing != null && !await _finish()) return;
    if (!mounted) return;
    final r = await showGradeSheet(context, grades: _catalog.grades, selected: _grade);
    if (r == null || !mounted || r == _grade) return;
    await _commit('grade', {'grade': r});
  }

  // ---------------------------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final name = _str('displayName');
    final facultyCanon = _str('faculty');
    final deptRaw = _str('department');
    final dept = deptRaw.isEmpty ? '' : context.departmentName(deptRaw, faculty: facultyCanon);
    final g = _grade;
    final grade = (g == null || g.isEmpty) ? '' : gradeLabelL(l, g);
    final bio = _str('bio');
    final dur = AppMotion.of(context, AppMotion.normal);

    return PopScope(
      canPop: _editing == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      // Kart YOK: avatar, büyük sade ad, bölüm/sınıf ve biyografi doğrudan sayfa zemininde (büyük bilgi kartı istenmiyor).
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(child: widget.avatar),
              const SizedBox(height: 12),
              _animated(
                dur,
                _editing == _Field.name
                    ? _TextEditor(
                        key: const ValueKey('inline-name-editor'),
                        fieldKey: const ValueKey('inline-name-field'),
                        controller: _nameCtrl,
                        focus: _nameFocus,
                        maxLength: _nameMax,
                        error: _error,
                        center: true,
                        capitalization: TextCapitalization.words,
                        formatters: const [NameCaseFormatter()],
                        hint: l.profileFullName,
                        onSave: _finish,
                        onCancel: _cancel,
                        onChanged: () => setState(() => _error = null),
                      )
                    : _ReadRow(
                        key: const ValueKey('inline-name'),
                        semantic: l.profileEditNameSemantic,
                        value: name,
                        saving: _busyKey == 'name',
                        onTap: () => _startEdit(_Field.name),
                        child: Text(name,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.displaySmall!.copyWith(color: t.ink, fontWeight: BuType.emphasisWeight)),
                      ),
              ),
              const SizedBox(height: 4),
              Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                _Chip(
                  key: const ValueKey('inline-department'),
                  semantic: l.profileEditDeptSemantic,
                  text: dept.isEmpty ? l.pickSelectDepartment : dept,
                  empty: dept.isEmpty,
                  saving: _busyKey == 'dept',
                  onTap: _pickDepartment,
                ),
                _Chip(
                  key: const ValueKey('inline-grade'),
                  semantic: l.profileEditGradeSemantic,
                  text: grade.isEmpty ? l.pickSelectGrade : grade,
                  empty: grade.isEmpty,
                  saving: _busyKey == 'grade',
                  onTap: _pickGrade,
                ),
              ]),
              const SizedBox(height: 8),
              _animated(
                dur,
                _editing == _Field.bio
                    ? _TextEditor(
                        key: const ValueKey('inline-bio-editor'),
                        fieldKey: const ValueKey('inline-bio-field'),
                        controller: _bioCtrl,
                        focus: _bioFocus,
                        maxLength: _bioMax,
                        minLines: 3,
                        maxLines: 6,
                        showCounter: true,
                        error: _error,
                        hint: l.profileBioHint,
                        onSave: _finish,
                        onCancel: _cancel,
                        onChanged: () => setState(() => _error = null),
                      )
                    : bio.isEmpty
                        ? _ReadRow(
                            key: const ValueKey('inline-bio-empty'),
                            semantic: l.profileEditBioSemantic,
                            saving: _busyKey == 'bio',
                            onTap: () => _startEdit(_Field.bio),
                            leading: BuIcons.plus,
                            child: Text(l.profileBioEmptyCta,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: 15, color: t.ink)),
                          )
                        : _ReadRow(
                            key: const ValueKey('inline-bio'),
                            semantic: l.profileEditBioSemantic,
                            value: bio,
                            saving: _busyKey == 'bio',
                            onTap: () => _startEdit(_Field.bio),
                            child: Text(bio,
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: 15, height: 1.4, color: t.mut)),
                          ),
              ),
            ]),
          ),
        ]),
    );
  }

  /// Okuma <-> düzenleme geçişi: yumuşak yükseklik + çapraz solma (azaltılmış harekette anlık).
  Widget _animated(Duration dur, Widget child) => AnimatedSize(
        duration: dur,
        curve: AppMotion.standard,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: dur,
          switchInCurve: AppMotion.enter,
          switchOutCurve: AppMotion.exit,
          layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topCenter, children: [...prev, if (cur != null) cur]),
          child: child,
        ),
      );
}

/// Kaydediliyor göstergesi: 16 dp ince halka (ekran okuyucuda "Kaydediliyor").
class _Saving extends StatelessWidget {
  const _Saving();

  @override
  Widget build(BuildContext context) => Semantics(
        label: context.l10n.profileSavingSemantic,
        liveRegion: true,
        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: context.bu.ink)),
      );
}

/// Okuma halindeki dokunulabilir alan: içerik + sağında ince kalem (düzenlenebilirlik ipucu); >= 44 dp.
class _ReadRow extends StatelessWidget {
  const _ReadRow({super.key, required this.semantic, required this.child, required this.onTap, this.value, this.saving = false, this.leading});

  final String semantic;
  final String? value;
  final Widget child;
  final VoidCallback onTap;
  final bool saving;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      container: true,
      button: true,
      label: semantic,
      value: value,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BuRadius.bMd,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (leading != null) ...[Icon(leading, size: 16, color: t.ink), const SizedBox(width: 6)],
              Flexible(child: child),
              const SizedBox(width: 8),
              if (saving) const _Saving() else if (leading == null) Icon(BuIcons.pencil, size: 15, color: t.mut),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Bölüm / Sınıf seçici: ince 1 dp çerçeve, 12 dp köşe (hap değil), sağda açılır ok; boşken "ekle" (artı) durumu.
class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.semantic, required this.text, required this.empty, required this.saving, required this.onTap});

  final String semantic;
  final String text;
  final bool empty;
  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      container: true,
      button: true,
      label: semantic,
      value: empty ? null : text,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        borderRadius: BuRadius.bControl,
        child: InkWell(
          onTap: onTap,
          borderRadius: BuRadius.bControl,
          child: Ink(
            decoration: BoxDecoration(borderRadius: BuRadius.bControl, border: Border.all(color: t.bd)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 12, 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (empty) ...[Icon(BuIcons.plus, size: 16, color: t.ink), const SizedBox(width: 6)],
                  Flexible(
                    child: Text(text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                            fontSize: 14, color: empty ? t.mut : t.ink)),
                  ),
                  const SizedBox(width: 6),
                  if (saving) const _Saving() else Icon(BuIcons.chevronDown, size: 16, color: t.mut),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Yerinde metin düzenleyici: ince çerçeveli kutu + altında (sayaç | hata) ve ✕ / ✓ düğmeleri (44 dp).
class _TextEditor extends StatelessWidget {
  const _TextEditor({
    super.key,
    required this.fieldKey,
    required this.controller,
    required this.focus,
    required this.maxLength,
    required this.onSave,
    required this.onCancel,
    required this.onChanged,
    this.minLines,
    this.maxLines = 1,
    this.hint,
    this.error,
    this.center = false,
    this.showCounter = false,
    this.capitalization = TextCapitalization.none,
    this.formatters = const [],
  });

  final Key fieldKey;
  final TextEditingController controller;
  final FocusNode focus;
  final int maxLength;
  final int? minLines;
  final int maxLines;
  final String? hint;
  final String? error;
  final bool center;
  final bool showCounter;
  final TextCapitalization capitalization;
  final List<TextInputFormatter> formatters;
  final Future<bool> Function() onSave;
  final VoidCallback onCancel;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final multi = maxLines > 1;
    final hasError = error != null;
    OutlineInputBorder b(Color c, double w) => OutlineInputBorder(borderRadius: BuRadius.bMd, borderSide: BorderSide(color: c, width: w));
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          key: fieldKey,
          controller: controller,
          focusNode: focus,
          maxLength: maxLength,
          minLines: minLines,
          maxLines: maxLines,
          textAlign: center ? TextAlign.center : TextAlign.start,
          textCapitalization: capitalization,
          inputFormatters: formatters,
          textInputAction: multi ? TextInputAction.newline : TextInputAction.done,
          keyboardType: multi ? TextInputType.multiline : TextInputType.name,
          scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
          onChanged: (_) => onChanged(),
          onSubmitted: multi ? null : (_) => onSave(),
          style: (center ? tx.headlineLarge! : tx.bodyLarge!).copyWith(color: t.ink, height: 1.35, fontWeight: center ? FontWeight.w400 : null),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: tx.bodyLarge!.copyWith(color: t.mut),
            counterText: '',
            isDense: true,
            filled: true,
            fillColor: t.sf,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: b(t.bdStrong, 1),
            enabledBorder: b(hasError ? t.danger : t.bdStrong, 1),
            focusedBorder: b(hasError ? t.danger : t.ink, 1.5),
          ),
        ),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: hasError
                ? Semantics(
                    liveRegion: true,
                    child: Text(error!, style: tx.labelMedium!.copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: t.danger)),
                  )
                : showCounter
                    ? ValueListenableBuilder<TextEditingValue>(
                        valueListenable: controller,
                        builder: (_, v, __) => Text('${v.text.characters.length}/$maxLength',
                            key: const ValueKey('inline-counter'),
                            style: tx.labelMedium!.copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: v.text.characters.length >= maxLength ? t.danger : t.mut)),
                      )
                    : const SizedBox.shrink(),
          ),
          _RoundBtn(
            key: const ValueKey('inline-cancel'),
            tooltip: l.commonCancel,
            icon: BuIcons.x,
            fg: t.ink,
            bg: t.sf2,
            onTap: onCancel,
          ),
          const SizedBox(width: 8),
          _RoundBtn(
            key: const ValueKey('inline-save'),
            tooltip: l.profileSave,
            icon: BuIcons.check,
            fg: t.onPr,
            bg: t.pr,
            onTap: () => onSave(),
          ),
        ]),
      ]),
    );
  }
}

/// 44 dp yuvarlak eylem düğmesi (✕ / ✓).
class _RoundBtn extends StatelessWidget {
  const _RoundBtn({super.key, required this.tooltip, required this.icon, required this.fg, required this.bg, required this.onTap});

  final String tooltip;
  final IconData icon;
  final Color fg;
  final Color bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Material(
            color: bg,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 20, color: fg)),
            ),
          ),
        ),
      );
}
