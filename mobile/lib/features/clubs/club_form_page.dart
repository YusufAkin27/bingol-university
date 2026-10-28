import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/platform/image_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'club_detail_page.dart';
import 'kulup_widgets.dart';

/// Kulüp kurma akışını başlatır: form -> sonuç. ACTIVE ise kulüp sayfasına gider,
/// onaya düştüyse bilgi verir. Dönüş: kulüp oluşturuldu mu (liste yenilensin).
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
      MaterialPageRoute(builder: (_) => ClubDetailPage(session: session, communityId: id)),
    );
  } else if (context.mounted) {
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(c.l10n.clubMgmtPendingTitle),
        content: Text(c.l10n.clubMgmtPendingBody),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(c.l10n.clubMgmtOk))],
      ),
    );
  }
  return true;
}

/// Kulüp kur / düzenle: tek ekranlı form. [club] verilirse düzenleme (PATCH), yoksa kurma (POST).
class ClubFormPage extends StatefulWidget {
  const ClubFormPage({super.key, required this.session, this.club});

  final Session session;
  final Map<String, dynamic>? club;

  @override
  State<ClubFormPage> createState() => _ClubFormPageState();
}

class _ClubFormPageState extends State<ClubFormPage> {
  static const _maxQuestions = 3;

  late final _name = TextEditingController(text: (widget.club?['name'] ?? '').toString());
  late final _desc = TextEditingController(text: (widget.club?['description'] ?? '').toString());
  late final _category = TextEditingController(text: (widget.club?['category'] ?? '').toString());
  late String _visibility = widget.club?['visibility'] == 'PRIVATE' ? 'PRIVATE' : 'PUBLIC';
  late String _policy = widget.club?['joinPolicy'] == 'APPROVAL' ? 'APPROVAL' : 'OPEN';
  final _questions = <TextEditingController>[];
  List<String> _origQuestions = const [];
  List<String> _categories = const [];
  PreparedImage? _cover;
  final _images = ImageService();
  final _scroll = ScrollController();

  bool _busy = false;
  final _errors = <String, String>{};
  String? _formError;

