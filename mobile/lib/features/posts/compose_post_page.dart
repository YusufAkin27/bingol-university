import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../chat/media_camera_page.dart';
import '../chat/media_library.dart';
import '../chat/media_pick.dart';
import '../chat/media_picker_page.dart';
import 'post_api.dart';
import 'post_draft_store.dart';
import 'post_media_uploader.dart';
import 'post_models.dart';

const kPostMaxText = 2000;
const kPostCounterFrom = 1800;
const kPostMaxMedia = 10;
const kPostParallelUploads = 3;

/// Oluşturucuyu tam ekran açar; paylaşılırsa oluşan [Post] döner, kapatılırsa null.
Future<Post?> openComposePost(BuildContext context, Session session) => Navigator.of(context).push<Post>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => ComposePostPage(session: session)),
    );

enum _St { idle, uploading, done, failed }

class _Item {
  _Item(this.pick) : thumbFuture = pick.thumb(240);
  final MediaPick pick;
  final Future<Uint8List?> thumbFuture;
  _St st = _St.idle;
  double progress = 0;
  PostMedia? media;
  String? error;
  bool retryable = true;
  PostUploadCancel? cancel;

  String get key => pick.key;
}

/// Gönderi oluşturucu: metin (<=2000) + en çok 10 medya (foto/video karışık), sıralama, yükleme ilerlemesi,
/// öğe başına yeniden deneme ve 24 saatlik taslak koruması.
class ComposePostPage extends StatefulWidget {
  const ComposePostPage({
    super.key,
    required this.session,
    this.initialText,
    this.initialMedia = const [],
    this.library,
    this.ensureAccess,
    this.openCamera,
    this.uploader,
    this.api,
    this.draftStore,
  });

  final Session session;
  final String? initialText;
  final List<MediaPick> initialMedia;

  /// Testler için: galeri/izin/kamera/yükleyici/API/taslak deposu enjeksiyonu.
  final MediaLibrary? library;
  final EnsureAccess? ensureAccess;
  final MediaCameraLauncher? openCamera;
  final PostMediaUploader? uploader;
  final PostApi? api;
  final PostDraftStore? draftStore;

  @override
  State<ComposePostPage> createState() => _ComposePostPageState();
}

class _ComposePostPageState extends State<ComposePostPage> with WidgetsBindingObserver {
  late final TextEditingController _text = TextEditingController(text: widget.initialText ?? '');
  final _focus = FocusNode();
  final _items = <_Item>[];
  late final PostMediaUploader _uploader = widget.uploader ?? PostMediaUploader(widget.session);
  late final PostApi _api = widget.api ?? PostApi(widget.session);
  late final PostDraftStore _drafts = widget.draftStore ?? PostDraftStore();

  bool _publishing = false;
  bool _done = false; // paylaşıldı ya da vazgeçildi: taslak artık yazılmaz
  String? _textError;
  String? _notice; // üst bilgi/hata şeridi (yükleme özeti)
  PostDraft? _draft;
  Timer? _saveTimer;

