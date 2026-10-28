import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/platform/image_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'post_api.dart';
import 'post_media_uploader.dart';
import 'post_models.dart';
import 'post_text_rules.dart';

/// Galeriden ya da kameradan tek fotoğraf baytı döndürür (iptalde null); testlerde sahtesi verilir.
typedef PostPhotoPicker = Future<Uint8List?> Function(ImageSource source);

Future<Uint8List?> _defaultPicker(ImageSource source) async {
  final f = await ImageService().pick(source);
  return f?.readAsBytes();
}

/// Oluşturucuyu tam ekran açar; paylaşılırsa oluşan [Post] döner, kapatılırsa null.
Future<Post?> openComposePost(BuildContext context, Session session) => Navigator.of(context).push<Post>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => ComposePostPage(session: session)),
    );

/// Sade gönderi oluşturucu: tam 1 fotoğraf (zorunlu) + isteğe bağlı kısa metin (en çok 7 kelime, canlı sayaç).
/// Fotoğraf `POST /posts/media` ile yüklenir, sonra gönderi `mediaIds: [id]` ile oluşturulur.
class ComposePostPage extends StatefulWidget {
  const ComposePostPage({super.key, required this.session, this.pickPhoto, this.uploader, this.api});

  final Session session;

  /// Testler için: seçici/yükleyici/API enjeksiyonu.
  final PostPhotoPicker? pickPhoto;
  final PostMediaUploader? uploader;
  final PostApi? api;

  @override
  State<ComposePostPage> createState() => _ComposePostPageState();
}

