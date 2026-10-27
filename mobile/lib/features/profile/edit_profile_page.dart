import 'package:flutter/material.dart';

import '../../core/academic_catalog.dart';
import '../../core/api.dart';
import '../../widgets/academic_picker.dart';
import '../../core/platform/image_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../auth/auth_widgets.dart';
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
      setState(() => _departmentError = 'Bölümü seçin.');
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
        title: const Text('Değişiklikler kaydedilmedi'),
        content: const Text('Çıkarsanız yaptığınız değişiklikler kaybolacak.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Düzenlemeye devam et')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Vazgeç ve çık')),
        ],
      ),
    );
    return r == true;
  }

  InputDecoration _deco(BuildContext context, {String? hint}) {
    final bu = context.bu;
    OutlineInputBorder b(Color c) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c));
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: bu.mut, fontWeight: FontWeight.w500),
      counterText: '',
      filled: true,
      fillColor: bu.sf,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: b(bu.bd),
      enabledBorder: b(bu.bd),
      focusedBorder: b(bu.pr),
      errorBorder: b(bu.danger),
      focusedErrorBorder: b(bu.danger),
    );
  }

  Widget _label(String t) {
    final bu = context.bu;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(t.toUpperCase(),
          style: BuType.label.copyWith(color: bu.mut, letterSpacing: 0.3)),
    );
  }

  Widget _avatar() {
    final bu = context.bu;
    final url = fileUrl(_avatarUrl);
    final initials = Container(
      width: 96,
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bu.h1, bu.h2],
        ),
      ),
      child: Text(
        initialsOf(_name.text),
        style: BuType.display.copyWith(color: Colors.white),
      ),
    );
    return Column(
      children: [
        GestureDetector(
          onTap: _pickAvatar,
          child: SizedBox(
            width: 98,
            height: 98,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (url == null)
                  initials
                else
                  ClipOval(
                    child: Image.network(url,
                        width: 96, height: 96, fit: BoxFit.cover, errorBuilder: (_, __, ___) => initials),
                  ),
                if (_uploading)
                  Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black45),
                    child: const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                      ),
                    ),
                  ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: bu.ink,
                      border: Border.all(color: bu.bg, width: 3),
                    ),
                    child: Icon(LucideIcons.camera, size: 14.5, color: bu.bg),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _pickAvatar,
          child: Text(_uploading ? 'Yükleniyor…' : 'Fotoğrafı değiştir',
              style: BuType.bodyStrong.copyWith(color: bu.pr)),
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
                  style: TextStyle(fontWeight: FontWeight.w700, color: danger ? bu.danger : bu.ink)),
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
              row(LucideIcons.image, 'Galeriden seç', 'gallery'),
              row(LucideIcons.camera, 'Fotoğraf çek', 'camera'),
              if (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                row(LucideIcons.trash2, 'Fotoğrafı kaldır', 'remove', danger: true),
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
          return 'Fotoğraf en fazla 2 MB olabilir. Daha küçük bir fotoğraf seçin.';
        case 'UNSUPPORTED_TYPE':
          return 'Yalnızca JPG, PNG veya WebP fotoğraflar yüklenebilir.';
        default:
          return 'Seçilen dosya okunamadı.';
      }
    }
    if (e is ApiError && e.status == 413) return 'Fotoğraf en fazla 2 MB olabilir.';
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
            BuHeader(title: 'Profili düzenle', onBack: () => Navigator.maybePop(context)),
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    if (_error != null) Notice(_error!),
                    Center(child: _avatar()),
                    const SizedBox(height: 18),
                    _label('Ad soyad'),
                    TextFormField(
                      controller: _name,
                      maxLength: 80,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setState(() {}),
                      style: BuType.bodyStrong.copyWith(color: bu.ink),
                      validator: (v) =>
                          (v == null || v.trim().length < 2) ? 'Ad en az 2 karakter olmalı.' : null,
                      decoration: _deco(context),
                    ),
                    const SizedBox(height: 14),
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
                        Expanded(child: _label('Hakkımda')),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text('${_bio.text.characters.length}/300',
                              style: BuType.label.copyWith(color: bu.mut)),
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
                      decoration: _deco(context, hint: 'Kendinizden kısaca bahsedin'),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 52,
                      padding: const EdgeInsets.only(left: 16, right: 12),
                      decoration: BoxDecoration(
                        color: bu.sf,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: bu.bd),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('E-postamı diğer kullanıcılara göster',
                                style: BuType.bodyStrong.copyWith(color: bu.ink)),
                          ),
                          Switch(
                            value: _showEmail,
                            onChanged: (v) => setState(() => _showEmail = v),
                            activeThumbColor: Colors.white,
                            activeTrackColor: bu.pr,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: bu.sf2,
                            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                          ),
                        ],
                      ),
                    ),
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
                  height: 54,
                  child: FilledButton(
                    onPressed: _busy ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: bu.pr,
                      foregroundColor: bu.onPr,
                      disabledBackgroundColor: bu.pr,
                      disabledForegroundColor: bu.onPr,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: BuType.heading,
                    ),
                    child: _busy
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: bu.onPr),
                          )
                        : const Text('Kaydet'),
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
