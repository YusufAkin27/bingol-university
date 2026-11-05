import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/api.dart';
import '../../../../core/locale_controller.dart';
import '../../../../core/platform/image_service.dart';
import '../../../../core/session.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../widgets/bu.dart';
import '../../../posts/post_models.dart' show postAuthHeaders;
import '../../data/forum_api.dart';
import '../../data/forum_compose_errors.dart';
import '../../data/forum_compose_rules.dart';
import '../../data/forum_draft_store.dart';
import '../../data/forum_models.dart';
import '../../forum_routes.dart' show openTopicDetail;
import '../widgets/compose_image_strip.dart';
import '../widgets/compose_widgets.dart';
import '../widgets/poll_builder.dart';

/// Galeriden/kameradan tek görsel baytı (iptalde null); testlerde sahtesi verilir.
typedef ForumPhotoPicker = Future<Uint8List?> Function(ImageSource source);

/// Görseli yükler (`POST /forum/media`); testlerde sahtesi verilir.
typedef ForumImageUploader = Future<ForumImage> Function(Uint8List bytes);

Future<Uint8List?> _defaultPick(ImageSource source) async {
  final f = await ImageService().pick(source);
  return f?.readAsBytes();
}

enum _Leave { save, discard, keep }

/// Yeni konu formu: başlık, açıklama, kategori, en çok 4 görsel, isteğe bağlı anket, anonim paylaşım.
///
/// * Görseller TEK TEK yüklenir; hepsi yüklenmeden "Yayınla" pasiftir.
/// * Çift dokunma tek istek üretir; her gönderim niyeti bir `Idempotency-Key` taşır (aynı içerikle yeniden
///   denemede AYNI anahtar).
/// * Hatada yazılan her şey korunur. Yazarken taslak otomatik kaydedilir; çıkışta değişiklik varsa sorulur.
/// * Başarıda konu detayı açılır ve bu ekran yığından çıkar; çağırana oluşan konunun özeti döner.
class CreateTopicPage extends StatefulWidget {
  const CreateTopicPage({
    super.key,
    required this.session,
    this.categoryId,
    this.api,
    this.pickPhoto,
    this.uploader,
    this.drafts,
    this.draftDebounce = const Duration(milliseconds: 800),
    this.now,
  });

  final Session session;

  /// Önceden seçili kategori (örn. kategori çipinden "Yeni konu").
  final int? categoryId;

  /// Testler için enjeksiyon.
  final ForumApi? api;
  final ForumPhotoPicker? pickPhoto;
  final ForumImageUploader? uploader;
  final ForumDraftStore? drafts;
  final Duration draftDebounce;
  final DateTime Function()? now;

  @override
  State<CreateTopicPage> createState() => _CreateTopicPageState();
}

class _CreateTopicPageState extends State<CreateTopicPage> {
  late final ForumApi _api = widget.api ?? ForumApi(widget.session);
  late final ForumDraftStore _drafts = widget.drafts ?? ForumDraftStore();
  late final ForumImageUploader _upload = widget.uploader ?? ((b) => _api.uploadImage(b));
  late final ForumPhotoPicker _pick = widget.pickPhoto ?? _defaultPick;

  final _title = TextEditingController();
  final _body = TextEditingController();
  final _titleFocus = FocusNode();
  final _bodyFocus = FocusNode();
  final _scroll = ScrollController();

  List<ForumCategory> _cats = const [];
  bool _catsLoading = true;
  bool _catsFailed = false;
  int? _categoryId;

  final List<ComposeImage> _images = [];
  PollDraft? _poll;
  Key _pollKey = UniqueKey();
  bool _anonymous = false;

  bool _publishing = false;
  bool _touched = false; // bu oturumda kullanıcı bir şey değiştirdi
  bool _skipFlush = false; // yayınlandı / taslak silindi: çıkışta taslak yazma
  String? _error;
  Timer? _saveTimer;
  String? _sig;
  String? _key;

  int? get _uid => widget.session.userId;
  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _categoryId = widget.categoryId;
    _loadCategories();
    _restoreDraft();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    if (!_skipFlush && _touched) {
      // Çıkış anında son durum taslağa yazılır (boşsa taslak silinir); sonucu beklenmez.
      unawaited(_drafts.save(_uid, _snapshot()));
    }
    _title.dispose();
    _body.dispose();
    _titleFocus.dispose();
    _bodyFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---- Yükleme ---------------------------------------------------------------------------------------------

