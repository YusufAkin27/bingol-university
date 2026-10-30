import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/platform/image_service.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../media_crop/media_crop.dart';
import 'post_api.dart';
import 'post_media_uploader.dart';
import 'post_models.dart';
import 'post_text_rules.dart';

/// Galeriden ya da kameradan tek fotoğraf baytı döndürür (iptalde null); testlerde sahtesi verilir.
typedef PostPhotoPicker = Future<Uint8List?> Function(ImageSource source);

/// Seçilen fotoğrafı 4:5 kırptırır (vazgeçilirse null); testlerde sahtesi verilir.
typedef PostPhotoCropper = Future<CropOutcome?> Function(BuildContext context, Uint8List bytes, CropSpec spec);

Future<Uint8List?> _defaultPicker(ImageSource source) async {
  final f = await ImageService().pick(source);
  return f?.readAsBytes();
}

/// Oluşturucuyu tam ekran açar; paylaşılırsa oluşan [Post] döner, kapatılırsa null.
Future<Post?> openComposePost(BuildContext context, Session session) => Navigator.of(context).push<Post>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => ComposePostPage(session: session)),
    );

enum _Err { none, generic, profanity, rate, network }

/// Sade gönderi oluşturucu: tam 1 fotoğraf (zorunlu, 4:5 kırpılır) + isteğe bağlı kısa metin (en çok 7 kelime, canlı
/// sayaç). Fotoğraf `POST /posts/media` ile yüklenir, sonra gönderi `mediaIds: [id]` ile oluşturulur.
class ComposePostPage extends StatefulWidget {
  const ComposePostPage({super.key, required this.session, this.pickPhoto, this.cropPhoto, this.uploader, this.api});

  final Session session;

  /// Testler için: seçici/kırpıcı/yükleyici/API enjeksiyonu.
  final PostPhotoPicker? pickPhoto;
  final PostPhotoCropper? cropPhoto;
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

  Uint8List? _original; // kırpılmamış seçim (yeniden kırpmak için)
  Uint8List? _photo; // kırpılmış 4:5
  PostMedia? _uploaded; // aynı fotoğraf için yeniden yüklemeyi önler (metin hatasından sonra tekrar dene)
  bool _publishing = false;
  _Err _err = _Err.none;
  String _errText = '';
  int _wait = 0; // hız sınırı geri sayımı (sn)
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  int get _words => postWordCount(_text.text);
  bool get _textOk => postTextOk(_text.text);
  bool get _dirty => _photo != null || _text.text.trim().isNotEmpty;
  bool get _canShare => !_publishing && _photo != null && _textOk;

  CropSpec get _spec => CropSpec.post(
        previewName: widget.session.displayName,
        previewCaption: _text.text.trim(),
        allowChange: true,
      );

  Future<CropOutcome?> _crop(Uint8List bytes) => (widget.cropPhoto ?? ((c, b, s) => cropImage(c, b, s)))(context, bytes, _spec);

