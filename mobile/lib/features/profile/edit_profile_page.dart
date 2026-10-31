import 'package:flutter/material.dart';

import '../../core/academic_catalog.dart';
import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/platform/image_service.dart';
import '../../core/session.dart';
import '../../widgets/academic_pickers.dart';
import '../../widgets/bu.dart';
import '../media_crop/media_crop.dart';
import 'profil2_widgets.dart';

/// Profili düzenle (Stitch 48-4/5/6): avatar + "Fotoğrafı değiştir", ad soyad, hakkımda, bölüm/sınıf,
/// salt okunur kurumsal e-posta, e-posta anahtarı, sabit "Kaydet". Çıkarken kaydedilmemiş değişiklik sorulur.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.session, required this.profile, this.cropPhoto});

  final Session session;
  final Map<String, dynamic> profile;

  /// Test için: seç + 1:1 daire kırp işlemini değiştirir (kırpılmış bayt döner; null = vazgeçildi).
  /// Verilmezse [pickAndCrop] ile `CropSpec.profile` kullanılır.
  final CropPhotoPicker? cropPhoto;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  static const _bioMax = 300;

  late final _name = TextEditingController(text: widget.profile['displayName'] as String? ?? '');
  late final _bio = TextEditingController(text: widget.profile['bio'] as String? ?? '');
  late final AcademicCatalog _catalog = AcademicCatalog.of(widget.session);
  // Katalog dışı (serbest metin) eski değerler olduğu gibi gösterilir.
  late String? _faculty = _f0;
  late String? _department = _d0;
  late String? _grade = _g0;
  late bool _showEmail = widget.profile['showEmail'] == true;
  // Dil seçimi Ayarlar'a taşındı; mevcut değer olduğu gibi gönderilir.

  late final String _n0 = _name.text;
  late final String _b0 = _bio.text;
  late final String? _f0 = _nonEmpty(widget.profile['faculty'] as String?);
  late final String? _d0 = _nonEmpty(widget.profile['department'] as String?);
  late final String? _g0 = _gradeOf(widget.profile);
  late final bool _e0 = _showEmail;

  String? _nameError;
  String? _departmentError;
  bool _busy = false;
  bool _saved = false;
  bool _uploading = false;
  late String? _avatarUrl = widget.profile['avatarUrl'] as String?;
  bool _avatarChanged = false; // avatar anında sunucuda güncellenir; üst sayfa yenilensin
  final _images = ImageService();
  String? _error;
  String? _photoError;
  int _uploadSeq = 0; // "İptal": sonucu yok sayılan yüklemeyi ayırt eder

  bool get _hasFormErrors => _nameError != null || _departmentError != null || _photoError != null;

  static String? _nonEmpty(String? s) => (s == null || s.isEmpty) ? null : s;

  /// Sınıf kimliği: yeni `grade` alanı; yoksa eski sayısal `classYear` (1..6) kimliğe çevrilir.
  static String? _gradeOf(Map<String, dynamic> p) {
    final g = p['grade'];
    if (g is String && g.isNotEmpty) return g;
    if (g is num && g > 0) return g.toInt().toString();
    final y = (p['classYear'] as num?)?.toInt();
    return (y != null && y >= 1 && y <= 6) ? '$y' : null;
  }

  bool get _academicChanged => _faculty != _f0 || _department != _d0;

  bool get _dirty =>
      _name.text != _n0 || _bio.text != _b0 || _academicChanged || _grade != _g0 || _showEmail != _e0;

  @override
  void initState() {
    super.initState();
    // Başlangıç değerlerini ilk çerçeveden önce sabitle.
    _n0;
    _b0;
    _e0;
    _catalog.load();
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || _uploading) return;
    final l = context.l10n;
    String? nameErr;
    String? deptErr;
    if (_name.text.trim().length < 2) nameErr = l.profileNameMin;
    if ((_department ?? '').isEmpty) deptErr = l.profileDeptRequired;
    if (nameErr != null || deptErr != null) {
      setState(() {
        _nameError = nameErr;
        _departmentError = deptErr;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _nameError = null;
      _departmentError = null;
    });
    try {
      await widget.session.api.patch('/users/me', {
        'displayName': _name.text.trim(),
        // Akademik alanlar yalnızca değiştiyse gönderilir (serbest metin eski değerler korunur).
        if (_academicChanged) ...{'faculty': _faculty ?? '', 'department': _department ?? ''},
        if (_grade != _g0) 'grade': _grade ?? '',
        'bio': _bio.text.trim(),
        'showEmail': _showEmail,
        // `language` bilerek gönderilmez: PATCH kısmidir; açılış anındaki bayat dil sunucudaki güncel dili ezerdi.
      });
      _saved = true;
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorText(e);
        });
      }
    }
  }

  /// Çıkış onayı (Stitch 48-6): ortada kart, "Düzenlemeye devam et" (koyu) + "Vazgeç ve çık" (kırmızı yazı).
  Future<bool> _confirmDiscard() async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = ctx.bu;
        final tx = Theme.of(ctx).textTheme;
        final l = ctx.l10n;
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            decoration: BoxDecoration(color: t.sf3, borderRadius: BorderRadius.circular(BuRadius.xl)),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(
                child: ExcludeSemantics(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: t.bd, borderRadius: BuRadius.bPill),
                  ),
                ),
              ),
              Center(
                child: ExcludeSemantics(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.errorContainer, shape: BoxShape.circle),
                    // Dolu uyarı üçgeni (Lucide'de dolgulu varyant yok).
                    child: Icon(Icons.warning_rounded, size: 30, color: t.danger),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(l.profileDiscardTitle, textAlign: TextAlign.center, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
              ),
              const SizedBox(height: 8),
              Text(l.profileDiscardBody, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.45)),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const ValueKey('discard-keep'),
                onPressed: () => Navigator.pop(ctx, false),
                style: FilledButton.styleFrom(backgroundColor: t.ink, foregroundColor: t.bg, minimumSize: const Size(0, BuSize.button)),
                icon: const Icon(LucideIcons.pencil, size: 18),
                label: Text(l.profileKeepEditing),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                key: const ValueKey('discard-exit'),
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: t.sf2, foregroundColor: t.danger, minimumSize: const Size(0, BuSize.button)),
                icon: const Icon(LucideIcons.trash2, size: 18),
                label: Text(l.profileDiscardExit),
              ),
            ]),
          ),
        );
      },
    );
    return r == true;
  }

  // ---------------------------------------------------------------------------------------------------------------
  // Fotoğraf

  Widget _avatar(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return Column(children: [
      SizedBox(
        width: 104,
        height: 104,
        child: Stack(clipBehavior: Clip.none, children: [
          PositionedDirectional(
            start: 4,
            top: 4,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: t.sf, width: 3)),
              child: ClipOval(
                child: Stack(fit: StackFit.expand, children: [
                  BuAvatar(name: _name.text, url: _avatarUrl, size: 90),
                  if (_uploading)
                    ColoredBox(
                      color: t.scrim.withValues(alpha: .6),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(strokeWidth: 3, color: t.onMedia),
                        ),
                        const SizedBox(height: 4),
                        Text(l.profileUploading,
                            maxLines: 1,
                            style: Theme.of(context).textTheme.labelSmall!.copyWith(color: t.onMedia, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                ]),
              ),
            ),
          ),
          PositionedDirectional(
            end: 0,
            bottom: 0,
            child: Semantics(
              button: true,
              label: l.profileChangePhotoSemantic,
              excludeSemantics: true,
              child: GestureDetector(
                key: const ValueKey('avatar-camera'),
                onTap: _pickAvatar,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: t.pr, border: Border.all(color: t.bg, width: 3)),
                  child: Icon(LucideIcons.camera, size: 16, color: t.onPr),
                ),
              ),
            ),
          ),
        ]),
      ),
      if (_uploading || _photoError != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            _PhotoChip(
              key: const ValueKey('photo-change'),
              icon: LucideIcons.camera,
              label: l.p19PhotoChange,
              onTap: _uploading ? null : _pickAvatar,
            ),
            _PhotoChip(
              key: const ValueKey('photo-cancel'),
              icon: LucideIcons.x,
              label: l.p19Cancel,
              danger: true,
              onTap: _cancelPhoto,
            ),
          ]),
        )
      else
        InkWell(
          onTap: _pickAvatar,
          borderRadius: BuRadius.bXs,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Center(
              widthFactor: 1,
              child: Text(l.profileChangePhoto, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: t.pr)),
            ),
          ),
        ),
      if (_photoError != null)
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: P2PhotoError(_photoError!),
        ),
    ]);
  }

  Future<void> _pickAvatar() async {
    if (_uploading || _busy) return;
    final hasPhoto = _avatarUrl != null && _avatarUrl!.isNotEmpty;
    final choice = await showPhotoSourceSheet(context, removable: hasPhoto);
    if (choice == null || !mounted) return;
    if (choice == PhotoSource.remove) return _removeAvatar();
    await _uploadAvatar(choice == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery);
  }

  /// "İptal": bekleyen yüklemenin sonucu yok sayılır, hata temizlenir.
  void _cancelPhoto() => setState(() {
        _uploadSeq++;
        _uploading = false;
        _photoError = null;
      });

  Future<void> _uploadAvatar(ImageSource source) async {
    final seq = ++_uploadSeq;
    setState(() {
      _uploading = true;
      _error = null;
      _photoError = null;
    });
    try {
      // Seç -> 1:1 daire kırp -> doğrula/sıkıştır -> yükle.
      final crop = widget.cropPhoto;
      final bytes = crop != null
          ? await crop(source)
          : await pickAndCrop(context, CropSpec.profile(previewName: _name.text.trim()), source: source);
      if (seq != _uploadSeq) return;
      if (bytes == null) {
        if (mounted) setState(() => _uploading = false);
        return; // kullanıcı vazgeçti
      }
      final prepared = await _images.prepare(bytes, avatar: true);
      final r = await MultipartUploader(widget.session).upload('/users/me/avatar', prepared);
      if (!mounted || seq != _uploadSeq) return;
      setState(() {
        if (r is Map && r['avatarUrl'] is String) _avatarUrl = r['avatarUrl'] as String;
        widget.session.avatarUrl.value = _avatarUrl;
        _avatarChanged = true;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted || seq != _uploadSeq) return;
      setState(() {
        _uploading = false;
        _photoError = _uploadError(e);
      });
    }
  }

  Future<void> _removeAvatar() async {
    setState(() {
      _uploading = true;
      _error = null;
      _photoError = null;
    });
    try {
      await widget.session.api.delete('/users/me/avatar');
      if (!mounted) return;
      setState(() {
        _avatarUrl = null;
        widget.session.avatarUrl.value = null;
        _avatarChanged = true;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _photoError = errorText(e);
      });
    }
  }

  String _uploadError(Object e) {
    if (e is ImageException) {
      switch (e.code) {
        case 'TOO_LARGE':
          return context.l10n.profilePhotoTooLargeHint;
        case 'UNSUPPORTED_TYPE':
          return context.l10n.profilePhotoUnsupported;
        default:
          return context.l10n.profilePhotoUnreadable;
      }
    }
    if (e is ApiError && e.status == 413) return context.l10n.profilePhotoTooLarge;
    return errorText(e);
  }

  // ---------------------------------------------------------------------------------------------------------------
  // Seçiciler

  Future<void> _pickDepartment() async {
    if (_busy) return;
    if (_catalog.state == CatalogState.error) {
      _catalog.retry();
      return;
    }
    if (!_catalog.ready) return;
    final r = await showDepartmentPicker(context, catalog: _catalog, selectedFaculty: _faculty, selected: _department);
    if (r == null || !mounted) return;
    setState(() {
      // Bölüm seçilince fakülte otomatik dolar.
      _faculty = r.faculty.name;
      _department = r.name;
      _departmentError = null;
    });
  }

  Future<void> _pickGrade() async {
    if (_busy) return;
    if (_catalog.state == CatalogState.error) {
      _catalog.retry();
      return;
    }
    if (!_catalog.ready) return;
    final r = await showGradeSheet(context, grades: _catalog.grades, selected: _grade);
    if (r == null || !mounted) return;
    setState(() => _grade = r);
  }

  String? _gradeName(BuildContext context) {
    if ((_grade ?? '').isEmpty) return null;
    for (final g in _catalog.grades) {
      if (g.id == _grade) {
        final loc = gradeLabelL(context.l10n, g.id);
        return loc == g.id ? g.name : loc;
      }
    }
    return _grade;
  }

  // ---------------------------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final email = (widget.profile['email'] as String?) ?? widget.session.email ?? '';
    return PopScope(
      // Avatar anında sunucuya yazıldığından, değiştiyse üst sayfaya "true" ile dönülür.
      canPop: _saved || (!_dirty && !_avatarChanged),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (!_dirty || await _confirmDiscard()) {
          if (!mounted) return;
          _saved = true;
          nav.pop(_avatarChanged);
        }
      },
      child: Scaffold(
        backgroundColor: t.bg,
        body: Column(
          children: [
            BuHeader(title: l.profileEditTitle, onBack: () => Navigator.maybePop(context)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  if (_hasFormErrors) ...[
                    P2NoticeCard(
                      key: const ValueKey('edit-form-errors'),
                      title: l.p19FormErrTitle,
                      lines: [l.p19FormErrBody],
                      icon: LucideIcons.circleAlert,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_error != null) ...[P2NoticeCard(lines: [_error!]), const SizedBox(height: 12)],
                  _avatar(context),
                  const SizedBox(height: 12),
                  // Tek sütun, kart yok: alan başına tek etiket (tur 3).
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      P2FieldLabel(l.profileFullName),
                      _TextBox(
                        key: const ValueKey('edit-name'),
                        controller: _name,
                        maxLength: 80,
                        error: _nameError,
                        capitalization: TextCapitalization.words,
                        onChanged: (_) => setState(() => _nameError = null),
                      ),
                      const SizedBox(height: 16),
                      P2FieldLabel(
                        l.profileAbout,
                        trailing: Text('${_bio.text.characters.length}/$_bioMax',
                            style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w600, color: t.mut)),
                      ),
                      _TextBox(
                        key: const ValueKey('edit-bio'),
                        controller: _bio,
                        maxLength: _bioMax,
                        minLines: 3,
                        maxLines: 5,
                        hint: l.profileBioHint,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      ListenableBuilder(
                        listenable: _catalog,
                        builder: (context, _) {
                          final loading = _catalog.state == CatalogState.loading || _catalog.state == CatalogState.idle;
                          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            P2FieldLabel(l.pickDepartment),
                            _SelectBox(
                              key: const ValueKey('edit-department'),
                              text: _department == null
                                  ? null
                                  : _catalog.departmentLabel(_department, uiLocale(context), faculty: _faculty),
                              placeholder: loading ? l.pickLoading : l.pickSelectDepartment,
                              error: _departmentError,
                              onTap: _pickDepartment,
                            ),
                            const SizedBox(height: 16),
                            P2FieldLabel(l.pickGrade),
                            _SelectBox(
                              key: const ValueKey('edit-grade'),
                              text: _gradeName(context),
                              placeholder: l.pickSelectGrade,
                              onTap: _pickGrade,
                            ),
                          ]);
                        },
                      ),
                  ]),
                  const SizedBox(height: 16),
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      P2FieldLabel(
                        l.profil1CorpEmail,
                        trailing: P2Pill(text: l.profil2SecVerified),
                      ),
                      Semantics(
                        label: '${l.profil1CorpEmail}: $email',
                        excludeSemantics: true,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 52),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bMd),
                          child: Row(children: [
                            Expanded(
                              child: Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodyLarge!.copyWith(color: t.mut)),
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 14),
                      MergeSemantics(
                        child: InkWell(
                          onTap: () => setState(() => _showEmail = !_showEmail),
                          borderRadius: BuRadius.bSm,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(l.profileShowEmail, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
                                  const SizedBox(height: 2),
                                  Text(l.p19ShowEmailDesc, style: tx.bodySmall!.copyWith(color: t.mut)),
                                ]),
                              ),
                              const SizedBox(width: 12),
                              Switch(
                                key: const ValueKey('edit-show-email'),
                                value: _showEmail,
                                onChanged: (v) => setState(() => _showEmail = v),
                              ),
                            ]),
                          ),
                        ),
                      ),
                  ]),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(color: t.bg, border: Border(top: BorderSide(color: t.bd))),
              padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
              child: BuButton(
                key: const ValueKey('edit-save'),
                label: l.profileSave,
                busy: _busy,
                onPressed: (_busy || _uploading) ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fotoğraf hatası: kırmızı zeminli tek satır.
class P2PhotoError extends StatelessWidget {
  const P2PhotoError(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => P2NoticeCard(lines: [text], compact: true, icon: LucideIcons.imageOff);
}

/// Dolgulu (sf2) metin kutusu: odakta marka çerçevesi, hatada kırmızı çerçeve + uyarı simgesi + altında hata satırı.
class _TextBox extends StatelessWidget {
  const _TextBox({
    super.key,
    required this.controller,
    this.maxLength,
    this.minLines,
    this.maxLines = 1,
    this.hint,
    this.error,
    this.capitalization = TextCapitalization.none,
    this.onChanged,
  });

  final TextEditingController controller;
  final int? maxLength;
  final int? minLines;
  final int maxLines;
  final String? hint;
  final String? error;
  final TextCapitalization capitalization;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final hasError = error != null;
    OutlineInputBorder b(Color c, [double w = 0]) => OutlineInputBorder(
          borderRadius: BuRadius.bMd,
          borderSide: w == 0 ? BorderSide.none : BorderSide(color: c, width: w),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: controller,
        maxLength: maxLength,
        minLines: minLines,
        maxLines: maxLines,
        textCapitalization: capitalization,
        onChanged: onChanged,
        style: tx.bodyLarge!.copyWith(color: t.ink, height: 1.4),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: tx.bodyLarge!.copyWith(color: t.mut),
          counterText: '',
          filled: true,
          fillColor: hasError ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: .45) : t.sf2,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: b(t.sf2),
          enabledBorder: hasError ? b(t.danger, 1.5) : b(t.sf2),
          focusedBorder: b(hasError ? t.danger : t.pr, 2),
          suffixIcon: hasError ? Icon(LucideIcons.circleAlert, size: 18, color: t.danger) : null,
        ),
      ),
      if (hasError)
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, top: 6),
          child: Semantics(
            liveRegion: true,
            child: Row(children: [
              Icon(LucideIcons.circleAlert, size: 14, color: t.danger),
              const SizedBox(width: 6),
              Expanded(child: Text(error!, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w600, color: t.danger))),
            ]),
          ),
        ),
    ]);
  }
}

