import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../../core/locale_controller.dart';
import '../../core/typography.dart';
import '../../l10n/app_localizations.dart';
import 'chat_media.dart';
import 'chat_video_player.dart';
import 'message_bubble.dart' show chatMediaUrl, PlayBadge, DurationPill;

/// Sohbet medyası listesindeki tek görsel.
class ChatMediaItem {
  const ChatMediaItem(
      {required this.url,
      this.thumbUrl,
      this.sender,
      this.at,
      this.id,
      this.isVideo = false,
      this.durationMs});

  final String url;
  final String? thumbUrl;
  final String? sender;
  final DateTime? at;
  final int? id;

  /// Video öğesi: [url] akış adresi, [thumbUrl] poster (olmayabilir).
  final bool isVideo;
  final int? durationMs;

  /// Ekten öğe üretir; kaldırılmış, URL'siz ve TEK GÖSTERİMLİK ekler listeye girmez (null).
  static ChatMediaItem? tryFromAttachment(Map a,
      {String? sender, DateTime? at}) {
    if (isViewOnceAttachment(a) || a['removed'] == true) return null;
    final url = (a['url'] ?? a['thumbUrl']) as String?;
    if (url == null) return null;
    final video = isVideoAttachment(a);
    return ChatMediaItem(
      url: url,
      thumbUrl: video
          ? a['thumbUrl'] as String?
          : (a['thumbUrl'] ?? a['url']) as String?,
      sender: sender,
      at: at,
      id: (a['id'] as num?)?.toInt(),
      isVideo: video,
      durationMs: (a['durationMs'] as num?)?.toInt(),
    );
  }
}

/// Videoyu yetkili GET ile alıp (geçici dosya) galeriye kaydeder; başarısızlıkta [Exception] fırlatır.
Future<void> saveChatVideoToGallery(
    String url, Map<String, String> headers) async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    throw UnsupportedError('Bu cihazda desteklenmiyor.');
  }
  final r = await http
      .get(Uri.parse(chatMediaUrl(url)), headers: headers)
      .timeout(const Duration(minutes: 2));
  if (r.statusCode != 200) throw Exception('Video indirilemedi.');
  final f = File(
      '${Directory.systemTemp.path}/bu_kampus_${DateTime.now().millisecondsSinceEpoch}.mp4');
  await f.writeAsBytes(r.bodyBytes);
  try {
    await Gal.putVideo(f.path);
  } finally {
    try {
      await f.delete();
    } catch (_) {}
  }
}

/// Galeri/oynatıcı için hata metni (video).
/// [l10n] verilmezse Türkçe kullanılır (eski çağıranlar için).
String chatVideoSaveErrorText(Object e, [AppLocalizations? l10n]) {
  final l = l10n ?? lookupAppLocalizations(const Locale('tr'));
  if (e is UnsupportedError) return l.chatMiscSaveUnsupported;
  if (e is GalException) {
    return switch (e.type) {
      GalExceptionType.accessDenied => l.chatMiscSaveDenied,
      GalExceptionType.notEnoughSpace => l.chatMiscSaveNoSpace,
      _ => l.chatMiscVideoSaveFailed,
    };
  }
  return l.chatMiscVideoSaveFailed;
}

/// Görseli yetkili GET ile alıp galeriye kaydeder; başarısızlıkta [Exception] fırlatır.
typedef SaveImage = Future<void> Function(
    String url, Map<String, String> headers);

/// Varsayılan kaydedici: Android MediaStore / iOS Photos (`gal`). Diğer platformlarda desteklenmez.
Future<void> saveChatImageToGallery(
    String url, Map<String, String> headers) async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    throw UnsupportedError('Bu cihazda desteklenmiyor.');
  }
  final r = await http
      .get(Uri.parse(chatMediaUrl(url)), headers: headers)
      .timeout(const Duration(seconds: 30));
  if (r.statusCode != 200) throw Exception('Görsel indirilemedi.');
  await Gal.putImageBytes(r.bodyBytes,
      name: 'bu_kampus_${DateTime.now().millisecondsSinceEpoch}');
}

String _saveErrorText(Object e, AppLocalizations l) {
  if (e is UnsupportedError) return l.chatMiscSaveUnsupported;
  if (e is GalException) {
    return switch (e.type) {
      GalExceptionType.accessDenied => l.chatMiscSaveDenied,
      GalExceptionType.notEnoughSpace => l.chatMiscSaveNoSpace,
      _ => l.chatMiscImageSaveFailed,
    };
  }
  return l.chatMiscImageSaveFailed;
}

/// Tam ekran görüntüleyici: sohbetin görselleri arasında yatay gezinme, yakınlaştırma, galeriye kaydetme.
class ChatMediaViewer extends StatefulWidget {
  const ChatMediaViewer({
    super.key,
    required this.items,
    required this.headers,
    this.initialIndex = 0,
    this.saveImage = saveChatImageToGallery,
    this.saveVideo = saveChatVideoToGallery,
    this.videoControllerFactory,
  });

  final List<ChatMediaItem> items;
  final Map<String, String> headers;
  final int initialIndex;

  /// Testlerde platform kanalı yerine enjekte edilir.
  final SaveImage saveImage;
  final SaveImage saveVideo;

  /// Testlerde sahte oynatıcı denetleyicisi.
  final VideoControllerFactory? videoControllerFactory;

  @override
  State<ChatMediaViewer> createState() => _ChatMediaViewerState();
}