  void _setError(Object e) {
    final l = context.l10n;
    _errText = postErrorText(e, l);
    _timer?.cancel();
    _wait = 0;
    if (e is ApiError && e.code == 'CONTENT_PROFANITY') {
      _err = _Err.profanity;
    } else if (e is ApiError && e.status == 429) {
      _err = _Err.rate;
      _wait = e.retryAfter ?? 0;
      if (_wait > 0) {
        _timer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted || _wait <= 1) {
            t.cancel();
            if (mounted) setState(() => _wait = 0);
            return;
          }
          setState(() => _wait--);
        });
      }
    } else if (e is ApiError && e.isNetwork) {
      _err = _Err.network;
    } else {
      _err = _Err.generic;
    }
  }

  Future<void> _pick(ImageSource source) async {
    if (_publishing) return;
    FocusScope.of(context).unfocus();
    try {
      var src = source;
      while (true) {
        final bytes = await (widget.pickPhoto ?? _defaultPicker)(src);
        if (bytes == null || !mounted) return;
        final out = await _crop(bytes);
        if (out == null || !mounted) return;
        if (out.changeRequested) {
          src = ImageSource.gallery;
          continue;
        }
        final cropped = out.bytes;
        if (cropped == null) return;
        setState(() {
          _original = bytes;
          _photo = cropped;
          _uploaded = null;
          _err = _Err.none;
        });
        return;
      }
    } catch (e) {
      if (mounted) setState(() => _setError(e));
    }
  }

  Future<void> _recrop() async {
    final orig = _original;
    if (orig == null || _publishing) return;
    final out = await _crop(orig);
    final cropped = out?.bytes;
    if (cropped == null || !mounted) return;
    setState(() {
      _photo = cropped;
      _uploaded = null;
    });
  }

  Future<void> _publish() async {
    final bytes = _photo;
    if (!_canShare || bytes == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _publishing = true;
      _err = _Err.none;
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
        _setError(e);
      });
    }
  }

  Future<void> _close() async {
    if (_dirty) {
      final ok = await showDialog<bool>(context: context, builder: (c) => const _DiscardDialog());
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
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    _photoArea(t),
                    const SizedBox(height: 12),
                    _textField(t),
                    ..._errors(t),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuTokens t) {
    final tt = Theme.of(context).textTheme;
    final enabled = _canShare;
    return SizedBox(
      height: 56,
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
                textAlign: TextAlign.center,
                style: tt.titleMedium?.copyWith(color: t.ink, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: Material(
              key: const ValueKey('composeShare'),
              color: enabled || _publishing ? t.pr : Colors.transparent,
              borderRadius: BorderRadius.circular(BuRadius.pill),
              child: InkWell(
                borderRadius: BorderRadius.circular(BuRadius.pill),
                onTap: enabled ? _publish : null,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40, minWidth: 64),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      widthFactor: 1,
                      heightFactor: 1,
                      child: _publishing
                          ? Row(mainAxisSize: MainAxisSize.min, children: [
                              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: t.onPr)),
                              const SizedBox(width: 8),
                              Text(context.l10n.p04PostSharing, style: tt.labelLarge?.copyWith(color: t.onPr, fontWeight: FontWeight.w700)),
                            ])
                          : Text(context.l10n.postComposeShare,
                              style: tt.labelLarge?.copyWith(color: enabled ? t.onPr : t.mut, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoArea(BuTokens t) {
    final tt = Theme.of(context).textTheme;
    final bytes = _photo;
    if (bytes != null) {
      return Container(
        key: const ValueKey('composePreview'),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(BuRadius.lg), boxShadow: BuElevation.of(context, 1)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(BuRadius.lg),
          child: AspectRatio(
            aspectRatio: 4 / 5,
            child: Stack(fit: StackFit.expand, children: [
              ColoredBox(color: t.sf2),
              Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, __, ___) => Center(child: Icon(LucideIcons.image, color: t.mut))),
              PositionedDirectional(
                top: 12,
                end: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: t.scrim.withValues(alpha: .55), borderRadius: BorderRadius.circular(BuRadius.pill)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    child: Text('4:5', style: tt.labelSmall?.copyWith(color: t.onMedia, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              if (!_publishing)
                PositionedDirectional(
                  start: 12,
                  end: 12,
                  bottom: 12,
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Flexible(child: _pill(const ValueKey('composeChange'), LucideIcons.images, context.l10n.gonderiChangePhoto, () => _pick(ImageSource.gallery))),
                    const SizedBox(width: 8),
                    Flexible(child: _pill(const ValueKey('composeRecrop'), LucideIcons.crop, context.l10n.p04Recrop, _recrop)),
                  ]),
                ),
              if (_publishing) Positioned.fill(child: ColoredBox(color: t.scrim.withValues(alpha: .35))),
            ]),
          ),
        ),
      );
    }
    final hint = _text.text.trim().isNotEmpty; // metin yazıldı ama fotoğraf yok: zorunluluk ipucu
    return CustomPaint(
      key: const ValueKey('composePicker'),
      painter: _DashedBorder(color: t.bd, radius: BuRadius.lg),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: t.sf, shape: BoxShape.circle, border: Border.all(color: t.bd)),
              child: Icon(LucideIcons.camera, size: 28, color: t.ink),
            ),
            const SizedBox(height: 16),
            if (hint) ...[
              Text(context.l10n.p04PostPhotoNone, textAlign: TextAlign.center, style: tt.titleSmall?.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(context.l10n.gonderiPhotoRequired,
                  key: const ValueKey('composePhotoHint'),
                  textAlign: TextAlign.center,
                  style: tt.titleSmall?.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(context.l10n.p04PostFormatHint, textAlign: TextAlign.center, style: tt.bodySmall?.copyWith(color: t.mut)),
              const SizedBox(height: 16),
            ],
            _bigBtn(const ValueKey('composeGallery'), LucideIcons.images, context.l10n.gonderiPickPhoto, () => _pick(ImageSource.gallery)),
            const SizedBox(height: 10),
            _bigBtn(const ValueKey('composeCamera'), LucideIcons.camera, context.l10n.gonderiTakePhoto,
                () => _pick(ImageSource.camera)),
            if (!hint) ...[
              const SizedBox(height: 16),
              Text(context.l10n.gonderiPhotoHint, textAlign: TextAlign.center, style: tt.bodyMedium?.copyWith(color: t.ink)),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _bigBtn(Key key, IconData icon, String label, VoidCallback onTap) {
    final t = context.bu;
    return Material(
      key: key,
      color: t.sf,
      shape: StadiumBorder(side: BorderSide(color: t.bd)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 210),
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: t.ink),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: t.ink)),
          ]),
        ),
      ),
    );
  }

  Widget _pill(Key key, IconData icon, String label, VoidCallback onTap) {
    final t = context.bu;
    return Material(
      key: key,
      color: t.sf,
      shape: const StadiumBorder(),
      elevation: 1,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: t.ink),
              const SizedBox(width: 6),
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: t.ink, fontWeight: FontWeight.w600))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _textField(BuTokens t) {
    final over = !_textOk;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('composeText'),
          controller: _text,
          focusNode: _focus,
          enabled: !_publishing,
          minLines: 1,
          maxLines: 3,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'[\r\n]')),
            LengthLimitingTextInputFormatter(kPostMaxChars),
          ],
          onChanged: (_) => setState(() {}),
          style: tt.bodyLarge?.copyWith(color: t.ink),
          decoration: InputDecoration(
            hintText: context.l10n.gonderiTextHint,
            hintStyle: tt.bodyLarge?.copyWith(color: t.mut),
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(context.l10n.gonderiWordCount(_words.toString(), kPostMaxWords.toString()),
                key: const ValueKey('composeCounter'),
                style: tt.labelLarge?.copyWith(color: over ? t.danger : t.ink, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  /// Doğrulama ve gönderim hataları (referans 10/3): kelime sınırı, içerik uyarısı kartı, hız sınırı, ağ.
  List<Widget> _errors(BuTokens t) {
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    Widget row(IconData icon, Widget child, {Color? color}) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: color ?? t.ink),
            const SizedBox(width: 8),
            Expanded(child: child),
          ]),
        );
    return [
      if (!_textOk)
        row(LucideIcons.circleAlert,
            Text(l.gonderiWordLimit(kPostMaxWords.toString()),
                key: const ValueKey('composeLimitWarn'), style: tt.labelLarge?.copyWith(color: t.danger, fontWeight: FontWeight.w700)),
            color: t.danger),
      if (_err == _Err.profanity)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: DecoratedBox(
            key: const ValueKey('composeError'),
            decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(BuRadius.md), border: Border.all(color: t.bd)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(LucideIcons.triangleAlert, size: 20, color: t.ink),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.p04ContentWarning, style: tt.titleSmall?.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(_errText, style: tt.bodyMedium?.copyWith(color: t.ink)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      if (_err == _Err.rate)
        row(
            LucideIcons.hourglass,
            Row(children: [
              Expanded(child: Text(_errText, key: const ValueKey('composeError'), style: tt.bodyMedium?.copyWith(color: t.ink))),
              if (_wait > 0) Text('${_wait}s', key: const ValueKey('composeWait'), style: tt.labelLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
            ])),
      if (_err == _Err.network)
        row(
            LucideIcons.wifiOff,
            Row(children: [
              Expanded(child: Text(_errText, key: const ValueKey('composeError'), style: tt.bodyMedium?.copyWith(color: t.ink))),
              GestureDetector(
                key: const ValueKey('composeRetry'),
                behavior: HitTestBehavior.opaque,
                onTap: _canShare ? _publish : null,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Center(
                    widthFactor: 1,
                    child: Text(l.commonRetryShort,
                        style: tt.labelLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w700, decoration: TextDecoration.underline)),
                  ),
                ),
              ),
            ])),
      if (_err == _Err.generic)
        row(LucideIcons.circleAlert, Text(_errText, key: const ValueKey('composeError'), style: tt.labelLarge?.copyWith(color: t.danger)),
            color: t.danger),
    ];
  }
}

/// "Gönderiden vazgeçilsin mi?" onayı (referans 10/4): Devam (kırmızı dolu) + Vazgeç (kırmızı metin). `true` = vazgeç.
class _DiscardDialog extends StatelessWidget {
  const _DiscardDialog();

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Dialog(
      backgroundColor: t.sf3,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l.gonderiDiscardTitle, textAlign: TextAlign.center, style: tt.titleLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(l.gonderiDiscardBody, textAlign: TextAlign.center, style: tt.bodyMedium?.copyWith(color: t.mut)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: BuButton(key: const ValueKey('composeKeep'), label: l.postComposeContinue, onPressed: () => Navigator.pop(context, false)),
          ),
          TextButton(
            key: const ValueKey('composeDiscard'),
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: t.pr),
            child: Text(l.gonderiDiscardYes, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 12) {
        canvas.drawPath(m.extractPath(d, d + 6), p);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder o) => o.color != color || o.radius != radius;
}