  Future<void> _loadCategories() async {
    setState(() {
      _catsLoading = true;
      _catsFailed = false;
    });
    try {
      final c = await _api.categories(force: true);
      if (!mounted) return;
      setState(() {
        _cats = c;
        _catsLoading = false;
        // Seçili kategori artık listede yoksa (arşivlendi) seçim temizlenir.
        if (_categoryId != null && c.isNotEmpty && !c.any((e) => e.id == _categoryId)) _categoryId = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _catsLoading = false;
        _catsFailed = true;
      });
    }
  }

  Future<void> _restoreDraft() async {
    final d = await _drafts.load(_uid);
    // Kullanıcı bu arada yazmaya başladıysa taslak ezilmez.
    if (d == null || !mounted || _touched) return;
    _title.text = d.title;
    _body.text = d.body;
    setState(() {
      _categoryId = d.categoryId ?? _categoryId;
      _anonymous = d.anonymous;
      _images
        ..clear()
        ..addAll(d.images.map(ComposeImage.restored));
      _poll = d.poll;
      _pollKey = UniqueKey();
    });
    BuToast.show(context, context.l10n.forumComposeDraftRestored, kind: BuToastKind.info, duration: const Duration(seconds: 2));
  }

  // ---- Durum -----------------------------------------------------------------------------------------------

  ForumDraft _snapshot() => ForumDraft(
        title: _title.text,
        body: _body.text,
        categoryId: _categoryId,
        anonymous: _anonymous,
        images: [for (final i in _images) if (i.draft != null) i.draft!],
        poll: _poll,
      );

  int get _busyCount => _images.where((i) => i.state == ComposeImageState.uploading).length;
  int get _failedCount => _images.where((i) => i.state == ComposeImageState.failed).length;

  ComposeIssue get _issue => validateCompose(
        title: _title.text,
        body: _body.text,
        categoryId: _categoryId,
        poll: _poll,
        imagesBusy: _busyCount,
        imagesFailed: _failedCount,
      );

  bool get _canPublish => !_publishing && _issue == ComposeIssue.none;

  void _changed() {
    if (!mounted) return;
    setState(() {
      _touched = true;
      _error = null;
    });
    _saveTimer?.cancel();
    _saveTimer = Timer(widget.draftDebounce, () {
      if (mounted) unawaited(_drafts.save(_uid, _snapshot()));
    });
  }

  String? _hint(AppLocalizations l) {
    if (!_touched || _error != null) return null;
    return switch (_issue) {
      ComposeIssue.none => null,
      ComposeIssue.title => l.forumComposeNeedTitle,
      ComposeIssue.body => l.forumComposeNeedBody,
      ComposeIssue.category => l.forumComposeNeedCategory,
      ComposeIssue.poll => l.forumComposeNeedPoll,
      ComposeIssue.imagesPending => l.forumComposeImagesPending,
      ComposeIssue.imageFailed =>
        _images.firstWhere((i) => i.state == ComposeImageState.failed, orElse: () => ComposeImage.local(Uint8List(0))).error ??
            l.forumComposeImageFailedHint,
    };
  }

  // ---- Görseller -------------------------------------------------------------------------------------------