class _ChatMediaViewerState extends State<ChatMediaViewer> {
  late final PageController _pc = PageController(
      initialPage: widget.initialIndex.clamp(0, widget.items.length - 1));
  late int _index = widget.initialIndex.clamp(0, widget.items.length - 1);
  bool _bars = true;
  bool _zoomed = false;
  bool _saving = false;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  String _meta(ChatMediaItem it) {
    final d = it.at;
    final date = d == null
        ? null
        : '${_two(d.day)}.${_two(d.month)}.${d.year} ${_two(d.hour)}:${_two(d.minute)}';
    return [
      if (it.sender != null && it.sender!.isNotEmpty) it.sender!,
      if (date != null) date
    ].join(' · ');
  }

  Future<void> _save() async {
    if (_saving) return;
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    setState(() => _saving = true);
    String msg;
    final item = widget.items[_index];
    try {
      await (item.isVideo ? widget.saveVideo : widget.saveImage)(
          item.url, widget.headers);
      msg = l.chatMiscSavedToGallery;
    } catch (e) {
      msg = item.isVideo ? chatVideoSaveErrorText(e, l) : _saveErrorText(e, l);
    }
    if (mounted) setState(() => _saving = false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.items[_index];
    final meta = _meta(it);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _bars = !_bars),
            child: PageView.builder(
              controller: _pc,
              itemCount: widget.items.length,
              physics: _zoomed
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              onPageChanged: (i) => setState(() {
                _index = i;
                _zoomed = false;
              }),
              itemBuilder: (c, i) => widget.items[i].isVideo
                  ? _VideoPosterPage(
                      key: ValueKey(widget.items[i].url),
                      item: widget.items[i],
                      headers: widget.headers,
                      controllerFactory: widget.videoControllerFactory,
                    )
                  : _ZoomPage(
                      key: ValueKey(widget.items[i].url),
                      item: widget.items[i],
                      headers: widget.headers,
                      onZoom: (z) {
                        if (z != _zoomed && i == _index) {
                          setState(() => _zoomed = z);
                        }
                      },
                    ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: IgnorePointer(
            ignoring: !_bars,
            child: AnimatedOpacity(
              opacity: _bars ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: Container(
                padding: EdgeInsets.fromLTRB(
                    4, MediaQuery.of(context).padding.top + 4, 4, 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: .7),
                      Colors.black.withValues(alpha: 0)
                    ],
                  ),
                ),
                child: Row(children: [
                  IconButton(
                    tooltip: context.l10n.chatMiscClose,
                    color: Colors.white,
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${_index + 1} / ${widget.items.length}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  BuType.label.copyWith(color: Colors.white)),
                          if (meta.isNotEmpty)
                            Text(meta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: BuType.caption
                                    .copyWith(color: Colors.white70)),
                        ]),
                  ),
                  IconButton(
                    tooltip: context.l10n.chatMiscDownload,
                    color: Colors.white,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(LucideIcons.download),
                    onPressed: _saving ? null : _save,
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Galeride video sayfası: poster + oynat düğmesi; dokununca tam ekran oynatıcı açılır.
class _VideoPosterPage extends StatelessWidget {
  const _VideoPosterPage(
      {super.key,
      required this.item,
      required this.headers,
      this.controllerFactory});

  final ChatMediaItem item;
  final Map<String, String> headers;
  final VideoControllerFactory? controllerFactory;

  void _play(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChatVideoPlayerPage(
          url: item.url,
          headers: headers,
          durationMs: item.durationMs,
          controllerFactory: controllerFactory ??
              (uri, h) => VideoPlayerController.networkUrl(uri, httpHeaders: h),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final thumb = item.thumbUrl;
    return GestureDetector(
      key: const ValueKey('viewerVideoPage'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _play(context),
      child: Stack(alignment: Alignment.center, fit: StackFit.expand, children: [
        if (thumb != null)
          Image.network(chatMediaUrl(thumb),
              headers: headers,
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) => const SizedBox.shrink()),
        Center(
          child: Semantics(
            button: true,
            label: context.l10n.chatMiscPlayVideo,
            child: const PlayBadge(size: 64),
          ),
        ),
        if (item.durationMs != null)
          Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(child: DurationPill(ms: item.durationMs!))),
      ]),
    );
  }
}

class _ZoomPage extends StatefulWidget {
  const _ZoomPage(
      {super.key,
      required this.item,
      required this.headers,
      required this.onZoom});

  final ChatMediaItem item;
  final Map<String, String> headers;
  final ValueChanged<bool> onZoom;

  @override
  State<_ZoomPage> createState() => _ZoomPageState();
}

class _ZoomPageState extends State<_ZoomPage> {
  final _tc = TransformationController();

  @override
  void initState() {
    super.initState();
    _tc.addListener(() => widget.onZoom(_tc.value.getMaxScaleOnAxis() > 1.02));
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _tc,
      minScale: 1,
      maxScale: 5,
      child: Center(
        child: Image.network(
          chatMediaUrl(widget.item.url),
          headers: widget.headers,
          fit: BoxFit.contain,
          loadingBuilder: (c, child, p) => p == null
              ? child
              : const Center(
                  child: CircularProgressIndicator(color: Colors.white)),
          errorBuilder: (c, e, s) => Padding(
            padding: const EdgeInsets.all(32),
            child: Text(context.l10n.chatMiscImageLoadFailed,
                style: BuType.body.copyWith(color: Colors.white70)),
          ),
        ),
      ),
    );
  }
}
