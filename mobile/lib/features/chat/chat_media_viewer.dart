import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import '../../core/locale_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import 'chat_media.dart';
import 'chat_media_parts.dart';
import 'chat_video_player.dart';
import 'chatd_parts.dart';
import 'message_bubble.dart' show PlayBadge;

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

/// Tam ekran görüntüleyici (referans 26): üstte kapat, "2 / 5" sayfa hapı ve "İndir"; ortada yuvarlatılmış görsel/video kartı;
/// sohbetin görselleri arasında yatay gezinme, yakınlaştırma (çift dokunuş dahil). Tek dokunuş çubukları gizler/gösterir.
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
  late final PageController _pc = PageController(initialPage: widget.initialIndex.clamp(0, widget.items.length - 1));
  late int _index = widget.initialIndex.clamp(0, widget.items.length - 1);
  bool _bars = true;
  bool _zoomed = false;
  bool _saving = false;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final l = context.l10n;
    setState(() => _saving = true);
    String msg;
    var ok = false;
    final item = widget.items[_index];
    try {
      await (item.isVideo ? widget.saveVideo : widget.saveImage)(item.url, widget.headers);
      msg = l.chatMiscSavedToGallery;
      ok = true;
    } catch (e) {
      msg = item.isVideo ? chatVideoSaveErrorText(e, l) : _saveErrorText(e, l);
    }
    if (!mounted) return;
    setState(() => _saving = false);
    BuToast.show(context, msg, kind: ok ? BuToastKind.success : BuToastKind.error, duration: const Duration(seconds: 2));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final n = widget.items.length;
    final it = widget.items[_index];
    // Sayfa içeriği üst çubuğun altından başlar (referans 26: çubuk ile kart ayrı bantlarda).
    final top = MediaQuery.paddingOf(context).top + 4 + 48 + 12;
    final bottom = MediaQuery.paddingOf(context).bottom + 16;
    return ChatdMediaScaffold(
      body: Stack(children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(top: top, bottom: bottom),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: () => setState(() => _bars = !_bars),
              child: PageView.builder(
                controller: _pc,
                itemCount: n,
                physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
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
                    : ChatZoomImage(
                        key: ValueKey(widget.items[i].url),
                        url: widget.items[i].url,
                        thumbUrl: widget.items[i].thumbUrl,
                        headers: widget.headers,
                        onZoom: (z) {
                          if (z != _zoomed && i == _index) setState(() => _zoomed = z);
                        },
                      ),
              ),
            ),
          ),
        ),
        PositionedDirectional(
          start: 0,
          end: 0,
          top: 0,
          child: ChatdChrome(
            visible: _bars,
            child: ChatdTopBar(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 12),
              child: SizedBox(
                height: 48,
                child: Stack(alignment: Alignment.center, children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ChatdRoundButton(icon: LucideIcons.x, tooltip: l.chatMiscClose, onPressed: () => Navigator.pop(context)),
                  ),
                  ChatdBarPill(icon: it.isVideo ? null : LucideIcons.image, label: '${_index + 1} / $n'),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: ChatdBarPill(icon: LucideIcons.download, label: l.chatMiscDownload, busy: _saving, onTap: _save),
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

/// Galeride video sayfası: yuvarlatılmış poster kartı + beyaz oynat düğmesi + "Videoyu oynat" hapı + süre.
/// Dokununca tam ekran oynatıcı açılır.
class _VideoPosterPage extends StatelessWidget {
  const _VideoPosterPage({super.key, required this.item, required this.headers, this.controllerFactory});

  final ChatMediaItem item;
  final Map<String, String> headers;
  final VideoControllerFactory? controllerFactory;

  void _play(BuildContext context) {
    buHaptic(BuHaptic.light);
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChatVideoPlayerPage(
          url: item.url,
          headers: headers,
          durationMs: item.durationMs,
          controllerFactory: controllerFactory ?? (uri, h) => VideoPlayerController.networkUrl(uri, httpHeaders: h),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final thumb = item.thumbUrl;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final w = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: GestureDetector(
          key: const ValueKey('viewerVideoPage'),
          behavior: HitTestBehavior.opaque,
          onTap: () => _play(context),
          child: Stack(alignment: Alignment.center, fit: StackFit.expand, children: [
            ColoredBox(color: kChatdNavy),
            if (thumb != null)
              Image.network(chatMediaUrl(thumb),
                  headers: headers,
                  fit: BoxFit.contain,
                  cacheWidth: (w * dpr).ceil().clamp(300, 1600),
                  gaplessPlayback: true,
                  errorBuilder: (c, e, s) => const SizedBox.shrink()),
            ColoredBox(color: t.scrim.withValues(alpha: .18)),
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Semantics(button: true, label: context.l10n.chatMiscPlayVideo, child: const PlayBadge(size: 80)),
                const SizedBox(height: 12),
                ChatdBarPill(label: context.l10n.chatMiscPlayVideo, color: t.scrim.withValues(alpha: .7)),
              ]),
            ),
            if (item.durationMs != null)
              PositionedDirectional(
                bottom: 14,
                end: 14,
                child: ChatdBarPill(
                  iconWidget: Icon(LucideIcons.video, size: 14, color: t.pr),
                  label: formatMediaDuration(item.durationMs!),
                  color: t.scrim.withValues(alpha: .7),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
