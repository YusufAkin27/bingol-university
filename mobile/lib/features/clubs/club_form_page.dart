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
import 'club_detail_parts.dart' show ClubBarIcon;
import 'clubs_widgets.dart' show ClubTextTabs;
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
    final tx = Theme.of(context).textTheme;
    final create = !_edit;
    final top = MediaQuery.paddingOf(context).top;
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
            // Üst çubuk (Stitch v3 06): geri oku + 22/600 başlık, altında ince ayraç.
            Container(
              padding: EdgeInsetsDirectional.only(top: top, start: 8, end: 20),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.bd))),
              child: SizedBox(
                height: 55,
                child: Row(
                  children: [
                    ClubBarIcon(icon: LucideIcons.arrowLeft, tooltip: l10n.commonBack, onTap: _back),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(_edit ? l10n.clubMgmtEditTitle : l10n.p51CreateClubTitle,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.title.copyWith(color: t.ink)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                    _coverPicker(t),
                    const SizedBox(height: 12),
                    _logoRow(t),
                    const SizedBox(height: 20),
                    _field(t, l10n.clubMgmtNameLabel, _nameField(t, tx), error: _errors['name']),
                    const SizedBox(height: 20),
                    _field(t, l10n.clubMgmtCategoryLabel, _categoryField(t, tx), error: _errors['category']),
                    const SizedBox(height: 20),
                    _field(t, l10n.p51DescLabel, _descField(t, tx), error: _errors['description']),
                    const SizedBox(height: 20),
                    _label(t, l10n.clubMgmtJoinLabel),
                    ClubTextTabs(
                      labels: [l10n.clubMgmtPublic, l10n.p51JoinApproval],
                      index: _policy == 'APPROVAL' ? 1 : 0,
                      padding: EdgeInsets.zero,
                      onChanged: (i) => setState(() => _policy = i == 1 ? 'APPROVAL' : 'OPEN'),
                    ),
                    const SizedBox(height: 20),
                    _label(t, l10n.clubMgmtVisibility),
                    ClubTextTabs(
                      labels: [l10n.clubMgmtPublic, l10n.clubMgmtPrivate],
                      index: _visibility == 'PRIVATE' ? 1 : 0,
                      padding: EdgeInsets.zero,
                      onChanged: (i) => setState(() => _visibility = i == 1 ? 'PRIVATE' : 'PUBLIC'),
                    ),
                    _hint(t, _visibility == 'PRIVATE' ? l10n.clubMgmtPrivateHint : l10n.clubMgmtPublicHint),
                    if (_askQuestions) ..._questionFields(t, tx),
                    if (_questions.length < _maxQuestions) _addQuestionButton(t, tx),
                    if (create) ...[const SizedBox(height: 8), _consentText(t)],
                    if (_formError != null) ...[
                      const SizedBox(height: 14),
                      Text(_formError!, style: tx.bodySmall!.copyWith(color: t.danger)),
                    ],
                    const SizedBox(height: 24),
                    BuButton(
                      label: _edit ? l10n.clubMgmtSave : l10n.p51Create,
                      busy: _busy && !_partial,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Etiket: 13-14 sp muted/600, alanın üstünde.
  Widget _label(BuTokens t, String s) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(s, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: t.mut, fontSize: 13, fontWeight: FontWeight.w600)),
      );

  /// Etiketli alan + altında (varsa) hata metni.
  Widget _field(BuTokens t, String label, Widget field, {String? error}) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(t, label),
          field,
          if (error != null) ClubFieldError(error),
        ],
      );

  /// İpucu satırı: simgesiz, muted 12.5 sp.
  Widget _hint(BuTokens t, String s) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(s, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: t.mut, height: 1.4)),
      );

  Widget _nameField(BuTokens t, TextTheme tx) => TextField(
        controller: _name,
        maxLength: _nameMax,
        textInputAction: TextInputAction.next,
        textCapitalization: TextCapitalization.words,
        style: tx.bodyLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w400),
        decoration: clubFill(context, hint: context.l10n.clubMgmtNameHint, hasError: _errors['name'] != null),
      );

  Widget _descField(BuTokens t, TextTheme tx) => Stack(
        children: [
          TextField(
            controller: _desc,
            maxLength: _descMax,
            minLines: 2,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            style: tx.bodyLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w400),
            decoration: clubFill(context,
                hint: context.l10n.p51DescHint,
                hasError: _errors['description'] != null,
                pad: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 38)),
          ),
          // Sayaç: alanın içinde sağ altta, muted.
          PositionedDirectional(
            end: 16,
            bottom: 12,
            child: IgnorePointer(
              child: Text('${_desc.text.characters.length}/$_descMax', style: tx.bodySmall!.copyWith(color: t.mut)),
            ),
          ),
        ],
      );

  Widget _categoryField(BuTokens t, TextTheme tx) {
    final l10n = context.l10n;
    final catName = _category == null
        ? null
        : (_categories.where((c) => c.key == _category).firstOrNull?.name ?? ClubCategories.labelFor(_category));
    final err = _errors['category'] != null;
    return Semantics(
      button: true,
      label: l10n.clubMgmtCategoryLabel,
      child: BuPressable(
        scale: .99,
        child: InkWell(
          onTap: _pickCategory,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minHeight: BuSize.field),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: t.sf,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: err ? t.danger : t.bdStrong, width: err ? 1.5 : 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(catName ?? l10n.clubMgmtCategoryHint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tx.bodyLarge!.copyWith(color: catName == null ? t.mut : t.ink, fontWeight: FontWeight.w400)),
                ),
                ExcludeSemantics(child: Icon(LucideIcons.chevronDown, size: 20, color: t.ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Katılma soruları (yalnız istekli/gizli kulüpte kaydedilir): alan + sil simgesi.
  List<Widget> _questionFields(BuTokens t, TextTheme tx) {
    final l10n = context.l10n;
    return [
      for (var i = 0; i < _questions.length; i++)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: TextField(
            controller: _questions[i],
            maxLength: 200,
            minLines: 1,
            maxLines: 3,
            style: tx.bodyLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w400),
            decoration: clubFill(context,
                hint: l10n.p12QuestionPlaceholder,
                suffixIcon: ClubBarIcon(
                  icon: LucideIcons.trash2,
                  tooltip: l10n.clubMgmtRemoveQuestion,
                  color: t.mut,
                  onTap: () => setState(() => _questions.removeAt(i).dispose()),
                )),
          ),
        ),
    ];
  }

  /// "+ Katılma sorusu ekle": marka renkli metin düğmesi. Soru yalnız istekli kulüpte anlamlıdır; açık katılımda
  /// dokununca katılım "İstek ile"ye geçer (soru kaydı için gerekli).
  Widget _addQuestionButton(BuTokens t, TextTheme tx) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          style: TextButton.styleFrom(foregroundColor: t.pr, minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 0)),
          onPressed: () => setState(() {
            if (_policy != 'APPROVAL' && _visibility != 'PRIVATE') _policy = 'APPROVAL';
            _questions.add(TextEditingController());
          }),
          child: Text('+ ${context.l10n.p51AddJoinQuestion}', style: tx.titleSmall!.copyWith(color: t.pr, fontWeight: FontWeight.w600)),
        ),
      );

  /// Onay notu: "topluluk ilkelerine" ifadesi kalın.
  Widget _consentText(BuTokens t) {
    final l = context.l10n;
    final style = Theme.of(context).textTheme.bodySmall!.copyWith(color: t.mut, height: 1.4);
    final text = l.p12ConsentNote;
    final at = text.indexOf(l.p12ConsentBold);
    if (at < 0) return Text(text, style: style);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: text.substring(0, at)),
        TextSpan(text: l.p12ConsentBold, style: TextStyle(color: t.ink, fontWeight: FontWeight.w800)),
        TextSpan(text: text.substring(at + l.p12ConsentBold.length)),
      ]),
      style: style,
    );
  }

  // -------------------------------------------------------------------------------------------------------------
  // Kapak + logo

  /// Kapak seçici: 140 dp; boşken kesik çizgili (bdStrong 1 dp) beyaz alan + tek görsel simgesi + metin; doluyken önizleme.
  Widget _coverPicker(BuTokens t) {
    final l10n = context.l10n;
    final tx = Theme.of(context).textTheme;
    final cover = fileUrl(widget.club?['coverUrl']?.toString());
    final hasCover = _cover != null || cover != null;
    return Semantics(
      button: true,
      excludeSemantics: true,
      onTap: _busy ? null : () => _pick(logo: false),
      label: hasCover ? l10n.clubMgmtChangeCover : l10n.eventFormAddCover,
      child: BuPressable(
        scale: .99,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _busy ? null : () => _pick(logo: false),
          child: SizedBox(
            height: 140,
            child: hasCover
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_cover != null)
                          Image.memory(_cover!.bytes, fit: BoxFit.cover, gaplessPlayback: true)
                        else
                          BuImage(widget.club?['coverUrl']?.toString(), width: double.infinity, height: 140),
                        PositionedDirectional(
                          end: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: t.scrim.withValues(alpha: .55), borderRadius: BuRadius.bPill),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.camera, size: 15, color: t.onMedia),
                                const SizedBox(width: 6),
                                Text(l10n.clubMgmtChangeCover, style: tx.labelMedium!.copyWith(color: t.onMedia, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : CustomPaint(
                    foregroundPainter: _DashedRRect(color: t.bdStrong, radius: 16),
                    child: Container(
                      decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(16)),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ExcludeSemantics(child: Icon(LucideIcons.image, size: 24, color: t.mut)),
                          const SizedBox(height: 8),
                          Text(l10n.eventFormAddCover, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut)),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// Logo satırı (Stitch'te yok, davranış korunur): 48 dp daire + "Logo ekle/değiştir" metni.
  Widget _logoRow(BuTokens t) {
    final l10n = context.l10n;
    final tx = Theme.of(context).textTheme;
    final logoUrl = fileUrl(widget.club?['logoUrl']?.toString());
    final hasLogo = _logo != null || (logoUrl != null && !_logoRemoved);
    return Semantics(
      button: true,
      excludeSemantics: true,
      onTap: _busy ? null : () => _pick(logo: true),
      label: hasLogo ? l10n.p12LogoChange : l10n.p12LogoAdd,
      child: BuPressable(
        scale: .99,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _busy ? null : () => _pick(logo: true),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: hasLogo
                      ? ClipOval(
                          child: _logo != null
                              ? Image.memory(_logo!.bytes, fit: BoxFit.cover, gaplessPlayback: true)
                              : BuImage(widget.club?['logoUrl']?.toString(), width: 48, height: 48),
                        )
                      : CustomPaint(
                          foregroundPainter: _DashedRRect(color: t.bdStrong, radius: 48, circle: true),
                          child: Center(child: Icon(LucideIcons.imagePlus, size: 20, color: t.mut)),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(hasLogo ? l10n.p12LogoChange : l10n.p12LogoAdd, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
                      Text(l10n.p12LogoHint, style: tx.bodySmall!.copyWith(color: t.mut)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
      ..strokeWidth = 1;
    final rect = (Offset.zero & size).deflate(1);
    final path = Path()
      ..addRRect(circle
          ? RRect.fromRectAndRadius(rect, Radius.circular(size.shortestSide))
          : RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    for (final PathMetric m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 4), paint);
        d += 8;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRect old) =>
      old.color != color || old.radius != radius || old.circle != circle;
}
