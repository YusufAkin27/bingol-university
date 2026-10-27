import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../chat/media_camera_page.dart';
import '../chat/media_library.dart';
import '../chat/media_pick.dart';
import '../chat/media_picker_page.dart';
import '../posts/post_media_uploader.dart';
import '../posts/social_api.dart';
import 'story_player.dart';
import 'story_viewer_page.dart' show storyColor;

/// Metin hikâyesi arka plan renkleri.
const kStoryBackgrounds = ['#1E3A8A', '#9D174D', '#047857', '#B45309', '#6D28D9', '#111827'];
const kStoryTextMax = 200;
const kStoryCaptionMax = 200;

/// Medyanın hikâye için uygun olup olmadığı: video en çok 30 sn. Uygunsa null, değilse kullanıcı mesajı.
String? storyMediaProblem(MediaPick p) {
  if (p.isVideo && p.durationMs > kStoryMaxVideo.inMilliseconds) return 'Hikâye videosu en fazla 30 saniye olabilir.';
  return null;
}

/// Hikâye oluşturma: fotoğraf/video (galeri ya da kamera) + açıklama, ya da metin + arka plan rengi.
/// Medya `POST /posts/media` ile yüklenir, sonra `POST /stories`. Başarıda `true` döner.
class StoryCreatePage extends StatefulWidget {
  const StoryCreatePage({
    super.key,
    required this.session,
    this.library,
    this.ensureAccess,
    this.openCamera,
    this.uploader,
    this.api,
  });

  final Session session;
  final MediaLibrary? library;
  final EnsureAccess? ensureAccess;
  final MediaCameraLauncher? openCamera;
  final PostMediaUploader? uploader;
  final SocialApi? api;

  @override
  State<StoryCreatePage> createState() => _StoryCreatePageState();
}

class _StoryCreatePageState extends State<StoryCreatePage> {
  late final PostMediaUploader _uploader = widget.uploader ?? PostMediaUploader(widget.session);
  late final SocialApi _api = widget.api ?? SocialApi(widget.session);
  final _text = TextEditingController();
  final _caption = TextEditingController();

