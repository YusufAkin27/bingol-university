import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/platform/image_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'club_detail_page.dart';

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
        title: const Text('Kulübün onaya gönderildi'),
        content: const Text('Yöneticiler incelediğinde kulüp yayına girecek. Durumu Kulüplerim bölümünden izleyebilirsin.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Tamam'))],
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
          ? 'Görsel çok büyük.'
          : e.code == 'UNSUPPORTED_TYPE'
              ? 'Yalnızca JPEG, PNG veya WebP görseller yüklenebilir.'
              : 'Görsel okunamadı.');
    } catch (_) {
      _snack('Görsel seçilemedi.');
    }
  }

  bool _validate() {
    final e = <String, String>{};
    final n = _name.text.trim();
    if (n.length < 3) e['name'] = 'Kulüp adı en az 3 karakter olmalı.';
    if (n.length > 80) e['name'] = 'Kulüp adı en fazla 80 karakter olabilir.';
    if (_desc.text.trim().length > 1000) e['description'] = 'Açıklama en fazla 1000 karakter olabilir.';
    if (_category.text.trim().length > 40) e['category'] = 'Kategori en fazla 40 karakter olabilir.';
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
      if (warn) _snack('Kulüp kaydedildi ancak kapak ya da katılım soruları kaydedilemedi.');
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
    return Scaffold(
      backgroundColor: t.bg,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          BuHeader(title: _edit ? 'Kulübü düzenle' : 'Kulüp kur', onBack: () => Navigator.pop(context)),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _coverPicker(t),
                const SizedBox(height: 18),
                _label(t, 'Kulüp adı'),
                TextField(
                  controller: _name,
                  maxLength: 80,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  style: BuType.body.copyWith(color: t.ink),
                  decoration: InputDecoration(hintText: 'Örn. Robotik Kulübü', errorText: _errors['name']),
                ),
                const SizedBox(height: 8),
                _label(t, 'Kısa açıklama'),
                TextField(
                  controller: _desc,
                  maxLength: 1000,
                  minLines: 3,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  style: BuType.body.copyWith(color: t.ink),
                  decoration: InputDecoration(hintText: 'Kulüp ne yapıyor?', errorText: _errors['description']),
                ),
                const SizedBox(height: 8),
                _label(t, 'Kategori'),
                if (_categories.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in _categories)
                          BuChip(
                            label: c,
                            selected: _category.text.trim() == c,
                            onTap: () => setState(() => _category.text = _category.text.trim() == c ? '' : c),
                          ),
                      ],
                    ),
                  ),
                TextField(
                  controller: _category,
                  maxLength: 40,
                  onChanged: (_) => setState(() {}),
                  style: BuType.body.copyWith(color: t.ink),
                  decoration: InputDecoration(hintText: 'Listeden seç ya da yaz (isteğe bağlı)', errorText: _errors['category']),
                ),
                const SizedBox(height: 8),
                _label(t, 'Görünürlük'),
                BuSegmented(
                  items: const ['Herkese açık', 'Gizli'],
                  index: _visibility == 'PRIVATE' ? 1 : 0,
                  onChanged: (i) => setState(() => _visibility = i == 1 ? 'PRIVATE' : 'PUBLIC'),
                ),
                _hint(t, _visibility == 'PRIVATE'
                    ? 'Kulüp içeriğini yalnızca üyeler görür; katılım onayla olur.'
                    : 'Kulüp Keşfet listesinde görünür.'),
                const SizedBox(height: 16),
                _label(t, 'Katılım'),
                BuSegmented(
                  items: const ['Serbest', 'Onaylı'],
                  index: _policy == 'APPROVAL' ? 1 : 0,
                  onChanged: (i) => setState(() => _policy = i == 1 ? 'APPROVAL' : 'OPEN'),
                ),
                _hint(t, _policy == 'APPROVAL'
                    ? 'Katılmak isteyenler başvuru gönderir, sen onaylarsın.'
                    : 'Herkes doğrudan katılabilir.'),
                if (_askQuestions) ..._questionFields(t),
                if (_formError != null) ...[
                  const SizedBox(height: 14),
                  Text(_formError!, style: BuType.caption.copyWith(color: t.pr)),
                ],
                const SizedBox(height: 22),
                BuButton(label: _edit ? 'Kaydet' : 'Kulübü oluştur', busy: _busy, onPressed: _submit),
              ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(BuTokens t, String s) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(s, style: BuType.label.copyWith(color: t.ink)),
      );

  Widget _hint(BuTokens t, String s) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(s, style: BuType.caption.copyWith(color: t.mut)),
      );

  List<Widget> _questionFields(BuTokens t) => [
        const SizedBox(height: 18),
        _label(t, 'Katılım soruları (en çok $_maxQuestions)'),
        for (var i = 0; i < _questions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _questions[i],
                    maxLength: 200,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    style: BuType.body.copyWith(color: t.ink),
                    decoration: InputDecoration(hintText: 'Soru ${i + 1}'),
                  ),
                ),
                const SizedBox(width: 8),
                BuIconButton(
                  icon: LucideIcons.x,
                  size: 38,
                  tooltip: 'Soruyu kaldır',
                  onTap: () => setState(() => _questions.removeAt(i).dispose()),
                ),
              ],
            ),
          ),
        if (_questions.length < _maxQuestions)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BuButton(
              label: 'Soru ekle',
              icon: LucideIcons.plus,
              kind: BuButtonKind.outline,
              compact: true,
              onPressed: () => setState(() => _questions.add(TextEditingController())),
            ),
          ),
      ];

  Widget _coverPicker(BuTokens t) {
    final existing = fileUrl(widget.club?['coverUrl']?.toString());
    final has = _cover != null || existing != null;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Material(
            color: t.sf,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: t.bd)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _busy ? null : _pickCover,
              child: _cover != null
                  ? Image.memory(_cover!.bytes, fit: BoxFit.cover, gaplessPlayback: true)
                  : existing != null
                      ? Image.network(existing, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _coverEmpty(t))
                      : _coverEmpty(t),
            ),
          ),
          if (has)
            PositionedDirectional(
              end: 10,
              bottom: 10,
              child: BuIconButton(icon: LucideIcons.camera, size: 44, tooltip: 'Kapağı değiştir', onTap: _busy ? null : _pickCover),
            ),
        ],
      ),
    );
  }

  Widget _coverEmpty(BuTokens t) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.image, size: 25, color: t.mut),
          const SizedBox(height: 6),
          Text('Kapak ekle (isteğe bağlı)', style: BuType.caption.copyWith(color: t.mut)),
        ],
      );
}
