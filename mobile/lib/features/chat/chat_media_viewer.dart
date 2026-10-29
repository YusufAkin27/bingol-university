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

/// Tam ekran görüntüleyici: sohbetin görselleri arasında yatay gezinme, yakınlaştırma (çift dokunuş dahil),
/// galeriye kaydetme, alt küçük resim şeridi. Tek dokunuş çubukları gizler/gösterir.
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
  static const _thumb = 48.0;
  static const _thumbGap = 6.0;

  late final PageController _pc = PageController(
      initialPage: widget.initialIndex.clamp(0, widget.items.length - 1));
  final _strip = ScrollController();
  late int _index = widget.initialIndex.clamp(0, widget.items.length - 1);
  bool _bars = true;
  bool _zoomed = false;
  bool _saving = false;

  @override
  void dispose() {
    _pc.dispose();
    _strip.dispose();
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
    final l = context.l10n;
    setState(() => _saving = true);
    String msg;
    var ok = false;
    final item = widget.items[_index];
    try {
      await (item.isVideo ? widget.saveVideo : widget.saveImage)(
          item.url, widget.headers);
      msg = l.chatMiscSavedToGallery;
      ok = true;
    } catch (e) {
      msg = item.isVideo ? chatVideoSaveErrorText(e, l) : _saveErrorText(e, l);
    }
    if (!mounted) return;
    setState(() => _saving = false);
    BuToast.show(context, msg,
        kind: ok ? BuToastKind.success : BuToastKind.error,
        duration: const Duration(seconds: 2));
  }

  void _jump(int i) {
    if (i == _index) return;
    buHaptic(BuHaptic.selection);
    final d = BuMotion.of(context, BuMotion.medium);
    if (d == Duration.zero) {
      _pc.jumpToPage(i);
    } else {
      _pc.animateToPage(i, duration: d, curve: BuMotion.standard);
    }
  }

  void _followStrip(int i) {
    if (!_strip.hasClients) return;
    final vp = _strip.position.viewportDimension;
    final target = (i * (_thumb + _thumbGap) - (vp - _thumb) / 2)
        .clamp(0.0, _strip.position.maxScrollExtent);
    final d = BuMotion.of(context, BuMotion.medium);
    if (d == Duration.zero) {
      _strip.jumpTo(target);
    } else {
      _strip.animateTo(target, duration: d, curve: BuMotion.standard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final n = widget.items.length;
    final it = widget.items[_index];
    final meta = _meta(it);
    return ChatdMediaScaffold(
      body: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _bars = !_bars),
            child: PageView.builder(
              controller: _pc,
              itemCount: n,
              physics: _zoomed
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              onPageChanged: (i) {
                setState(() {
                  _index = i;
                  _zoomed = false;
                });
                _followStrip(i);
              },
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
                        if (z != _zoomed && i == _index) {
                          setState(() => _zoomed = z);
                        }
                      },
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
              child: Row(children: [
                ChatdRoundButton(
                    icon: LucideIcons.x,
                    tooltip: l.chatMiscClose,
                    onPressed: () => Navigator.pop(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${_index + 1} / $n',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tx.titleSmall!.copyWith(
                                color: t.onMedia, fontWeight: FontWeight.w700)),
                        if (meta.isNotEmpty)
                          Text(meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tx.bodySmall!.copyWith(
                                  color: t.onMedia.withValues(alpha: .78))),
                      ]),
                ),
                const SizedBox(width: 8),
                ChatdRoundButton(
                    icon: LucideIcons.download,
                    tooltip: l.chatMiscDownload,
                    busy: _saving,
                    onPressed: _save),
              ]),
            ),
          ),
        ),
        if (n > 1)
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: ChatdChrome(
              visible: _bars,
              fromTop: false,
              child: ChatdBottomBar(
                padding: const EdgeInsetsDirectional.fromSTEB(0, 28, 0, 10),
                child: SizedBox(
                  height: _thumb,
                  child: ListView.builder(
                    controller: _strip,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: n,
                    itemExtent: _thumb + _thumbGap,
                    itemBuilder: (c, i) => _StripThumb(
                      item: widget.items[i],
                      headers: widget.headers,
                      selected: i == _index,
                      label: l.p08ItemOf('${i + 1}', '$n'),
                      onTap: () => _jump(i),
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

/// Alt şeritteki küçük resim (48 dp): seçili olan açık halkalı, diğerleri hafif karartılı.
class _StripThumb extends StatelessWidget {
  const _StripThumb(
      {required this.item,
      required this.headers,
      required this.selected,
      required this.label,
      required this.onTap});

  final ChatMediaItem item;
  final Map<String, String> headers;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final src = item.isVideo ? item.thumbUrl : (item.thumbUrl ?? item.url);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: 6),
          child: AnimatedContainer(
            duration: BuMotion.of(context, BuMotion.short),
            curve: BuMotion.standard,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selected ? t.onMedia : t.onMedia.withValues(alpha: 0),
                  width: 2),
            ),
            padding: const EdgeInsets.all(2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Stack(fit: StackFit.expand, children: [
                if (src == null)
                  ColoredBox(color: t.onMedia.withValues(alpha: .14))
                else
                  Image.network(chatMediaUrl(src),
                      headers: headers,
                      fit: BoxFit.cover,
                      cacheWidth: 144,
                      gaplessPlayback: true,
                      errorBuilder: (c, e, s) =>
                          ColoredBox(color: t.onMedia.withValues(alpha: .14))),
                if (!selected)
                  ColoredBox(color: t.scrim.withValues(alpha: .42)),
                if (item.isVideo)
                  Center(
                      child:
                          Icon(LucideIcons.play, size: 16, color: t.onMedia)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Galeride video sayfası: poster + oynat düğmesi + süre; dokununca tam ekran oynatıcı açılır.
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
    buHaptic(BuHaptic.light);
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
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final w = MediaQuery.sizeOf(context).width;
    return GestureDetector(
      key: const ValueKey('viewerVideoPage'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _play(context),
      child: Stack(alignment: Alignment.center, fit: StackFit.expand, children: [
        if (thumb != null)
          Image.network(chatMediaUrl(thumb),
              headers: headers,
              fit: BoxFit.contain,
              cacheWidth: (w * dpr).ceil().clamp(300, 1600),
              gaplessPlayback: true,
              errorBuilder: (c, e, s) => const SizedBox.shrink()),
        Center(
          child: Semantics(
            button: true,
            label: context.l10n.chatMiscPlayVideo,
            child: const PlayBadge(size: 72),
          ),
        ),
        if (item.durationMs != null)
          PositionedDirectional(
            bottom: 96,
            start: 0,
            end: 0,
            child: Center(child: ChatdDuration(ms: item.durationMs!)),
          ),
      ]),
    );
  }
}