  Future<void> _addImage() async {
    if (_publishing || _images.length >= ForumComposeLimits.maxImages) return;
    final l = context.l10n;
    final src = await BuSheet.show<ImageSource>(
      context,
      scrollable: false,
      padding: EdgeInsets.zero,
      builder: (ctx) {
        final t = ctx.bu;
        Widget row(Key k, IconData icon, String label, ImageSource v) => InkWell(
              key: k,
              onTap: () => Navigator.pop(ctx, v),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: BuSize.row),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: BuSpace.page),
                  child: Row(children: [
                    Icon(icon, size: 22, color: t.ink),
                    const SizedBox(width: 14),
                    Expanded(child: Text(label, style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w400))),
                  ]),
                ),
              ),
            );
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          row(const ValueKey('forumPickGallery'), BuIcons.image, l.forumComposeGallery, ImageSource.gallery),
          Divider(height: 1, color: t.bd),
          row(const ValueKey('forumPickCamera'), BuIcons.camera, l.forumComposeCamera, ImageSource.camera),
          SizedBox(height: MediaQuery.paddingOf(ctx).bottom > 0 ? 0 : 8),
        ]);
      },
    );
    if (src == null || !mounted) return;
    Uint8List? bytes;
    try {
      bytes = await _pick(src);
    } catch (e) {
      if (mounted) BuToast.show(context, forumImageErrorText(e, context.l10n), kind: BuToastKind.error);
      return;
    }
    if (bytes == null || !mounted || _images.length >= ForumComposeLimits.maxImages) return;
    final im = ComposeImage.local(bytes);
    setState(() => _images.add(im));
    _changed();
    unawaited(_uploadImage(im));
  }

  Future<void> _uploadImage(ComposeImage im) async {
    final bytes = im.bytes;
    if (bytes == null) return;
    try {
      final m = await _upload(bytes);
      if (!mounted || !_images.contains(im)) return;
      setState(() {
        im.media = m;
        im.state = ComposeImageState.done;
        im.error = null;
      });
      _changed();
    } catch (e) {
      if (!mounted || !_images.contains(im)) return;
      setState(() {
        im.state = ComposeImageState.failed;
        im.error = forumImageErrorText(e, context.l10n);
      });
    }
  }

  void _retryImage(ComposeImage im) {
    if (_publishing || im.state != ComposeImageState.failed) return;
    setState(() {
      im.state = ComposeImageState.uploading;
      im.error = null;
    });
    unawaited(_uploadImage(im));
  }

  void _removeImage(ComposeImage im) {
    if (_publishing) return;
    setState(() => _images.remove(im));
    _changed();
  }

  // ---- Yayınla ---------------------------------------------------------------------------------------------

  String _signature() {
    final d = _snapshot();
    return [
      d.title.trim(),
      d.body.trim(),
      d.categoryId,
      d.anonymous,
      [for (final i in d.images) i.id].join(','),
      d.poll?.toJson(),
    ].join('|');
  }

  Future<void> _publish() async {
    // Çift dokunma koruması: bayrak İLK dokunuşta, await'ten önce kurulur.
    if (_publishing || _issue != ComposeIssue.none) return;
    FocusScope.of(context).unfocus();
    final sig = _signature();
    if (sig != _sig) {
      _sig = sig;
      _key = ForumApi.newIdempotencyKey();
    }
    setState(() {
      _publishing = true;
      _error = null;
    });
    try {
      final topic = await _api.createTopic(
        title: _title.text,
        body: _body.text,
        categoryId: _categoryId!,
        anonymous: _anonymous,
        imageIds: [for (final i in _images) i.mediaId!],
        poll: _poll?.toRequest(_now()),
        idempotencyKey: _key,
      );
      if (!mounted) return;
      _skipFlush = true;
      _saveTimer?.cancel();
      unawaited(_drafts.clear(_uid));
      final nav = Navigator.of(context);
      final host = nav.context;
      nav.pop<TopicSummary>(topic);
      // Oluşturma ekranı yığından çıktı; yeni konunun detayı açılır.
      // ignore: use_build_context_synchronously
      unawaited(openTopicDetail(host, widget.session, topic.id, initial: topic));
    } catch (e) {
      if (!mounted) return;
      final l = context.l10n;
      setState(() {
        _publishing = false;
        _error = forumPublishErrorText(e, l);
        // Kategori kaldırılmışsa seçimi temizle + listeyi yenile; kullanıcı başka kategori seçsin.
        if (e is ApiError && e.code.startsWith('FORUM_CATEGORY')) _categoryId = null;
      });
      if (e is ApiError && e.code.startsWith('FORUM_CATEGORY')) unawaited(_loadCategories());
      if (_scroll.hasClients) unawaited(_scroll.animateTo(0, duration: BuMotion.of(context, BuMotion.medium), curve: BuMotion.standard));
    }
  }

  // ---- Çıkış -----------------------------------------------------------------------------------------------

  bool get _canLeaveFreely => !_publishing && (!_touched || _snapshot().isEmpty);

  Future<void> _confirmLeave() async {
    if (_publishing) return;
    FocusScope.of(context).unfocus();
    final l = context.l10n;
    final r = await BuSheet.show<_Leave>(
      context,
      title: l.forumComposeDraftSheetTitle,
      subtitle: l.forumComposeDraftSheetBody,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BuButton(key: const ValueKey('draftSave'), label: l.forumComposeDraftSave, onPressed: () => Navigator.pop(ctx, _Leave.save)),
        const SizedBox(height: 8),
        BuButton(
            key: const ValueKey('draftDiscard'),
            label: l.forumComposeDraftDelete,
            kind: BuButtonKind.outline,
            onPressed: () => Navigator.pop(ctx, _Leave.discard)),
        const SizedBox(height: 4),
        BuButton(
            key: const ValueKey('draftKeep'),
            label: l.forumComposeDraftContinue,
            kind: BuButtonKind.text,
            onPressed: () => Navigator.pop(ctx, _Leave.keep)),
      ]),
    );
    if (!mounted) return;
    switch (r) {
      case _Leave.save:
        _saveTimer?.cancel();
        await _drafts.save(_uid, _snapshot());
        _skipFlush = true;
        if (mounted) Navigator.of(context).pop();
      case _Leave.discard:
        _saveTimer?.cancel();
        _skipFlush = true;
        await _drafts.clear(_uid);
        if (mounted) Navigator.of(context).pop();
      case _Leave.keep:
      case null:
        break;
    }
  }

  // ---- Arayüz ----------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final hint = _hint(l);
    final locked = _publishing;
    return PopScope(
      canPop: _canLeaveFreely,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_publishing) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: t.bg,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(children: [
            _TopBar(
              publishing: _publishing,
              canPublish: _canPublish,
              onClose: () => Navigator.of(context).maybePop(),
              onPublish: _publish,
            ),
            Expanded(
              child: ListView(
                controller: _scroll,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(BuSpace.page, 4, BuSpace.page, 32),
                children: [
                  AnimatedSize(
                    duration: BuMotion.of(context, BuMotion.short),
                    curve: BuMotion.standard,
                    alignment: Alignment.topCenter,
                    child: _error != null
                        ? _Notice(key: const ValueKey('forumComposeError'), text: _error!, error: true)
                        : (hint != null ? _Notice(key: const ValueKey('forumComposeHint'), text: hint) : const SizedBox(width: double.infinity)),
                  ),
                  CategoryPickerRow(
                    categories: _cats,
                    selectedId: _categoryId,
                    loading: _catsLoading,
                    failed: _catsFailed,
                    enabled: !locked,
                    onRetry: _loadCategories,
                    onSelected: (c) {
                      setState(() => _categoryId = c.id);
                      _changed();
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('forumTitle'),
                    controller: _title,
                    focusNode: _titleFocus,
                    enabled: !locked,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: ForumComposeLimits.titleMax,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[\r\n]'))],
                    onChanged: (_) => _changed(),
                    onSubmitted: (_) => _bodyFocus.requestFocus(),
                    style: tt.titleLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w400),
                    decoration: composeInputDecoration(context, hint: l.forumComposeTitleHint, padding: const EdgeInsets.symmetric(vertical: 8))
                        .copyWith(hintStyle: tt.titleLarge?.copyWith(color: t.mut, fontWeight: FontWeight.w400)),
                  ),
                  Divider(height: 16, color: t.bd),
                  TextField(
                    key: const ValueKey('forumBody'),
                    controller: _body,
                    focusNode: _bodyFocus,
                    enabled: !locked,
                    minLines: 6,
                    maxLines: null,
                    maxLength: ForumComposeLimits.bodyMax,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => _changed(),
                    style: tt.bodyLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w400),
                    decoration: composeInputDecoration(context, hint: l.forumComposeBodyHint, padding: const EdgeInsets.symmetric(vertical: 8)),
                  ),
                  const SizedBox(height: 16),
                  ComposeImageStrip(
                    images: _images,
                    max: ForumComposeLimits.maxImages,
                    enabled: !locked,
                    authHeaders: postAuthHeaders(widget.session),
                    onAdd: _addImage,
                    onRemove: _removeImage,
                    onRetry: _retryImage,
                  ),
                  const SizedBox(height: 16),
                  AnimatedSize(
                    duration: BuMotion.of(context, BuMotion.medium),
                    curve: BuMotion.standard,
                    alignment: Alignment.topCenter,
                    child: _poll == null
                        ? Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: BuButton(
                              key: const ValueKey('forumPollAdd'),
                              label: l.forumComposePollAdd,
                              icon: BuIcons.vote,
                              kind: BuButtonKind.outline,
                              compact: true,
                              onPressed: locked
                                  ? null
                                  : () {
                                      setState(() {
                                        _poll = const PollDraft();
                                        _pollKey = UniqueKey();
                                      });
                                      _changed();
                                    },
                            ),
                          )
                        : PollBuilder(
                            key: _pollKey,
                            value: _poll!,
                            enabled: !locked,
                            now: widget.now,
                            onChanged: (p) {
                              setState(() => _poll = p);
                              _changed();
                            },
                            onRemove: () {
                              setState(() => _poll = null);
                              _changed();
                            },
                          ),
                  ),
                  const SizedBox(height: 8),
                  Divider(height: 24, color: t.bd),
                  ComposeSwitchRow(
                    key: const ValueKey('forumAnonymous'),
                    icon: BuIcons.eyeOff,
                    label: l.forumComposeAnonymous,
                    hint: l.forumComposeAnonymousDesc,
                    note: l.forumComposeAnonymousNote,
                    value: _anonymous,
                    onChanged: locked
                        ? null
                        : (v) {
                            setState(() => _anonymous = v);
                            _changed();
                          },
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Üst çubuk: kapat + (sayfa başlığı metni YOK) + "Yayınla" hapı. Hap yüklenirken ilerleme gösterir.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.publishing, required this.canPublish, required this.onClose, required this.onPublish});

  final bool publishing;
  final bool canPublish;
  final VoidCallback onClose;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final on = canPublish || publishing;
    return SizedBox(
      height: BuSize.appBar,
      child: Row(children: [
        IconButton(
          key: const ValueKey('forumComposeClose'),
          tooltip: l.forumComposeClose,
          constraints: const BoxConstraints(minWidth: BuSize.touch, minHeight: BuSize.touch),
          icon: Icon(BuIcons.x, size: 24, color: t.ink),
          onPressed: publishing ? null : onClose,
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 12),
          child: Semantics(
            button: true,
            enabled: canPublish,
            label: publishing ? l.forumComposePublishing : l.forumComposePublish,
            excludeSemantics: true,
            child: AnimatedOpacity(
              opacity: on ? 1 : .4,
              duration: BuMotion.of(context, BuMotion.short),
              child: Material(
                key: const ValueKey('forumPublish'),
                color: Colors.transparent,
                child: InkWell(
                  customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onTap: canPublish ? onPublish : null,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: BuSize.touch, minWidth: 72),
                    child: Center(
                      widthFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: t.pr, borderRadius: BorderRadius.circular(10)),
                        child: SizedBox(
                          height: 36,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Center(
                              widthFactor: 1,
                              child: AnimatedSwitcher(
                                duration: BuMotion.of(context, BuMotion.short),
                                child: publishing
                                    ? SizedBox(
                                        key: const ValueKey('publishing'),
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: t.onPr),
                                      )
                                    : Text(l.forumComposePublish,
                                        key: const ValueKey('publish'),
                                        style: tt.labelLarge?.copyWith(color: t.onPr, fontSize: 14, fontWeight: FontWeight.w400)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Form üstü bilgi satırı: hata (kırmızı, ikonlu) ya da eksik alan ipucu (soluk).
class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.text, this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: error ? t.dangerSoft : t.sf2,
            borderRadius: BorderRadius.circular(BuRadius.sm),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ExcludeSemantics(child: Icon(error ? BuIcons.circleAlert : BuIcons.info, size: 18, color: error ? t.danger : t.mut)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: tt.bodySmall?.copyWith(color: error ? t.danger : t.mut, fontWeight: FontWeight.w400, height: 1.35)),
            ),
          ]),
        ),
      ),
    );
  }
}
