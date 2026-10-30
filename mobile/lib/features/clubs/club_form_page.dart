import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/platform/image_service.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../media_crop/media_crop.dart';
import 'club_categories.dart';
import 'club_detail_page.dart';
import 'club_detail_parts.dart' show ClubRoundButton;
import 'club_ref_widgets.dart';

/// Kulüp kurma akışını başlatır: form -> sonuç. ACTIVE ise kulüp sayfasına gider,
/// onaya düştüyse bilgi verir (referans 29-06). Dönüş: kulüp oluşturuldu mu (liste yenilensin).
Future<bool> openCreateClub(BuildContext context, Session session) async {
  final res = await Navigator.push<Map<String, dynamic>>(
    context,
    MaterialPageRoute(builder: (_) => ClubFormPage(session: session)),
  );
  if (res == null || !context.mounted) return false;
  final id = (res['id'] as num?)?.toInt();
  if (res['status'] == 'ACTIVE' && id != null) {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ClubDetailPage(session: session, communityId: id)),
    );
  } else if (context.mounted) {
    final l = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (c) => ClubDialogCard(
        icon: LucideIcons.clock,
        badge: LucideIcons.check,
        title: l.clubMgmtPendingTitle,
        message: l.clubMgmtPendingBody,
        boldName: l.profilePrefsMyClubs,
        actions: [
          ClubBtn(
              label: l.clubMgmtOk,
              kind: ClubBtnKind.primary,
              onPressed: () => Navigator.pop(c))
        ],
      ),
    );
  }
  return true;
}

/// Kulüp kur / düzenle: tek ekranlı form. [club] verilirse düzenleme (PATCH), yoksa kurma (POST).
class ClubFormPage extends StatefulWidget {
  const ClubFormPage(
      {super.key, required this.session, this.club, this.cropPicker});

  final Session session;
  final Map<String, dynamic>? club;

  /// Yalnız testler: galeri/kamera seçicisinin sahtesi (kırpma sayfası gerçek açılır).
  @visibleForTesting
  final CropPhotoPicker? cropPicker;

  @override
  State<ClubFormPage> createState() => _ClubFormPageState();
}

class _ClubFormPageState extends State<ClubFormPage> {
  static const _maxQuestions = 3;
  static const _nameMax = 80;
  static const _descMax = 1000;

  late final _name =
      TextEditingController(text: (widget.club?['name'] ?? '').toString());
  late final _desc = TextEditingController(
      text: (widget.club?['description'] ?? '').toString());

  /// Seçili kategori anahtarı (null = seçilmedi). Düzenlemede kulübün mevcut anahtarıyla başlar.
  late String? _category = _origCategory;
  String? get _origCategory {
    final k = (widget.club?['category'] ?? '').toString().trim();
    return k.isEmpty ? null : k;
  }

  late String _visibility =
      widget.club?['visibility'] == 'PRIVATE' ? 'PRIVATE' : 'PUBLIC';
  late String _policy =
      widget.club?['joinPolicy'] == 'APPROVAL' ? 'APPROVAL' : 'OPEN';
  final _questions = <TextEditingController>[];
  List<String> _origQuestions = const [];
  List<ClubCategory> _categories = const [];
  bool _catsLoaded = false;
  PreparedImage? _cover;
  PreparedImage? _logo;
  bool _logoRemoved =
      false; // var olan logo "kaldır" ile silinecek (kayıtta DELETE)
  final _images = ImageService();
  final _scroll = ScrollController();

  bool _busy = false;
  final _errors = <String, String>{};
  String? _formError;

  /// Kulüp kaydedildi ama kapak/logo/sorular yazılamadı: form açık kalır, uyarı bandı ve "Tekrar dene" çıkar.
  int? _savedId;
  Map<String, dynamic>? _savedResult;
  bool _partial = false;