  int? get _uid => widget.session.userId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    for (final p in widget.initialMedia.take(kPostMaxMedia)) {
      _items.add(_Item(p));
    }
    _lastText = _text.text;
    _text.addListener(_onTextChanged);
    if ((widget.initialText ?? '').isEmpty && widget.initialMedia.isEmpty) _loadDraft();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    for (final i in _items) {
      i.cancel?.cancel();
    }
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) _saveNow();
  }

  // ---------- Taslak ----------

  Future<void> _loadDraft() async {
    final d = await _drafts.load(_uid);
    if (!mounted || d == null) return;
    setState(() => _draft = d);
  }

  Future<void> _restoreDraft() async {
    final d = _draft;
    if (d == null) return;
    final picks = <MediaPick>[];
    for (final m in d.items) {
      final p = m.toPick();
      if (p != null) picks.add(p);
    }
    setState(() {
      _draft = null;
      _text.text = d.text;
      _text.selection = TextSelection.collapsed(offset: d.text.length);
      _items
        ..clear()
        ..addAll(picks.take(kPostMaxMedia).map(_Item.new));
    });
  }

  Future<void> _dropDraft() async {
    setState(() => _draft = null);
    await _drafts.clear(_uid);
  }

  void _scheduleSave() {
    if (_done) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), _saveNow);
  }

  Future<void> _saveNow() async {
    if (_done) return;
    _saveTimer?.cancel();
    final text = _text.text;
    final picks = [for (final i in _items) i.pick];
    final saved = <DraftMedia>[];
    for (final p in picks) {
      final m = await _drafts.materialize(p);
      if (m != null) saved.add(m);
    }
    if (_done) return;
    await _drafts.save(_uid, PostDraft(text: text, items: saved, savedAt: DateTime.now()));
  }

  // ---------- Durum ----------

  bool get _dirty => _text.text.trim().isNotEmpty || _items.isNotEmpty;
  bool get _canShare => !_publishing && _dirty;

  String _lastText = '';

  void _onTextChanged() {
    // Seçim/odak değişimi de dinleyiciyi tetikler: yalnız metin değiştiyse hata temizlenir.
    if (_text.text == _lastText) return;
    _lastText = _text.text;
    if (_textError != null) _textError = null;
    setState(() {});
    _scheduleSave();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
  }

  // ---------- Medya ekleme ----------

  void _addPicks(Iterable<MediaPick> picks) {
    var skipped = false;
    setState(() {
      for (final p in picks) {
        if (_items.any((i) => i.key == p.key)) continue;
        if (_items.length >= kPostMaxMedia) {
          skipped = true;
          break;
        }
        _items.add(_Item(p));
      }
      _notice = null;
    });
    if (skipped) _toast('En fazla $kPostMaxMedia medya ekleyebilirsin');
    _scheduleSave();
  }

  Future<void> _openGallery() async {
    if (_publishing) return;
    final room = kPostMaxMedia - _items.length;
    if (room <= 0) {
      _toast('En fazla $kPostMaxMedia medya ekleyebilirsin');
      return;
    }
    FocusScope.of(context).unfocus();
    final plan = await Navigator.push<MediaSendPlan>(
      context,
      MaterialPageRoute(
        builder: (_) => MediaPickerPage(
          library: widget.library ?? PhotoManagerLibrary(),
          ensureAccess: widget.ensureAccess,
          openCamera: widget.openCamera,
          maxItems: room,
        ),
      ),
    );
    if (plan == null || !mounted) return;
    _addPicks(plan.items.map((e) => e.pick));
  }

  Future<void> _openCamera() async {
    if (_publishing) return;
    if (_items.length >= kPostMaxMedia) {
      _toast('En fazla $kPostMaxMedia medya ekleyebilirsin');
      return;
    }
    FocusScope.of(context).unfocus();
    final pick = await (widget.openCamera ?? openMediaCamera)(context);
    if (pick == null || !mounted) return;
    _addPicks([pick]);
  }

  void _remove(_Item it) {
    if (_publishing) return;
    it.cancel?.cancel();
    setState(() => _items.remove(it));
    _scheduleSave();
  }

  void _reorder(int from, int to) {
    if (_publishing) return;
    setState(() {
      final it = _items.removeAt(from);
      _items.insert(to, it);
    });
    _scheduleSave();
  }

  // ---------- Paylaş ----------

  Future<void> _uploadOne(_Item it) async {
    final cancel = PostUploadCancel();
    it.cancel = cancel;
    if (mounted) {
      setState(() {
        it.st = _St.uploading;
        it.progress = 0;
        it.error = null;
      });
    }
    try {
      final m = await _uploader.upload(it.pick, cancel: cancel, onProgress: (p) {
        if (!mounted) return;
        setState(() => it.progress = p);
      });
      it.media = m;
      it.st = _St.done;
      it.progress = 1;
    } catch (e) {
      it.st = _St.failed;
      it.error = postErrorText(e);
      it.retryable = e is! PostUploadException || e.retryable;
    } finally {
      it.cancel = null;
    }
    if (mounted) setState(() {});
  }

  /// Bekleyen öğeleri en çok [kPostParallelUploads] paralel, sırayla yükler.
  Future<void> _uploadAll() async {
    final queue = [for (final i in _items) if (i.st != _St.done) i];
    var next = 0;
    Future<void> worker() async {
      while (mounted && next < queue.length) {
        final it = queue[next++];
        await _uploadOne(it);
      }
    }

    await Future.wait([for (var i = 0; i < kPostParallelUploads && i < queue.length; i++) worker()]);
  }

  Future<void> _publish() async {
    if (!_canShare) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _publishing = true;
      _textError = null;
      _notice = null;
    });
    await _uploadAll();
    if (!mounted) return;

    final failed = _items.where((i) => i.st != _St.done).toList();
    if (failed.isNotEmpty) {
      setState(() {
        _publishing = false;
        _notice = '${failed.length} medya yüklenemedi. Yeniden deneyebilir ya da çıkarabilirsin.';
      });
      _saveNow();
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final post = await _api.create(text: _text.text, mediaIds: [for (final i in _items) i.media!.id]);
      if (!mounted) return;
      _done = true;
      _saveTimer?.cancel();
      unawaited(_drafts.clear(_uid));
      messenger?.showSnackBar(const SnackBar(content: Text('Paylaşıldı'), duration: Duration(seconds: 2)));
      Navigator.pop(context, post);
    } catch (e) {
      if (!mounted) return;
      _onCreateError(e);
    }
  }

  void _onCreateError(Object e) {
    setState(() => _publishing = false);
    if (e is ApiError) {
      if (e.code == 'CONTENT_PROFANITY') {
        setState(() => _textError = postErrorText(e));
        _focus.requestFocus();
        _saveNow();
        return;
      }
      if (e.code == 'POST_MEDIA_INVALID') {
        // Sunucu bağlantıyı reddetti: yüklenenler geçersiz sayılır, yeniden yüklenir.
        setState(() {
          for (final i in _items) {
            i.st = _St.idle;
            i.media = null;
          }
          _notice = 'Medya geçersiz, yeniden yüklenecek. Paylaş\'a tekrar dokun.';
        });
        return;
      }
      if (e.isNetwork) {
        _toast('Bağlantı yok. Taslağın korundu, tekrar dene.');
        _saveNow();
        return;
      }
    }
    _toast(postErrorText(e));
    _saveNow();
  }

  Future<void> _retryItem(_Item it) async {
    if (_publishing) return;
    setState(() => _publishing = true);
    await _uploadOne(it);
    if (!mounted) return;
    setState(() {
      _publishing = false;
      if (_items.every((i) => i.st != _St.failed)) _notice = null;
    });
  }

  Future<void> _retryFailed() async {
    if (_publishing) return;
    setState(() {
      _publishing = true;
      _notice = null;
    });
    final failed = [for (final i in _items) if (i.st == _St.failed) i];
    await Future.wait([for (final i in failed) _uploadOne(i)]);
    if (!mounted) return;
    final left = _items.where((i) => i.st == _St.failed).length;
    setState(() {
      _publishing = false;
      _notice = left > 0 ? '$left medya yüklenemedi. Yeniden deneyebilir ya da çıkarabilirsin.' : null;
    });
  }

  void _removeFailed() {
    setState(() {
      _items.removeWhere((i) => i.st == _St.failed);
      _notice = null;
    });
    _scheduleSave();
  }

  // ---------- Kapatma ----------

  Future<bool> _confirmDiscard() async {
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Taslağı silmek istiyor musun?'),
        content: const Text('Yazdıkların ve seçtiğin medya silinecek.'),
        actions: [
          TextButton(key: const ValueKey('composeKeep'), onPressed: () => Navigator.pop(c, false), child: const Text('Devam')),
          TextButton(
            key: const ValueKey('composeDiscard'),
            onPressed: () => Navigator.pop(c, true),
            child: Text('Taslağı sil', style: TextStyle(color: c.bu.danger)),
          ),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _close() async {
    if (_dirty) {
      if (!await _confirmDiscard() || !mounted) return;
      _done = true;
      _saveTimer?.cancel();
      for (final i in _items) {
        i.cancel?.cancel();
      }
      unawaited(_drafts.clear(_uid));
    }
    if (mounted) Navigator.pop(context);
  }

  // ---------- Arayüz ----------

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final len = _text.text.characters.length;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: t.bg,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              _topBar(t),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    if (_draft != null) _draftBanner(t),
                    if (_notice != null) _noticeBar(t),
                    _authorRow(t),
                    const SizedBox(height: 10),
                    _field(t, len),
                    if (_items.isNotEmpty) ...[const SizedBox(height: 12), _strip(t)],
                  ],
                ),
              ),
              _toolbar(t, len),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuTokens t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
        child: Row(
          children: [
            IconButton(
              key: const ValueKey('composeClose'),
              tooltip: 'Kapat',
              icon: Icon(LucideIcons.x, color: t.ink),
              onPressed: _close,
            ),
            Expanded(child: Text('Yeni gönderi', style: BuType.heading.copyWith(color: t.ink), maxLines: 1, overflow: TextOverflow.ellipsis)),
            BuButton(
              key: const ValueKey('composeShare'),
              label: 'Paylaş',
              compact: true,
              busy: _publishing,
              onPressed: _canShare ? _publish : null,
            ),
          ],
        ),
      );

  Widget _draftBanner(BuTokens t) => Container(
        key: const ValueKey('composeDraftBanner'),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(LucideIcons.fileClock, size: 16, color: t.onSoft),
            const SizedBox(width: 8),
            Expanded(child: Text('Kayıtlı bir taslağın var.', style: BuType.label.copyWith(color: t.onSoft))),
            TextButton(key: const ValueKey('composeDraftRestore'), onPressed: _restoreDraft, child: const Text('Taslağı geri yükle')),
            IconButton(
              key: const ValueKey('composeDraftDrop'),
              tooltip: 'Taslağı sil',
              visualDensity: VisualDensity.compact,
              icon: Icon(LucideIcons.x, size: 16, color: t.onSoft),
              onPressed: _dropDraft,
            ),
          ],
        ),
      );

  Widget _noticeBar(BuTokens t) => Container(
        key: const ValueKey('composeNotice'),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_notice!, style: BuType.label.copyWith(color: t.onSoft)),
            if (_items.any((i) => i.st == _St.failed)) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                children: [
                  TextButton(key: const ValueKey('composeRetryFailed'), onPressed: _retryFailed, child: const Text('Yeniden dene')),
                  TextButton(key: const ValueKey('composeRemoveFailed'), onPressed: _removeFailed, child: const Text('Başarısızları çıkar')),
                ],
              ),
            ],
          ],
        ),
      );

  Widget _authorRow(BuTokens t) => Row(
        children: [
          BuAvatar(name: widget.session.displayName, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Text(widget.session.displayName ?? '',
                style: BuType.bodyStrong.copyWith(color: t.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      );

  Widget _field(BuTokens t, int len) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('composeText'),
            controller: _text,
            focusNode: _focus,
            enabled: !_publishing,
            minLines: 5,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(kPostMaxText)],
            style: BuType.body.copyWith(color: t.ink),
            decoration: InputDecoration(
              hintText: 'Ne düşünüyorsun?',
              hintStyle: BuType.body.copyWith(color: t.mut),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          if (_textError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_textError!, key: const ValueKey('composeTextError'), style: BuType.label.copyWith(color: t.danger)),
            ),
        ],
      );

  Widget _strip(BuTokens t) => SizedBox(
        key: const ValueKey('composeStrip'),
        height: 92,
        child: ReorderableListView.builder(
          scrollDirection: Axis.horizontal,
          buildDefaultDragHandles: false,
          itemCount: _items.length,
          onReorderItem: _reorder,
          proxyDecorator: (child, i, a) => Material(color: Colors.transparent, child: child),
          itemBuilder: (c, i) {
            final it = _items[i];
            return ReorderableDelayedDragStartListener(
              key: ValueKey('composeItem_${it.key}'),
              index: i,
              enabled: !_publishing,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _tile(t, it),
              ),
            );
          },
        ),
      );

  Widget _tile(BuTokens t, _Item it) {
    const s = 84.0;
    final failed = it.st == _St.failed;
    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FutureBuilder<Uint8List?>(
              future: it.thumbFuture,
              builder: (c, snap) {
                final b = snap.data;
                if (b == null) {
                  return ColoredBox(
                      color: t.sf2,
                      child: Icon(it.pick.isVideo ? LucideIcons.video : LucideIcons.image, color: t.mut));
                }
                return Image.memory(b, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, __, ___) => ColoredBox(color: t.sf2));
              },
            ),
          ),
          if (it.pick.isVideo)
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(LucideIcons.play, size: 9, color: Colors.white),
                  const SizedBox(width: 3),
                  Text(_dur(it.pick.durationMs), style: BuType.micro.copyWith(color: Colors.white)),
                ]),
              ),
            ),
          if (it.st == _St.uploading)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ColoredBox(
                  color: Colors.black45,
                  child: Center(
                    child: SizedBox(
                      key: ValueKey('composeProgress_${it.key}'),
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(value: it.progress.clamp(0.02, 1.0), strokeWidth: 3, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          if (it.st == _St.done)
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                key: ValueKey('composeDone_${it.key}'),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: t.ok, shape: BoxShape.circle),
                child: const Icon(LucideIcons.check, size: 11, color: Colors.white),
              ),
            ),
          if (failed)
            Positioned.fill(
              child: GestureDetector(
                key: ValueKey('composeRetry_${it.key}'),
                onTap: it.retryable ? () => _retryItem(it) : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ColoredBox(
                    color: t.danger.withValues(alpha: .78),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.triangleAlert, size: 18, color: Colors.white),
                        const SizedBox(height: 2),
                        Text(it.retryable ? 'Yeniden dene' : 'Çıkar',
                            textAlign: TextAlign.center, style: BuType.micro.copyWith(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (!_publishing)
            Positioned(
              right: 2,
              top: 2,
              child: GestureDetector(
                key: ValueKey('composeRemove_${it.key}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _remove(it),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(LucideIcons.x, size: 13, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _dur(int ms) {
    final s = (ms / 1000).round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Widget _toolbar(BuTokens t, int len) => Container(
        decoration: BoxDecoration(color: t.sf, border: Border(top: BorderSide(color: t.bd))),
        padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
        child: Row(
          children: [
            IconButton(
              key: const ValueKey('composeGallery'),
              tooltip: 'Galeri',
              icon: Icon(LucideIcons.image, color: t.pr),
              onPressed: _publishing ? null : _openGallery,
            ),
            IconButton(
              key: const ValueKey('composeCamera'),
              tooltip: 'Kamera',
              icon: Icon(LucideIcons.camera, color: t.pr),
              onPressed: _publishing ? null : _openCamera,
            ),
            if (_items.isNotEmpty)
              Text('${_items.length}/$kPostMaxMedia', key: const ValueKey('composeMediaCount'), style: BuType.label.copyWith(color: t.mut)),
            const Spacer(),
            if (len >= kPostCounterFrom)
              Text('$len/$kPostMaxText',
                  key: const ValueKey('composeCounter'),
                  style: BuType.label.copyWith(color: len >= kPostMaxText ? t.danger : t.mut)),
          ],
        ),
      );
}