class _ComposePostPageState extends State<ComposePostPage> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  late final PostMediaUploader _uploader = widget.uploader ?? PostMediaUploader(widget.session);
  late final PostApi _api = widget.api ?? PostApi(widget.session);

  Uint8List? _photo;
  PostMedia? _uploaded; // aynı fotoğraf için yeniden yüklemeyi önler (metin hatasından sonra tekrar dene)
  bool _publishing = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  int get _words => postWordCount(_text.text);
  bool get _textOk => postTextOk(_text.text);
  bool get _dirty => _photo != null || _text.text.trim().isNotEmpty;
  bool get _canShare => !_publishing && _photo != null && _textOk;

  Future<void> _pick(ImageSource source) async {
    if (_publishing) return;
    FocusScope.of(context).unfocus();
    try {
      final bytes = await (widget.pickPhoto ?? _defaultPicker)(source);
      if (bytes == null || !mounted) return;
      setState(() {
        _photo = bytes;
        _uploaded = null;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = postErrorText(e, context.l10n));
    }
  }

  Future<void> _publish() async {
    final bytes = _photo;
    if (!_canShare || bytes == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _publishing = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final media = _uploaded ??= await _uploader.upload(bytes);
      final post = await _api.create(text: _text.text, mediaId: media.id);
      if (!mounted) return;
      messenger?.showSnackBar(SnackBar(content: Text(context.l10n.postComposeShared), duration: const Duration(seconds: 2)));
      Navigator.pop(context, post);
    } catch (e) {
      if (!mounted) return;
      if (e is ApiError && e.code == 'POST_MEDIA_INVALID') _uploaded = null;
      setState(() {
        _publishing = false;
        _error = postErrorText(e, context.l10n);
      });
    }
  }

  Future<void> _close() async {
    if (_dirty) {
      final l = context.l10n;
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(l.gonderiDiscardTitle),
          content: Text(l.gonderiDiscardBody),
          actions: [
            TextButton(key: const ValueKey('composeKeep'), onPressed: () => Navigator.pop(c, false), child: Text(l.postComposeContinue)),
            TextButton(
              key: const ValueKey('composeDiscard'),
              onPressed: () => Navigator.pop(c, true),
              child: Text(l.gonderiDiscardYes, style: TextStyle(color: c.bu.danger)),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return PopScope(
      canPop: !_dirty || _publishing,
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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  children: [
                    _photoArea(t),
                    const SizedBox(height: 16),
                    _textField(t),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(_error!, key: const ValueKey('composeError'), style: BuType.label.copyWith(color: t.danger)),
                      ),
                  ],
                ),
              ),
              _bottomBar(t),
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
              tooltip: context.l10n.postComposeClose,
              icon: Icon(LucideIcons.x, color: t.ink),
              onPressed: _publishing ? null : _close,
            ),
            Expanded(
              child: Text(context.l10n.postComposeNewPost,
                  style: BuType.heading.copyWith(color: t.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );

  Widget _photoArea(BuTokens t) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final shadow = [
      BoxShadow(color: Colors.black.withValues(alpha: dark ? .22 : .07), blurRadius: 16, offset: const Offset(0, 5)),
    ];
    final bytes = _photo;
    if (bytes != null) {
      return Container(
        key: const ValueKey('composePreview'),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: shadow),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 4 / 5,
            child: Stack(fit: StackFit.expand, children: [
              ColoredBox(color: t.sf2),
              Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, __, ___) => Center(child: Icon(LucideIcons.image, color: t.mut))),
              if (!_publishing)
                PositionedDirectional(
                  top: 10,
                  end: 10,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _roundBtn(const ValueKey('composeChange'), LucideIcons.image, context.l10n.gonderiChangePhoto, () => _pick(ImageSource.gallery)),
                    const SizedBox(width: 8),
                    _roundBtn(const ValueKey('composeRemove'), LucideIcons.x, context.l10n.postComposeRemove,
                        () => setState(() {
                              _photo = null;
                              _uploaded = null;
                            })),
                  ]),
                ),
              if (_publishing)
                const Positioned.fill(
                    child: ColoredBox(color: Colors.black38, child: Center(child: CircularProgressIndicator(color: Colors.white)))),
            ]),
          ),
        ),
      );
    }
    return Container(
      key: const ValueKey('composePicker'),
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 20),
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.bd),
        boxShadow: shadow,
      ),
      child: Column(children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
          child: Icon(LucideIcons.image, size: 28, color: t.onSoft),
        ),
        const SizedBox(height: 14),
        Text(context.l10n.gonderiPhotoRequired,
            textAlign: TextAlign.center, style: BuType.bodyStrong.copyWith(color: t.ink)),
        const SizedBox(height: 4),
        Text(context.l10n.gonderiPhotoHint, textAlign: TextAlign.center, style: BuType.caption.copyWith(color: t.mut)),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: BuButton(
              key: const ValueKey('composeGallery'),
              label: context.l10n.gonderiPickPhoto,
              icon: LucideIcons.image,
              kind: BuButtonKind.soft,
              onPressed: () => _pick(ImageSource.gallery),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: BuButton(
              key: const ValueKey('composeCamera'),
              label: context.l10n.gonderiTakePhoto,
              icon: LucideIcons.camera,
              kind: BuButtonKind.outline,
              onPressed: () => _pick(ImageSource.camera),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _roundBtn(Key key, IconData icon, String tooltip, VoidCallback onTap) => Tooltip(
        message: tooltip,
        child: GestureDetector(
          key: key,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
      );

  Widget _textField(BuTokens t) {
    final over = !_textOk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          decoration: BoxDecoration(
            color: t.sf,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: over ? t.danger : t.bd),
          ),
          child: TextField(
            key: const ValueKey('composeText'),
            controller: _text,
            focusNode: _focus,
            enabled: !_publishing,
            minLines: 1,
            maxLines: 2,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'[\r\n]')),
              LengthLimitingTextInputFormatter(kPostMaxChars),
            ],
            onChanged: (_) => setState(() {}),
            style: BuType.body.copyWith(color: t.ink),
            decoration: InputDecoration(
              hintText: context.l10n.gonderiTextHint,
              hintStyle: BuType.body.copyWith(color: t.mut),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(children: [
            Expanded(
              child: over
                  ? Text(context.l10n.gonderiWordLimit(kPostMaxWords.toString()),
                      key: const ValueKey('composeLimitWarn'), style: BuType.label.copyWith(color: t.danger))
                  : const SizedBox.shrink(),
            ),
            Text(context.l10n.gonderiWordCount(_words.toString(), kPostMaxWords.toString()),
                key: const ValueKey('composeCounter'), style: BuType.label.copyWith(color: over ? t.danger : t.mut)),
          ]),
        ),
      ],
    );
  }

  Widget _bottomBar(BuTokens t) {
    final enabled = _canShare;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Material(
        key: const ValueKey('composeShare'),
        color: enabled ? t.pr : t.pr.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: enabled ? _publish : null,
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: Center(
              child: _publishing
                  ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: t.onPr))
                  : Text(context.l10n.postComposeShare, style: BuType.heading.copyWith(color: t.onPr)),
            ),
          ),
        ),
      ),
    );
  }
}