  int _mode = 0; // 0 medya, 1 metin
  MediaPick? _pick;
  Future<Uint8List?>? _thumb;
  int _bg = 0;
  bool _busy = false;
  double _progress = 0;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    _caption.dispose();
    super.dispose();
  }

  void _setPick(MediaPick? p) {
    if (p == null || !mounted) return;
    final problem = storyMediaProblem(p);
    setState(() {
      if (problem != null) {
        _pick = null;
        _error = problem;
      } else {
        _pick = p;
        _thumb = p.thumb(720);
        _error = null;
      }
    });
  }

  Future<void> _gallery() async {
    final plan = await Navigator.push<MediaSendPlan>(
      context,
      MaterialPageRoute(
        builder: (_) => MediaPickerPage(
          library: widget.library ?? PhotoManagerLibrary(),
          ensureAccess: widget.ensureAccess,
          openCamera: widget.openCamera,
          maxItems: 1,
        ),
      ),
    );
    if (plan == null || plan.items.isEmpty) return;
    _setPick(plan.items.first.pick);
  }

  Future<void> _camera() async {
    final p = await (widget.openCamera ?? openMediaCamera)(context);
    _setPick(p);
  }

  bool get _canShare => !_busy && (_mode == 0 ? _pick != null : _text.text.trim().isNotEmpty);

  Future<void> _share() async {
    if (!_canShare) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });
    try {
      if (_mode == 0) {
        final p = _pick!;
        final m = await _uploader.upload(p, onProgress: (v) {
          if (mounted) setState(() => _progress = v);
        });
        await _api.createStory(
            kind: p.isVideo ? 'VIDEO' : 'IMAGE', mediaId: m.id, caption: _caption.text);
      } else {
        await _api.createStory(kind: 'TEXT', bodyText: _text.text, background: kStoryBackgrounds[_bg]);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = postErrorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      resizeToAvoidBottomInset: true,
      body: Column(children: [
        BuHeader(
          title: 'Hikâye oluştur',
          onBack: _busy ? null : () => Navigator.pop(context),
          actions: [
            BuButton(
              key: const ValueKey('storyShare'),
              label: 'Paylaş',
              compact: true,
              busy: _busy,
              onPressed: _canShare ? _share : null,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: BuSegmented(
            items: const ['Fotoğraf / Video', 'Metin'],
            index: _mode,
            onChanged: (i) {
              if (_busy) return;
              setState(() {
                _mode = i;
                _error = null;
              });
            },
          ),
        ),
        if (_busy && _mode == 0)
          LinearProgressIndicator(value: _progress == 0 ? null : _progress, minHeight: 3),
        Expanded(child: _mode == 0 ? _media(t) : _textMode(t)),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(_error!, key: const ValueKey('storyError'), style: BuType.label.copyWith(color: t.danger)),
          ),
      ]),
    );
  }

  Widget _media(BuTokens t) {
    final p = _pick;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        if (p == null)
          Container(
            height: 280,
            decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(20), border: Border.all(color: t.bd)),
            alignment: Alignment.center,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.image, size: 36, color: t.mut),
              const SizedBox(height: 8),
              Text('Hikâyen 24 saat görünür', style: BuType.body.copyWith(color: t.mut)),
            ]),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 9 / 14,
              child: Stack(fit: StackFit.expand, children: [
                ColoredBox(color: t.sf2),
                FutureBuilder<Uint8List?>(
                  future: _thumb,
                  builder: (_, s) => s.data == null ? const SizedBox.shrink() : Image.memory(s.data!, fit: BoxFit.cover),
                ),
                if (p.isVideo)
                  const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 56)),
              ]),
            ),
          ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
              child: BuButton(
                  key: const ValueKey('storyGallery'),
                  label: 'Galeri',
                  icon: LucideIcons.image,
                  kind: BuButtonKind.outline,
                  onPressed: _busy ? null : _gallery)),
          const SizedBox(width: 10),
          Expanded(
              child: BuButton(
                  key: const ValueKey('storyCamera'),
                  label: 'Kamera',
                  icon: LucideIcons.camera,
                  kind: BuButtonKind.outline,
                  onPressed: _busy ? null : _camera)),
        ]),
        if (p != null) ...[
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('storyCaption'),
            controller: _caption,
            enabled: !_busy,
            maxLines: 2,
            inputFormatters: [LengthLimitingTextInputFormatter(kStoryCaptionMax)],
            style: BuType.body.copyWith(color: t.ink),
            decoration: const InputDecoration(hintText: 'Açıklama ekle…'),
          ),
        ],
      ],
    );
  }

  Widget _textMode(BuTokens t) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 300,
          decoration: BoxDecoration(color: storyColor(kStoryBackgrounds[_bg]), borderRadius: BorderRadius.circular(20)),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            key: const ValueKey('storyBody'),
            controller: _text,
            enabled: !_busy,
            textAlign: TextAlign.center,
            maxLines: null,
            onChanged: (_) => setState(() {}),
            inputFormatters: [LengthLimitingTextInputFormatter(kStoryTextMax)],
            style: BuType.title.copyWith(color: Colors.white, fontSize: 24),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              hintText: 'Bir şeyler yaz…',
              hintStyle: BuType.title.copyWith(color: Colors.white54, fontSize: 24),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Text('${_text.text.characters.length}/$kStoryTextMax', style: BuType.caption.copyWith(color: t.mut)),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 12, children: [
          for (var i = 0; i < kStoryBackgrounds.length; i++)
            Semantics(
              button: true,
              selected: i == _bg,
              label: 'Arka plan rengi ${i + 1}',
              child: GestureDetector(
                key: ValueKey('storyBg-$i'),
                onTap: _busy ? null : () => setState(() => _bg = i),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: storyColor(kStoryBackgrounds[i]),
                    shape: BoxShape.circle,
                    border: Border.all(color: i == _bg ? t.ink : t.bd, width: i == _bg ? 3 : 1),
                  ),
                ),
              ),
            ),
        ]),
      ],
    );
  }
}