  bool get _edit => widget.club != null || _savedId != null;
  int? get _id => (widget.club?['id'] as num?)?.toInt() ?? _savedId;
  bool get _askQuestions => _policy == 'APPROVAL' || _visibility == 'PRIVATE';

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.club != null) _loadQuestions();
    _name.addListener(_tick);
    _desc.addListener(_tick);
  }

  void _tick() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _scroll.dispose();
    for (final c in _questions) {
      c.dispose();
    }
    super.dispose();
  }

  /// Etkin kategoriler (admin sırasıyla); ad sunucuda istek diline çevrilmiştir.
  Future<void> _loadCategories() async {
    final list = await ClubCategories.load(widget.session.api);
    if (!mounted) return;
    setState(() {
      _catsLoaded = true;
      if (list != null) _categories = list;
    });
  }

  /// Kulübün mevcut kategorisi etkin listede yoksa (pasif/silinmiş) salt-okunur "kullanım dışı" gösterilir.
  bool get _origInactive =>
      _edit &&
      _origCategory != null &&
      _catsLoaded &&
      !_categories.any((c) => c.key == _origCategory);

  Future<void> _loadQuestions() async {
    try {
      final res =
          await widget.session.api.get('/communities/$_id/join-questions');
      if (!mounted || res is! List) return;
      final qs = [
        for (final e in res.whereType<Map>()) (e['question'] ?? '').toString()
      ];
      setState(() {
        _origQuestions = qs;
        for (final q in qs.take(_maxQuestions)) {
          _questions.add(TextEditingController(text: q));
        }
      });
    } catch (_) {}
  }

  void _snack(String m) => BuToast.show(context, m, kind: BuToastKind.error);

  String _imageError(ImageException e) => e.code == 'TOO_LARGE'
      ? context.l10n.clubMgmtImageTooLarge
      : e.code == 'UNSUPPORTED_TYPE'
          ? context.l10n.clubMgmtImageUnsupported
          : context.l10n.clubMgmtImageUnreadable;

  /// Kaynak sayfası (Galeriden seç / Fotoğraf çek / Fotoğrafı kaldır) -> seç -> kırp (logo 1:1, kapak 16:9) -> hazırla.
  /// Kapakta sunucu silme ucu olmadığından "kaldır" yalnız bu oturumda seçilmiş görseli geri alır.
  Future<void> _pick({required bool logo}) async {
    final existingLogo =
        fileUrl(widget.club?['logoUrl']?.toString()) != null && !_logoRemoved;
    final removable = logo ? (_logo != null || existingLogo) : _cover != null;
    final src = await showPhotoSourceSheet(context, removable: removable);
    if (src == null || !mounted) return;
    if (src == PhotoSource.remove) {
      setState(() {
        if (logo) {
          _logo = null;
          if (existingLogo) _logoRemoved = true;
        } else {
          _cover = null;
        }
      });
      return;
    }
    try {
      final name = _name.text.trim();
      final spec = logo
          ? CropSpec.logo(previewName: name.isEmpty ? null : name)
          : CropSpec.cover(previewTitle: name.isEmpty ? null : name);
      final bytes = await pickAndCrop(
        context,
        spec,
        source: src == PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        pick: widget.cropPicker,
      );
      if (bytes == null || !mounted) return;
      final img = await _images.prepare(bytes, avatar: logo);
      if (!mounted) return;
      setState(() {
        if (logo) {
          _logo = img;
          _logoRemoved = false;
        } else {
          _cover = img;
        }
      });
    } on ImageException catch (e) {
      if (mounted) _snack(_imageError(e));
    } catch (_) {
      if (mounted) _snack(context.l10n.clubMgmtImagePickFailed);
    }
  }

  bool _validate() {
    final e = <String, String>{};
    final n = _name.text.trim();
    if (n.length < 3) e['name'] = context.l10n.clubMgmtNameMin;
    if (n.length > _nameMax) e['name'] = context.l10n.clubMgmtNameMax;
    if (_desc.text.trim().length > _descMax) {
      e['description'] = context.l10n.clubMgmtDescMax;
    }
    setState(() {
      _errors
        ..clear()
        ..addAll(e);
      _formError = null;
    });
    if (e.isNotEmpty && _scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
    return e.isEmpty;
  }

  /// Sunucu `alan: mesaj` biçiminde doğrulama hatası dönerse alanın altına yazar.
  void _applyServerError(Object err) {
    if (err is ApiError && err.code == 'VALIDATION_ERROR') {
      final m = RegExp(r'^(\w+):\s*(.+)$').firstMatch(err.message);
      if (m != null &&
          const {'name', 'description', 'category'}.contains(m.group(1))) {
        setState(() => _errors[m.group(1)!] = m.group(2)!);
        return;
      }
    }
    if (err is ApiError && err.code == 'COMMUNITY_CATEGORY_INVALID') {
      setState(() => _errors['category'] = err.message.isNotEmpty
          ? err.message
          : context.l10n.clubMgmtCategoryInvalid);
      // Liste güncel olmayabilir (kategori pasifleşti): yeniden çek.
      _loadCategories();
      return;
    }
    setState(() => _formError = errorText(err));
  }

  List<String> get _questionTexts => [for (final c in _questions) c.text.trim()]
      .where((q) => q.isNotEmpty)
      .toList();

  /// Kulüp oluştuktan/güncellendikten sonraki adımlar: sorular, kapak, logo. Hata kurmayı geri almaz; `true` = hepsi tamam.
  Future<bool> _extras(int id) async {
    final api = widget.session.api;
    var ok = true;
    final qs = _askQuestions ? _questionTexts : <String>[];
    if (qs.join('\u0001') != _origQuestions.join('\u0001') &&
        (widget.club != null || _savedId != null || qs.isNotEmpty)) {
      try {
        await api.put('/communities/$id/join-questions', {'questions': qs});
        _origQuestions = qs;
      } catch (_) {
        ok = false;
      }
    }
    if (_cover != null) {
      try {
        await MultipartUploader(widget.session)
            .upload('/communities/$id/cover', _cover!);
        _cover = null;
      } catch (_) {
        ok = false;
      }
    }
    if (_logo != null) {
      try {
        await MultipartUploader(widget.session)
            .upload('/communities/$id/logo', _logo!);
        _logo = null;
      } catch (_) {
        ok = false;
      }
    } else if (_logoRemoved) {
      try {
        await api.delete('/communities/$id/logo');
        _logoRemoved = false;
      } catch (_) {
        ok = false;
      }
    }
    return ok;
  }

  Future<void> _submit() async {
    if (_busy || !_validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final api = widget.session.api;
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'description': _desc.text.trim(),
      'joinPolicy': _policy,
      'visibility': _visibility,
    };
    try {
      Map<String, dynamic> result;
      if (_edit) {
        // Değişmeyen kategori aynen gönderilir (pasif olsa da kabul edilir); temizlenen boş gider.
        if (_category != null) {
          body['category'] = _category;
        } else if (_origCategory != null) {
          body['category'] = '';
        }
        await api.patch('/communities/$_id', body);
        result = _savedResult ?? {'updated': true, 'id': _id};
      } else {
        // Boş açıklama / seçilmeyen kategori hiç gönderilmez.
        if ((body['description'] as String).isEmpty) body.remove('description');
        if (_category != null) body['category'] = _category;
        final res = await api.post('/communities', body);
        final m =
            res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
        final st = (m['status'] ?? '').toString();
        result = {
          'id': (m['id'] as num?)?.toInt(),
          'status': st == 'ACTIVE' ? 'ACTIVE' : 'PENDING'
        };
      }
      final id = (result['id'] as num?)?.toInt();
      var warn = false;
      if (id != null) {
        _savedId = id;
        _savedResult = result;
        warn = !await _extras(id);
      }
      if (!mounted) return;
      if (warn) {
        setState(() {
          _busy = false;
          _partial = true;
        });
        if (_scroll.hasClients) {
          _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
        return;
      }
      Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _applyServerError(e);
      }
    }
  }

  /// Uyarı bandındaki "Tekrar dene": yalnız başarısız ek adımları yeniden dener.
  Future<void> _retryExtras() async {
    final id = _id;
    if (_busy || id == null) return;
    setState(() => _busy = true);
    final ok = await _extras(id);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, _savedResult ?? {'updated': true, 'id': id});
    } else {
      setState(() => _busy = false);
    }
  }

  void _back() => Navigator.pop(context, _savedResult);

  Future<void> _pickCategory() async {
    final l = context.l10n;
    final v = await BuSheet.show<String>(
      context,
      title: l.p12CategorySheetTitle,
      builder: (c) {
        final t = c.bu;
        Widget row(String value, String label, {IconData? icon}) {
          final on = (value.isEmpty ? null : value) == _category;
          return BuListTile(
            title: label,
            leading: icon == null
                ? null
                : Icon(icon, size: 20, color: on ? t.pr : t.mut),
            selected: on,
            trailing:
                on ? Icon(LucideIcons.check, size: 18, color: t.pr) : null,
            onTap: () => Navigator.of(c).pop(value),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row('', l.clubMgmtCategoryNone),
            for (final cat in _categories)
              row(cat.key, cat.name, icon: ClubCategory.iconFor(cat.icon)),
            if (_origInactive)
              row(
                  _origCategory!,
                  l.clubMgmtCategoryInactive(
                      ClubCategories.labelFor(_origCategory))),
          ],
        );
      },
    );
    if (v == null || !mounted) return;
    setState(() {
      _category = v.isEmpty ? null : v;
      _errors.remove('category');
    });
  }

  // -------------------------------------------------------------------------------------------------------------
  // Yapı

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l10n = context.l10n;
    final create = !_edit;
    return PopScope(
      canPop: _savedResult == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: t.bg,
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            BuHeader(
                title:
                    _edit ? l10n.clubMgmtEditTitle : l10n.clubMgmtCreateTitle,
                onBack: _back),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_partial) ...[
                      ClubNoteCard(
                        icon: LucideIcons.triangleAlert,
                        title: l10n.p12PartialTitle,
                        body: l10n.clubMgmtSavedWithWarning,
                        tone: ClubNoteTone.soft,
                        action: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: BuButton(
                              label: l10n.commonRetry,
                              icon: LucideIcons.refreshCw,
                              kind: BuButtonKind.outline,
                              compact: true,
                              busy: _busy,
                              onPressed: _retryExtras),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _mediaCard(t),
                    const SizedBox(height: 16),
                    _basicsCard(t, create),
                    const SizedBox(height: 16),
                    if (create) ...[
                      _titledCard(
                        t,
                        icon: LucideIcons.eye,
                        title: l10n.clubMgmtVisibility,
                        child: _visibilityBlock(t),
                      ),
                      const SizedBox(height: 16),
                      _titledCard(
                        t,
                        icon: LucideIcons.userCheck,
                        title: l10n.clubMgmtJoinLabel,
                        child: _joinBlock(t),
                      ),
                    ] else
                      BuCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(l10n.p12VisibilityAndJoin,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge!
                                    .copyWith(
                                        color: t.ink,
                                        fontWeight: FontWeight.w800)),
                            const SizedBox(height: 16),
                            _label(t, l10n.clubMgmtVisibility),
                            _segmented(
                                t,
                                [
                                  (LucideIcons.globe, l10n.clubMgmtPublic),
                                  (LucideIcons.lock, l10n.clubMgmtPrivate)
                                ],
                                _visibility == 'PRIVATE' ? 1 : 0,
                                (i) => setState(() => _visibility =
                                    i == 1 ? 'PRIVATE' : 'PUBLIC')),
                            const SizedBox(height: 16),
                            _label(t, l10n.clubMgmtJoinLabel),
                            _segmented(
                                t,
                                [
                                  (LucideIcons.zap, l10n.clubMgmtOpenPolicy),
                                  (
                                    LucideIcons.squareCheckBig,
                                    l10n.clubMgmtApprovalPolicy
                                  )
                                ],
                                _policy == 'APPROVAL' ? 1 : 0,
                                (i) => setState(() =>
                                    _policy = i == 1 ? 'APPROVAL' : 'OPEN')),
                          ],
                        ),
                      ),
                    if (_askQuestions) ...[
                      const SizedBox(height: 16),
                      _questionsCard(t)
                    ],
                    if (create) ...[const SizedBox(height: 16), _consent(t)],
                    if (_formError != null) ...[
                      const SizedBox(height: 14),
                      Text(_formError!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall!
                              .copyWith(color: t.danger)),
                    ],
                  ],
                ),
              ),
            ),
            // Sabit alt çubuk: üstte yumuşak geçiş.
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16,
                  12 + MediaQuery.of(context).padding.bottom.clamp(0, 10)),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  stops: const [.75, 1],
                  colors: [t.bg, t.bg.withValues(alpha: 0)],
                ),
              ),
              child: BuButton(
                label: _edit ? l10n.clubMgmtSave : l10n.clubMgmtCreateButton,
                icon: _edit ? LucideIcons.save : LucideIcons.rocket,
                busy: _busy && !_partial,
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(BuTokens t, String s,
          {bool required = false, String? trailing}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: s),
                  if (required)
                    TextSpan(text: ' *', style: TextStyle(color: t.pr)),
                ]),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall!
                    .copyWith(color: t.ink, fontWeight: FontWeight.w700),
              ),
            ),
            if (trailing != null)
              Text(trailing,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium!
                      .copyWith(color: t.mut, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _hint(BuTokens t, String s,
          {IconData icon = LucideIcons.info, bool error = false}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 10, 2, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
                padding: const EdgeInsets.only(top: 1),
                child: ExcludeSemantics(
                    child:
                        Icon(icon, size: 15, color: error ? t.danger : t.mut))),
            const SizedBox(width: 8),
            Expanded(
              child: Text(s,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: error ? t.danger : t.mut,
                      height: 1.4,
                      fontWeight: error ? FontWeight.w600 : null)),
            ),
          ],
        ),
      );

  /// Başlıklı kart: kırmızı simge + başlık, altında içerik.
  Widget _titledCard(BuTokens t,
          {required IconData icon,
          required String title,
          required Widget child,
          String? subtitle,
          Widget? trailing}) =>
      BuCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: ExcludeSemantics(
                        child: Icon(icon, size: 22, color: t.pr))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                          header: true,
                          child: Text(title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge!
                                  .copyWith(
                                      color: t.ink,
                                      fontWeight: FontWeight.w800))),
                      if (subtitle != null)
                        Text(subtitle,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall!
                                .copyWith(color: t.mut)),
                    ],
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );

  Widget _visibilityBlock(BuTokens t) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _segmented(
              t,
              [
                (LucideIcons.globe, context.l10n.clubMgmtPublic),
                (LucideIcons.lock, context.l10n.clubMgmtPrivate)
              ],
              _visibility == 'PRIVATE' ? 1 : 0,
              (i) =>
                  setState(() => _visibility = i == 1 ? 'PRIVATE' : 'PUBLIC')),
          _hint(
              t,
              _visibility == 'PRIVATE'
                  ? context.l10n.clubMgmtPrivateHint
                  : context.l10n.clubMgmtPublicHint),
        ],
      );

  Widget _joinBlock(BuTokens t) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _segmented(
              t,
              [
                (LucideIcons.zap, context.l10n.clubMgmtOpenPolicy),
                (
                  LucideIcons.squareCheckBig,
                  context.l10n.clubMgmtApprovalPolicy
                )
              ],
              _policy == 'APPROVAL' ? 1 : 0,
              (i) => setState(() => _policy = i == 1 ? 'APPROVAL' : 'OPEN')),
          _hint(
              t,
              _policy == 'APPROVAL'
                  ? context.l10n.clubMgmtApprovalHint
                  : context.l10n.clubMgmtOpenHint,
              icon: LucideIcons.shieldCheck),
        ],
      );

  /// İki seçenekli simgeli segment: gri zemin, seçili parça beyaz.
  Widget _segmented(BuTokens t, List<(IconData, String)> items, int index,
          ValueChanged<int> onChanged) =>
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.md)),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == index,
                  label: items[i].$2,
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        buHaptic(BuHaptic.selection);
                        onChanged(i);
                      },
                      child: AnimatedContainer(
                        duration: BuMotion.of(context, BuMotion.short),
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i == index ? t.sf : t.sf2.withValues(alpha: 0),
                          borderRadius: BorderRadius.circular(BuRadius.sm),
                          boxShadow:
                              i == index ? BuElevation.of(context, 1) : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(items[i].$1,
                                size: 17, color: i == index ? t.ink : t.mut),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(items[i].$2,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge!
                                      .copyWith(
                                          color: i == index ? t.ink : t.mut,
                                          fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _basicsCard(BuTokens t, bool create) {
    final l10n = context.l10n;
    final tx = Theme.of(context).textTheme;
    final catName = _category == null
        ? null
        : (_categories.where((c) => c.key == _category).firstOrNull?.name ??
            ClubCategories.labelFor(_category));
    return BuCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!create) ...[
            Text(l10n.p12BasicInfo,
                style: tx.titleLarge!
                    .copyWith(color: t.ink, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
          ],
          _label(t, l10n.clubMgmtNameLabel,
              required: true,
              trailing: '${_name.text.characters.length}/$_nameMax'),
          TextField(
            controller: _name,
            maxLength: _nameMax,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            style: tx.bodyLarge!.copyWith(color: t.ink),
            decoration: clubFill(context,
                hint: l10n.clubMgmtNameHint,
                hasError: _errors['name'] != null,
                prefixIcon: Icon(LucideIcons.flag, size: 18, color: t.mut)),
          ),
          if (_errors['name'] != null) ClubFieldError(_errors['name']!),
          const SizedBox(height: 18),
          _label(t, l10n.clubMgmtDescLabel,
              trailing: '${_desc.text.characters.length}/$_descMax'),
          TextField(
            controller: _desc,
            maxLength: _descMax,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            style: tx.bodyLarge!.copyWith(color: t.ink),
            decoration: clubFill(context,
                hint: l10n.clubMgmtDescHint,
                hasError: _errors['description'] != null,
                pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
          ),
          if (_errors['description'] != null)
            ClubFieldError(_errors['description']!),
          const SizedBox(height: 18),
          _label(t, l10n.clubMgmtCategoryLabel),
          Semantics(
            button: true,
            label: l10n.clubMgmtCategoryLabel,
            child: InkWell(
              onTap: _pickCategory,
              borderRadius: BorderRadius.circular(BuRadius.md),
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _errors['category'] != null ? t.soft : t.sf2,
                  borderRadius: BorderRadius.circular(BuRadius.md),
                ),
                child: Row(
                  children: [
                    ExcludeSemantics(
                        child:
                            Icon(LucideIcons.shapes, size: 18, color: t.mut)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: catName == null
                          ? Text(l10n.clubMgmtCategoryHint,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tx.bodyLarge!.copyWith(color: t.mut))
                          : Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                    color: _errors['category'] != null
                                        ? t.soft
                                        : t.sf,
                                    borderRadius: BuRadius.bPill),
                                child: Text(catName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: tx.labelLarge!.copyWith(
                                        color: _errors['category'] != null
                                            ? t.onSoft
                                            : t.ink,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                    ),
                    ExcludeSemantics(
                        child: Icon(LucideIcons.chevronDown,
                            size: 20, color: t.mut)),
                  ],
                ),
              ),
            ),
          ),
          if (_errors['category'] != null)
            _hint(t, _errors['category']!,
                icon: LucideIcons.circleAlert, error: true),
        ],
      ),
    );
  }

  Widget _questionsCard(BuTokens t) {
    final l10n = context.l10n;
    final tx = Theme.of(context).textTheme;
    return _titledCard(
      t,
      icon: LucideIcons.fileQuestion,
      title: l10n.clubMgmtQuestionsLabel('$_maxQuestions'),
      subtitle: l10n.p12QuestionsSubtitle,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bPill),
        child: Text('${_questions.length} / $_maxQuestions',
            style: tx.labelMedium!
                .copyWith(color: t.mut, fontWeight: FontWeight.w800)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _questions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 8, 14),
                decoration: BoxDecoration(
                    color: t.sf2,
                    borderRadius: BorderRadius.circular(BuRadius.md)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(l10n.clubMgmtQuestionHint('${i + 1}'),
                                style: tx.labelLarge!.copyWith(
                                    color: t.ink,
                                    fontWeight: FontWeight.w800))),
                        ClubRoundButton(
                          icon: LucideIcons.trash2,
                          tooltip: l10n.clubMgmtRemoveQuestion,
                          plain: true,
                          size: 40,
                          onTap: () =>
                              setState(() => _questions.removeAt(i).dispose()),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: TextField(
                        controller: _questions[i],
                        maxLength: 200,
                        minLines: 1,
                        maxLines: 3,
                        style: tx.bodyLarge!.copyWith(color: t.ink),
                        decoration: clubFill(context,
                            hint: l10n.p12QuestionPlaceholder,
                            fill: t.sf,
                            pad: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_questions.length < _maxQuestions)
            BuButton(
              label: l10n.clubMgmtAddQuestion,
              icon: LucideIcons.circlePlus,
              kind: BuButtonKind.soft,
              onPressed: () =>
                  setState(() => _questions.add(TextEditingController())),
            ),
        ],
      ),
    );
  }

  /// Onay notu: "topluluk ilkelerine" ifadesi kalın.
  Widget _consentText(BuTokens t) {
    final l = context.l10n;
    final style = Theme.of(context)
        .textTheme
        .bodySmall!
        .copyWith(color: t.mut, height: 1.4);
    final text = l.p12ConsentNote;
    final at = text.indexOf(l.p12ConsentBold);
    if (at < 0) return Text(text, style: style);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: text.substring(0, at)),
        TextSpan(
            text: l.p12ConsentBold,
            style: TextStyle(color: t.ink, fontWeight: FontWeight.w800)),
        TextSpan(text: text.substring(at + l.p12ConsentBold.length)),
      ]),
      style: style,
    );
  }

  Widget _consent(BuTokens t) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.md)),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: t.sf, shape: BoxShape.circle),
                child: Icon(LucideIcons.badgeCheck, size: 17, color: t.mut),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _consentText(t)),
          ],
        ),
      );

  // -------------------------------------------------------------------------------------------------------------
  // Kapak + logo

  Widget _mediaCard(BuTokens t) {
    final l10n = context.l10n;
    final tx = Theme.of(context).textTheme;
    final cover = fileUrl(widget.club?['coverUrl']?.toString());
    final logoUrl = fileUrl(widget.club?['logoUrl']?.toString());
    final hasCover = _cover != null || cover != null;
    final hasLogo = _logo != null || (logoUrl != null && !_logoRemoved);
    const logoSize = 96.0;
    return BuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Logo kapağın alt kenarına biner; Stack yüksekliği logonun yarısı kadar uzatılır ki logo/etiket tamamen dokunulabilir olsun.
              Padding(
                padding: const EdgeInsets.only(bottom: logoSize / 2),
                child: Semantics(
                  button: true,
                  label: hasCover
                      ? l10n.clubMgmtChangeCover
                      : l10n.clubMgmtAddCover,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _busy ? null : () => _pick(logo: false),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: hasCover
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(BuRadius.md),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (_cover != null)
                                    Image.memory(_cover!.bytes,
                                        fit: BoxFit.cover,
                                        gaplessPlayback: true)
                                  else
                                    BuImage(
                                        widget.club?['coverUrl']?.toString(),
                                        width: double.infinity,
                                        height: double.infinity),
                                  PositionedDirectional(
                                    end: 12,
                                    bottom: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                          color: t.scrim.withValues(alpha: .55),
                                          borderRadius: BuRadius.bPill),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(LucideIcons.camera,
                                              size: 15, color: t.onMedia),
                                          const SizedBox(width: 6),
                                          Text(l10n.clubMgmtChangeCover,
                                              style: tx.labelMedium!.copyWith(
                                                  color: t.onMedia,
                                                  fontWeight: FontWeight.w700)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : CustomPaint(
                              painter: _DashedRRect(
                                  color: t.bd, radius: BuRadius.md),
                              child: Container(
                                decoration: BoxDecoration(
                                    color: t.sf2.withValues(alpha: .5),
                                    borderRadius:
                                        BorderRadius.circular(BuRadius.md)),
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                          color: t.sf, shape: BoxShape.circle),
                                      child: Icon(LucideIcons.imagePlus,
                                          size: 22, color: t.pr),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(l10n.clubMgmtAddCover,
                                        textAlign: TextAlign.center,
                                        style: tx.labelLarge!.copyWith(
                                            color: t.ink,
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 2),
                                    Text(l10n.p12CoverHint,
                                        textAlign: TextAlign.center,
                                        style: tx.labelSmall!
                                            .copyWith(color: t.mut)),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              if (!hasLogo)
                PositionedDirectional(
                  start: logoSize + 28,
                  bottom: 14,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _busy ? null : () => _pick(logo: true),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.p12LogoAdd,
                            style: tx.labelLarge!.copyWith(
                                color: t.ink, fontWeight: FontWeight.w800)),
                        Text(l10n.p12LogoHint,
                            style: tx.labelSmall!.copyWith(color: t.mut)),
                      ],
                    ),
                  ),
                ),
              PositionedDirectional(
                start: 12,
                bottom: 0,
                child: Semantics(
                  button: true,
                  label: hasLogo ? l10n.p12LogoChange : l10n.p12LogoAdd,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _busy ? null : () => _pick(logo: true),
                    child: SizedBox(
                      width: logoSize + 8,
                      height: logoSize + 8,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                  color: t.sf, shape: BoxShape.circle),
                              padding: const EdgeInsets.all(4),
                              child: hasLogo
                                  ? ClipOval(
                                      child: _logo != null
                                          ? Image.memory(_logo!.bytes,
                                              fit: BoxFit.cover,
                                              gaplessPlayback: true)
                                          : BuImage(
                                              widget.club?['logoUrl']
                                                  ?.toString(),
                                              width: logoSize,
                                              height: logoSize),
                                    )
                                  : CustomPaint(
                                      painter: _DashedRRect(
                                          color: t.bd,
                                          radius: logoSize,
                                          circle: true),
                                      child: Container(
                                        decoration: BoxDecoration(
                                            color: t.sf2.withValues(alpha: .5),
                                            shape: BoxShape.circle),
                                        alignment: Alignment.center,
                                        child: Icon(LucideIcons.imagePlus,
                                            size: 24, color: t.mut),
                                      ),
                                    ),
                            ),
                          ),
                          PositionedDirectional(
                            end: 2,
                            bottom: 2,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                  color: t.pr,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: t.sf, width: 2)),
                              child: Icon(
                                  hasLogo
                                      ? LucideIcons.pencil
                                      : LucideIcons.camera,
                                  size: 15,
                                  color: t.onPr),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

/// Kesik çizgili yuvarlatılmış dikdörtgen/daire çerçeve (yükleme alanları).
class _DashedRRect extends CustomPainter {
  _DashedRRect(
      {required this.color, required this.radius, this.circle = false});

  final Color color;
  final double radius;
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final rect = (Offset.zero & size).deflate(1);
    final path = Path()
      ..addRRect(circle
          ? RRect.fromRectAndRadius(rect, Radius.circular(size.shortestSide))
          : RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    for (final PathMetric m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 7), paint);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRect old) =>
      old.color != color || old.radius != radius || old.circle != circle;
}