/// Açılır seçici görünümlü kutu (sf2 dolgu + aşağı ok).
class _SelectBox extends StatelessWidget {
  const _SelectBox({super.key, required this.text, required this.placeholder, required this.onTap, this.error});

  final String? text;
  final String placeholder;
  final String? error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final has = text != null && text!.isNotEmpty;
    final hasError = error != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(
        button: true,
        child: Material(
          color: hasError ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: .45) : t.sf2,
          borderRadius: BuRadius.bMd,
          child: InkWell(
            borderRadius: BuRadius.bMd,
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BuRadius.bMd,
                border: hasError ? Border.all(color: t.danger, width: 1.5) : null,
              ),
              child: Row(children: [
                Expanded(
                  child: Text(has ? text! : placeholder,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tx.bodyLarge!.copyWith(color: has ? t.ink : t.mut)),
                ),
                const SizedBox(width: 8),
                if (hasError) ...[Icon(LucideIcons.circleAlert, size: 18, color: t.danger), const SizedBox(width: 8)],
                Icon(LucideIcons.chevronDown, size: 18, color: t.mut),
              ]),
            ),
          ),
        ),
      ),
      if (hasError)
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, top: 6),
          child: Semantics(
            liveRegion: true,
            child: Row(children: [
              Icon(LucideIcons.circleAlert, size: 14, color: t.danger),
              const SizedBox(width: 6),
              Expanded(child: Text(error!, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w600, color: t.danger))),
            ]),
          ),
        ),
    ]);
  }
}

/// Fotoğraf çipi (Fotoğrafı değiştir / İptal): gri hap, 48 dp hedef.
class _PhotoChip extends StatelessWidget {
  const _PhotoChip({super.key, required this.icon, required this.label, required this.onTap, this.danger = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final fg = danger ? t.danger : t.ink;
    return Opacity(
      opacity: onTap == null ? .5 : 1,
      child: Material(
        color: t.sf2,
        borderRadius: BuRadius.bPill,
        child: InkWell(
          borderRadius: BuRadius.bPill,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 8),
                Text(label, style: Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: fg)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