  bool get _edit => widget.club != null;
  int? get _id => (widget.club?['id'] as num?)?.toInt();
  bool get _askQuestions => _policy == 'APPROVAL' || _visibility == 'PRIVATE';

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (_edit) _loadQuestions();
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _category.dispose();
    _scroll.dispose();
    for (final c in _questions) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final res = await widget.session.api.get('/communities/categories');
      if (!mounted || res is! List) return;
      setState(() => _categories = [
            for (final e in res)
              if (e is Map && (e['category']?.toString().trim() ?? '').isNotEmpty) e['category'].toString().trim(),
          ]);
    } catch (_) {}
  }

  Future<void> _loadQuestions() async {
    try {
      final res = await widget.session.api.get('/communities/$_id/join-questions');
      if (!mounted || res is! List) return;
      final qs = [for (final e in res.whereType<Map>()) (e['question'] ?? '').toString()];
      setState(() {
        _origQuestions = qs;
        for (final q in qs.take(_maxQuestions)) {
          _questions.add(TextEditingController(text: q));
        }
      });
    } catch (_) {}
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickCover() async {
    try {
      final img = await _images.pickPrepared(ImageSource.gallery);
      if (img != null && mounted) setState(() => _cover = img);
    } on ImageException catch (e) {
      _snack(e.code == 'TOO_LARGE'
          ? context.l10n.clubMgmtImageTooLarge
          : e.code == 'UNSUPPORTED_TYPE'
              ? context.l10n.clubMgmtImageUnsupported
              : context.l10n.clubMgmtImageUnreadable);
    } catch (_) {
      _snack(context.l10n.clubMgmtImagePickFailed);
    }
  }

  bool _validate() {
    final e = <String, String>{};
    final n = _name.text.trim();
    if (n.length < 3) e['name'] = context.l10n.clubMgmtNameMin;
    if (n.length > 80) e['name'] = context.l10n.clubMgmtNameMax;
    if (_desc.text.trim().length > 1000) e['description'] = context.l10n.clubMgmtDescMax;
    if (_category.text.trim().length > 40) e['category'] = context.l10n.clubMgmtCategoryMax;
    setState(() {
      _errors
        ..clear()
        ..addAll(e);
      _formError = null;
    });
    if (e.isNotEmpty && _scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    return e.isEmpty;
  }

  /// Sunucu `alan: mesaj` biçiminde doğrulama hatası dönerse alanın altına yazar.
  void _applyServerError(Object err) {
    if (err is ApiError && err.code == 'VALIDATION_ERROR') {
      final m = RegExp(r'^(\w+):\s*(.+)$').firstMatch(err.message);
      if (m != null && const {'name', 'description', 'category'}.contains(m.group(1))) {
        setState(() => _errors[m.group(1)!] = m.group(2)!);
        return;
      }
    }
    setState(() => _formError = errorText(err));
  }

  List<String> get _questionTexts =>
      [for (final c in _questions) c.text.trim()].where((q) => q.isNotEmpty).toList();

  Future<void> _submit() async {
    if (_busy || !_validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final api = widget.session.api;
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'description': _desc.text.trim(),
      'category': _category.text.trim(),
      'joinPolicy': _policy,
      'visibility': _visibility,
    };
    try {
      Map<String, dynamic> result;
      if (_edit) {
        await api.patch('/communities/$_id', body);
        result = {'updated': true, 'id': _id};
      } else {
        // Boş açıklama/kategori hiç gönderilmez.
        if ((body['description'] as String).isEmpty) body.remove('description');
        if ((body['category'] as String).isEmpty) body.remove('category');
        final res = await api.post('/communities', body);
        final m = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
        final st = (m['status'] ?? '').toString();
        result = {'id': (m['id'] as num?)?.toInt(), 'status': st == 'ACTIVE' ? 'ACTIVE' : 'PENDING'};
      }
      final id = (result['id'] as num?)?.toInt();
      // Sonraki adımlar kulüp kurulduktan sonra çalışır; hata kurmayı geri almaz, yalnız bilgi verilir.
      var warn = false;
      if (id != null) {
        final qs = _askQuestions ? _questionTexts : <String>[];
        if (qs.join('\u0001') != _origQuestions.join('\u0001') && (_edit || qs.isNotEmpty)) {
          try {
            await api.put('/communities/$id/join-questions', {'questions': qs});
          } catch (_) {
            warn = true;
          }
        }
        if (_cover != null) {
          try {
            await MultipartUploader(widget.session).upload('/communities/$id/cover', _cover!);
          } catch (_) {
            warn = true;
          }
        }
      }
      if (!mounted) return;
      if (warn) _snack(context.l10n.clubMgmtSavedWithWarning);
      Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _applyServerError(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: t.bg,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          BuHeader(title: _edit ? l10n.clubMgmtEditTitle : l10n.kulupdetayCreateTitle, onBack: () => Navigator.pop(context)),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _coverPicker(t),
                  const SizedBox(height: 14),
                  _label(t, l10n.clubMgmtNameLabel),
                  TextField(
                    controller: _name,
                    maxLength: 80,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    style: BuType.body.copyWith(fontSize: 14.5, color: t.ink),
                    decoration: kulupField(context, hint: l10n.clubMgmtNameHint, error: _errors['name']),
                  ),
                  const SizedBox(height: 14),
                  _label(t, l10n.clubMgmtDescLabel),
                  TextField(
                    controller: _desc,
                    maxLength: 1000,
                    minLines: 3,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    style: BuType.body.copyWith(fontSize: 14.5, color: t.ink),
                    decoration: kulupField(context,
                        hint: l10n.clubMgmtDescHint,
                        error: _errors['description'],
                        pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                  ),
                  const SizedBox(height: 14),
                  _label(t, l10n.clubMgmtCategoryLabel),
                  if (_categories.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in _categories)
                          _choiceChip(t, c, _category.text.trim() == c,
                              () => setState(() => _category.text = _category.text.trim() == c ? '' : c)),
                      ],
                    ),
                  if (_categories.isEmpty || (_category.text.trim().isNotEmpty && !_categories.contains(_category.text.trim())))
                    Padding(
                      padding: EdgeInsets.only(top: _categories.isEmpty ? 0 : 8),
                      child: TextField(
                        controller: _category,
                        maxLength: 40,
                        onChanged: (_) => setState(() {}),
                        style: BuType.body.copyWith(fontSize: 14.5, color: t.ink),
                        decoration: kulupField(context, hint: l10n.clubMgmtCategoryHint, error: _errors['category']),
                      ),
                    ),
                  if (_errors['category'] != null && _categories.isNotEmpty && _categories.contains(_category.text.trim()))
                    _hint(t, _errors['category']!, error: true),
                  const SizedBox(height: 14),
                  _label(t, l10n.clubMgmtVisibility),
                  _segGroup(
                    t,
                    [l10n.clubMgmtPublic, l10n.clubMgmtPrivate],
                    _visibility == 'PRIVATE' ? 1 : 0,
                    (i) => setState(() => _visibility = i == 1 ? 'PRIVATE' : 'PUBLIC'),
                  ),
                  _hint(t, _visibility == 'PRIVATE' ? l10n.clubMgmtPrivateHint : l10n.clubMgmtPublicHint),
                  const SizedBox(height: 14),
                  _label(t, l10n.clubMgmtJoinLabel),
                  _segGroup(
                    t,
                    [l10n.clubMgmtOpenPolicy, l10n.clubMgmtApprovalPolicy],
                    _policy == 'APPROVAL' ? 1 : 0,
                    (i) => setState(() => _policy = i == 1 ? 'APPROVAL' : 'OPEN'),
                  ),
                  _hint(t, _policy == 'APPROVAL' ? l10n.clubMgmtApprovalHint : l10n.clubMgmtOpenHint),
                  if (_askQuestions) ..._questionFields(t),
                  if (_formError != null) ...[
                    const SizedBox(height: 14),
                    Text(_formError!, style: BuType.caption.copyWith(color: t.pr)),
                  ],
                ],
              ),
            ),
          ),
          // Sabit alt çubuk: üstte yumuşak geçiş.
          Container(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + MediaQuery.of(context).padding.bottom.clamp(0, 10)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: const [.75, 1],
                colors: [t.bg, t.bg.withValues(alpha: 0)],
              ),
            ),
            child: BuButton(label: _edit ? l10n.clubMgmtSave : l10n.clubMgmtCreateButton, busy: _busy, onPressed: _submit),
          ),
        ],
      ),
    );
  }

  Widget _label(BuTokens t, String s) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Semantics(
          header: false,
          child: Text(s, style: BuType.bodyStrong.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
        ),
      );

  Widget _hint(BuTokens t, String s, {bool error = false}) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
        child: Text(s, style: BuType.caption.copyWith(fontSize: 12, height: 1.4, color: error ? t.pr : t.mut)),
      );

  /// Kategori çipi: 44 dp, hap; seçili: yumuşak kırmızı zemin + kırmızı çizgi.
  Widget _choiceChip(BuTokens t, String label, bool on, VoidCallback onTap) => Semantics(
        button: true,
        selected: on,
        child: Material(
          color: on ? t.soft : t.sf,
          shape: StadiumBorder(side: BorderSide(color: on ? t.pr : t.bd, width: 1.5)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Center(
                  widthFactor: 1,
                  child: Text(label, style: BuType.bodyStrong.copyWith(color: on ? t.pr : t.ink)),
                ),
              ),
            ),
          ),
        ),
      );

  /// İki/üç seçenekli grup: beyaz zemin, 1.5 dp çizgi, seçili parça kırmızı dolgu.
  Widget _segGroup(BuTokens t, List<String> items, int index, ValueChanged<int> onChanged) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: t.sf,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.bd, width: 1.5),
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == index,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == index ? t.pr : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(items[i],
                            maxLines: 1,
                            style: BuType.bodyStrong.copyWith(
                                fontWeight: FontWeight.w700, color: i == index ? t.onPr : t.mut)),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  List<Widget> _questionFields(BuTokens t) => [
        const SizedBox(height: 14),
        _label(t, context.l10n.clubMgmtQuestionsLabel('$_maxQuestions')),
        for (var i = 0; i < _questions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _questions[i],
                    maxLength: 200,
                    style: BuType.body.copyWith(fontSize: 14.5, color: t.ink),
                    decoration: kulupField(context, hint: context.l10n.clubMgmtQuestionHint('${i + 1}')),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: context.l10n.clubMgmtRemoveQuestion,
                  child: Tooltip(
                    message: context.l10n.clubMgmtRemoveQuestion,
                    excludeFromSemantics: true,
                    child: Material(
                      color: t.sf,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: t.bd)),
                      child: InkWell(
                        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        onTap: () => setState(() => _questions.removeAt(i).dispose()),
                        child: SizedBox(width: 44, height: 44, child: Icon(LucideIcons.x, size: 18, color: t.mut)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_questions.length < _maxQuestions)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: t.pr,
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                textStyle: BuType.bodyStrong.copyWith(fontWeight: FontWeight.w700),
              ),
              onPressed: () => setState(() => _questions.add(TextEditingController())),
              icon: Icon(LucideIcons.plus, size: 18, color: t.pr),
              label: Text(context.l10n.clubMgmtAddQuestion),
            ),
          ),
      ];

  /// Kapak: 120 dp, gradyan + dairesel süs; seçilince/mevcutsa görsel. Sağ altta beyaz kamera düğmesi.
  Widget _coverPicker(BuTokens t) {
    final existing = fileUrl(widget.club?['coverUrl']?.toString());
    const circle = Colors.white;
    return SizedBox(
      height: 120,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(decoration: BoxDecoration(gradient: t.hero)),
            if (_cover != null)
              Image.memory(_cover!.bytes, fit: BoxFit.cover, gaplessPlayback: true)
            else if (existing != null)
              Image.network(existing, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink())
            else ...[
              PositionedDirectional(
                  end: -30,
                  top: -40,
                  child: Container(
                      width: 150, height: 150, decoration: BoxDecoration(color: circle.withValues(alpha: .15), shape: BoxShape.circle))),
              PositionedDirectional(
                  start: -20,
                  bottom: -50,
                  child: Container(
                      width: 120, height: 120, decoration: BoxDecoration(color: circle.withValues(alpha: .10), shape: BoxShape.circle))),
            ],
            PositionedDirectional(
              end: 12,
              bottom: 12,
              child: Semantics(
                button: true,
                label: context.l10n.clubMgmtChangeCover,
                child: Tooltip(
                  message: context.l10n.clubMgmtChangeCover,
                  excludeFromSemantics: true,
                  child: Material(
                    color: t.sf,
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _busy ? null : _pickCover,
                      child: SizedBox(width: 44, height: 44, child: Icon(LucideIcons.camera, size: 20, color: t.ink)),
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
