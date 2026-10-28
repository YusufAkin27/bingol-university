import 'package:flutter/material.dart';

import '../../core/academic_catalog.dart';
import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../widgets/academic_picker.dart';
import '../../core/platform/image_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../auth/auth_widgets.dart';
import 'profil_widgets.dart';
import '../../core/typography.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.session, required this.profile});

  final Session session;
  final Map<String, dynamic> profile;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile['displayName'] as String? ?? '');
  late final _bio = TextEditingController(text: widget.profile['bio'] as String? ?? '');
  late final AcademicCatalog _catalog = AcademicCatalog.of(widget.session);
  // Katalog dışı (serbest metin) eski değerler olduğu gibi gösterilir.
  late String? _faculty = _f0;
  late String? _department = _d0;
  late String? _grade = _g0;
  late bool _showEmail = widget.profile['showEmail'] == true;
  // Dil seçimi Ayarlar'a taşındı; mevcut değer olduğu gibi gönderilir.
  late final String _language = (widget.profile['language'] as String?) ?? 'tr';

  late final String _n0 = _name.text;
  late final String _b0 = _bio.text;
  late final String? _f0 = _nonEmpty(widget.profile['faculty'] as String?);
  late final String? _d0 = _nonEmpty(widget.profile['department'] as String?);
  late final String? _g0 = _gradeOf(widget.profile);
  late final bool _e0 = _showEmail;

  String? _departmentError;
  bool _busy = false;
  bool _saved = false;
  bool _uploading = false;
  late String? _avatarUrl = widget.profile['avatarUrl'] as String?;
  bool _avatarChanged = false; // avatar anında sunucuda güncellenir; üst sayfa yenilensin
  final _images = ImageService();
  String? _error;

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
      _name.text != _n0 ||
      _bio.text != _b0 ||
      _academicChanged ||
      _grade != _g0 ||
      _showEmail != _e0;

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
    if (_busy || !_form.currentState!.validate()) return;
    if (_academicChanged && ((_faculty ?? '').isEmpty || (_department ?? '').isEmpty)) {
      setState(() => _departmentError = context.l10n.profileDeptRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
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
        'language': _language,
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

  Future<bool> _confirmDiscard() async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.profileDiscardTitle),
        content: Text(ctx.l10n.profileDiscardBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.profileKeepEditing)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.l10n.profileDiscardExit)),
        ],
      ),
    );
    return r == true;
  }

  InputDecoration _deco(BuildContext context, {String? hint}) {
    final bu = context.bu;
    OutlineInputBorder b(Color c) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c, width: 1.5));
    return InputDecoration(
      hintText: hint,
      hintStyle: BuType.body.copyWith(color: bu.mut),
      counterText: '',
      filled: true,
      fillColor: bu.sf,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: b(bu.bd),
      enabledBorder: b(bu.bd),
      focusedBorder: b(bu.pr),
      disabledBorder: b(bu.bd),
      errorBorder: b(bu.danger),
      focusedErrorBorder: b(bu.danger),
    );
  }

  Widget _label(String t) {
    final bu = context.bu;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
      child: Text(t,
          style: BuType.label.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: bu.ink)),
    );
  }

  Widget _avatar() {
    final bu = context.bu;
    final url = fileUrl(_avatarUrl);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final initials = Container(
      width: 70,
      height: 70,
      alignment: Alignment.center,
      color: bu.soft,
      child: Text(
        initialsOf(_name.text),
        style: BuType.display.copyWith(fontSize: 24, color: dark ? bu.onSoft : bu.pr),
      ),
    );
    final hasPhoto = _avatarUrl != null && _avatarUrl!.isNotEmpty;
    return Row(
      children: [
        SizedBox(
          width: 76,
          height: 76,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: bu.sf, width: 3),
                  boxShadow: dark
                      ? null
                      : const [
                          BoxShadow(color: Color(0x59171E33), blurRadius: 24, offset: Offset(0, 10), spreadRadius: -12)
                        ],
                ),
                child: ClipOval(
                  child: url == null
                      ? initials
                      : Image.network(url,
                          width: 70, height: 70, fit: BoxFit.cover, errorBuilder: (_, __, ___) => initials),
                ),
              ),
              if (_uploading)
                Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black45),
                  child: const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                    ),
                  ),
                ),
              PositionedDirectional(
                end: -8,
                bottom: -8,
                child: Semantics(
                  button: true,
                  label: context.l10n.profileChangePhotoSemantic,
                  child: GestureDetector(
                    onTap: _pickAvatar,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: bu.pr,
                        border: Border.all(color: bu.bg, width: 3),
                      ),
                      child: Icon(LucideIcons.camera, size: 18, color: bu.onPr),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: _pickAvatar,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(_uploading ? context.l10n.profileUploading : context.l10n.profileChangePhoto,
                        style: BuType.bodyStrong.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: bu.pr)),
                  ),
                ),
              ),
              if (hasPhoto)
                InkWell(
                  onTap: (_uploading || _busy) ? null : _removeAvatar,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(context.l10n.profil1Remove,
                          style: BuType.bodyStrong.copyWith(fontSize: 13, color: bu.mut)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickAvatar() async {
    if (_uploading || _busy) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.bu.sf,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final bu = ctx.bu;
        Widget row(IconData icon, String label, String value, {bool danger = false}) => ListTile(
              leading: Icon(icon, color: danger ? bu.danger : bu.ink),
              title: Text(label,
                  style: BuType.bodyStrong.copyWith(color: danger ? bu.danger : bu.ink)),
              onTap: () => Navigator.pop(ctx, value),
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: bu.bd, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 8),
              row(LucideIcons.image, ctx.l10n.profilePickGallery, 'gallery'),
              row(LucideIcons.camera, ctx.l10n.profileTakePhoto, 'camera'),
              if (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                row(LucideIcons.trash2, ctx.l10n.profileRemovePhoto, 'remove', danger: true),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (choice == null || !mounted) return;
    if (choice == 'remove') return _removeAvatar();
    await _uploadAvatar(choice == 'camera' ? ImageSource.camera : ImageSource.gallery);
  }

  Future<void> _uploadAvatar(ImageSource source) async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final prepared = await _images.pickPrepared(source, avatar: true);
      if (prepared == null) {
        if (mounted) setState(() => _uploading = false);
        return; // kullanıcı vazgeçti
      }
      final r = await MultipartUploader(widget.session).upload('/users/me/avatar', prepared);
      if (!mounted) return;
      setState(() {
        if (r is Map && r['avatarUrl'] is String) _avatarUrl = r['avatarUrl'] as String;
        _avatarChanged = true;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = _uploadError(e);
      });
    }
  }

  Future<void> _removeAvatar() async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      await widget.session.api.delete('/users/me/avatar');
      if (!mounted) return;
      setState(() {
        _avatarUrl = null;
        _avatarChanged = true;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = errorText(e);
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

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
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
        backgroundColor: bu.bg,
        body: Column(
          children: [
            BuHeader(title: context.l10n.profileEditTitle, onBack: () => Navigator.maybePop(context)),
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    if (_error != null) Notice(_error!),
                    _avatar(),
                    const SizedBox(height: 22),
                    _label(context.l10n.profileFullName),
                    TextFormField(
                      controller: _name,
                      maxLength: 80,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setState(() {}),
                      style: BuType.bodyStrong.copyWith(color: bu.ink),
                      validator: (v) =>
                          (v == null || v.trim().length < 2) ? context.l10n.profileNameMin : null,
                      decoration: _deco(context),
                    ),
                    const SizedBox(height: 12),
                    AcademicFields(
                      catalog: _catalog,
                      faculty: _faculty,
                      department: _department,
                      grade: _grade,
                      enabled: !_busy,
                      departmentError: _departmentError,
                      onChanged: (f, d, g) => setState(() {
                        _faculty = f;
                        _department = d;
                        _grade = g;
                        _departmentError = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _label(context.l10n.profileAbout)),
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 4, bottom: 6),
                          child: Text('${_bio.text.characters.length} / 300',
                              style: BuType.label.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: bu.mut)),
                        ),
                      ],
                    ),
                    TextFormField(
                      controller: _bio,
                      maxLength: 300,
                      maxLines: 4,
                      minLines: 3,
                      onChanged: (_) => setState(() {}),
                      style: BuType.body.copyWith(height: 1.4, color: bu.ink),
                      decoration: _deco(context, hint: context.l10n.profileBioHint),
                    ),
                    const SizedBox(height: 12),
                    _label(context.l10n.profil1CorpEmail),
                    TextFormField(
                      initialValue: (widget.profile['email'] as String?) ?? '',
                      readOnly: true,
                      style: BuType.body.copyWith(fontSize: 15, color: bu.mut),
                      decoration: _deco(context).copyWith(
                        fillColor: bu.sf2,
                        suffixIcon: Icon(LucideIcons.lock, size: 18, color: bu.mut),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ProfilCard(children: [
                      ProfilToggleRow(
                        label: context.l10n.profileShowEmail,
                        value: _showEmail,
                        onChanged: (v) => setState(() => _showEmail = v),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: Theme.of(context).brightness == Brightness.dark
                          ? null
                          : const [
                              BoxShadow(
                                  color: Color(0x99C62A20), blurRadius: 26, offset: Offset(0, 14), spreadRadius: -12)
                            ],
                    ),
                    child: FilledButton(
                      onPressed: _busy ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: bu.pr,
                        foregroundColor: bu.onPr,
                        disabledBackgroundColor: bu.pr,
                        disabledForegroundColor: bu.onPr,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        textStyle: BuType.heading.copyWith(fontWeight: FontWeight.w700),
                      ),
                      child: _busy
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: bu.onPr),
                            )
                          : Text(context.l10n.profileSave),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
