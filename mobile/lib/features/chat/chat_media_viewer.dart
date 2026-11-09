import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../../core/locale_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import 'chat_media.dart';
import 'chat_media_pager.dart';
import 'chat_media_parts.dart';
import 'chat_video_cover.dart';
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
    } catch (_) {
      // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
    }
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
    this.pager,
  });

  final List<ChatMediaItem> items;

  /// Doluysa eskiye doğru sonsuz yükleme: [items] eskiden yeniye sıralı olmalı ve pager'ın başlangıç listesi ile aynıdır.
  final ChatMediaPager? pager;
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
  late PageController _pc = PageController(initialPage: _index);
  late int _index = widget.initialIndex.clamp(0, widget.items.length - 1);
  double _drag = 0;
  List<ChatMediaItem> get _items => widget.pager?.items ?? widget.items;
  bool _bars = true;
  bool _zoomed = false;
  bool _saving = false;
  final ScrollController _strip = ScrollController();

  /// Alt şerit: küçük resim kenarı + aralık (kaydırma konumu hesabı için).
  static const double _thumb = 52;
  static const double _gap = 6;

  @override
  void dispose() {
    widget.pager?.removeListener(_onPager);
    _pc.dispose();
    _strip.dispose();
    super.dispose();
  }

  /// Seçili küçük resmi şeridin ortasına getirir.
  void _centerStrip(int i, {bool animate = true}) {
    if (!_strip.hasClients) return;
    final view = _strip.position.viewportDimension;
    final target = (i * (_thumb + _gap) - (view - _thumb) / 2).clamp(0.0, _strip.position.maxScrollExtent);
    if (animate) {
      _strip.animateTo(target, duration: BuMotion.of(context, BuMotion.short), curve: BuMotion.standard);
    } else {
      _strip.jumpTo(target);
    }
  }

  @override
  void initState() {
    super.initState();
    widget.pager?.addListener(_onPager);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _centerStrip(_index, animate: false);
    });
    _maybeLoadOlder();
  }

  /// Başa yakınsa daha eski medyayı ister (sınırsız sorgu yok: pager sayfalı ve imleçli).
  void _maybeLoadOlder() {
    final p = widget.pager;
    if (p != null && p.hasOlder && !p.loadingOlder && p.error == null && _index < 5) p.loadOlder();
  }

  void _onPager() {
    if (!mounted) return;
    final k = widget.pager!.prepended;
    if (k > 0 && !_consumed) {
      // Başa eklenen öğeler indeksleri kaydırır: aynı medyada kalmak için yeni denetleyici (kare sıçraması olmadan).
      _consumed = true;
      final old = _pc;
      _index += k;
      _pc = PageController(initialPage: _index);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        old.dispose();
        if (mounted) _centerStrip(_index, animate: false);
      });
    }
    if (widget.pager!.loadingOlder) _consumed = false;
    setState(() {});
  }

  bool _consumed = false;

  void _goTo(int i) {
    if (i == _index) return;
    buHaptic(BuHaptic.light);
    _pc.animateToPage(i, duration: BuMotion.of(context, BuMotion.medium), curve: BuMotion.standard);
  }

  Future<void> _save() async {
    if (_saving) return;
    final l = context.l10n;
    setState(() => _saving = true);
    String msg;
    var ok = false;
    final item = _items[_index];
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

  /// "Gönderen · 9 Kas 14:32" alt yazısı; ikisi de yoksa null.
  String? _meta(ChatMediaItem it) {
    final parts = <String>[];
    if (it.sender != null && it.sender!.isNotEmpty) parts.add(it.sender!);
    final at = it.at;
    if (at != null) {
      final loc = Localizations.localeOf(context).toLanguageTag();
      try {
        parts.add(DateFormat.MMMd(loc).add_Hm().format(at.toLocal()));
      } catch (_) {
        parts.add(DateFormat.MMMd().add_Hm().format(at.toLocal()));
      }
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = _items;
    final n = items.length;
    final it = items[_index];
    final pager = widget.pager;
    final more = pager?.hasOlder ?? false;
    final counter = '${_index + 1} / $n${more ? '+' : ''}';
    final meta = _meta(it);
    // Sayfa içeriği üst çubuğun altından başlar (referans 26: çubuk ile kart ayrı bantlarda).
    final top = MediaQuery.paddingOf(context).top + 4 + 48 + 12;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    // Birden çok medya varsa alta küçük resim şeridi girer; sayfa içeriği şeridin üstünde kalır.
    final stripH = n > 1 ? _thumb + 16 : 0.0;
    final bottom = safeBottom + 16 + stripH;
    return ChatdMediaScaffold(
      body: Stack(children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(top: top, bottom: bottom),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: () => setState(() => _bars = !_bars),
              onVerticalDragUpdate: _zoomed ? null : (d) => setState(() => _drag = (_drag + d.delta.dy).clamp(0.0, 600.0)),
              onVerticalDragEnd: _zoomed
                  ? null
                  : (d) {
                      if (_drag > 120 || (d.primaryVelocity ?? 0) > 800) {
                        Navigator.pop(context);
                      } else {
                        setState(() => _drag = 0);
                      }
                    },
              onVerticalDragCancel: () => setState(() => _drag = 0),
              child: Transform.translate(
                offset: Offset(0, _drag),
                child: Opacity(
                  opacity: (1 - _drag / 500).clamp(.4, 1.0),
                  child: PageView.builder(
                key: ValueKey(_pc),
                controller: _pc,
                itemCount: n,
                physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
                onPageChanged: (i) {
                  setState(() {
                    _index = i;
                    _zoomed = false;
                  });
                  _centerStrip(i);
                  _maybeLoadOlder();
                },
                itemBuilder: (c, i) => Semantics(
                  container: true,
                  label: l.chatMediaPosition(i + 1, n),
                  child: items[i].isVideo
                    ? _VideoPosterPage(
                        key: ValueKey(items[i].url),
                        item: items[i],
                        headers: widget.headers,
                        controllerFactory: widget.videoControllerFactory,
                      )
                    : ChatZoomImage(
                        key: ValueKey(items[i].url),
                        url: items[i].url,
                        thumbUrl: items[i].thumbUrl,
                        headers: widget.headers,
                        onZoom: (z) {
                          if (z != _zoomed && i == _index) setState(() => _zoomed = z);
                        },
                      ),
                ),
              ),
                ),
              ),
            ),
          ),
        ),
        if (meta != null || (pager != null && (pager.loadingOlder || pager.error != null)))
          PositionedDirectional(
            start: 16,
            end: 16,
            bottom: safeBottom + 8 + (n > 1 ? _thumb + 12 : 0),
            child: ChatdChrome(
              visible: _bars,
              fromTop: false,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (pager != null && pager.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ChatdBarPill(
                      key: const ValueKey('viewerOlderRetry'),
                      icon: BuIcons.refreshCw,
                      label: l.chatMediaOlderFailed,
                      onTap: () {
                        pager.error = null;
                        pager.loadOlder();
                      },
                    ),
                  )
                else if (pager != null && pager.loadingOlder)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Semantics(
                      liveRegion: true,
                      label: l.chatMediaOlderLoading,
                      child: SizedBox(
                        key: const ValueKey('viewerOlderLoading'),
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, strokeCap: StrokeCap.round, color: context.bu.onMedia),
                      ),
                    ),
                  ),
                if (meta != null)
                  Text(meta,
                      key: const ValueKey('viewerMeta'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge!.copyWith(color: context.bu.onMedia, fontWeight: FontWeight.w400)),
              ]),
            ),
          ),
        if (n > 1)
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: safeBottom + 8,
            child: ChatdChrome(
              visible: _bars,
              fromTop: false,
              child: SizedBox(
                key: const ValueKey('viewerStrip'),
                height: _thumb + 4,
                child: ListView.separated(
                  controller: _strip,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  itemCount: n,
                  separatorBuilder: (_, __) => const SizedBox(width: _gap),
                  itemBuilder: (c, i) => _StripThumb(
                    key: ValueKey('viewerThumb$i'),
                    item: items[i],
                    headers: widget.headers,
                    size: _thumb,
                    selected: i == _index,
                    label: l.chatMediaPosition(i + 1, n),
                    onTap: () => _goTo(i),
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
                    child: ChatdRoundButton(icon: BuIcons.x, tooltip: l.chatMiscClose, onPressed: () => Navigator.pop(context)),
                  ),
                  ChatdBarPill(icon: it.isVideo ? null : BuIcons.image, label: counter, semanticsLabel: l.chatMediaPosition(_index + 1, n)),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: ChatdBarPill(icon: BuIcons.download, label: l.chatMiscDownload, busy: _saving, onTap: _save),
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

/// Alt şeritteki küçük resim: seçili olan tam opak + beyaz çerçeve, diğerleri soluk; videoda küçük oynat simgesi.
class _StripThumb extends StatelessWidget {
  const _StripThumb(
      {super.key,
      required this.item,
      required this.headers,
      required this.size,
      required this.selected,
      required this.label,
      required this.onTap});

  final ChatMediaItem item;
  final Map<String, String> headers;
  final double size;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final src = item.thumbUrl ?? (item.isVideo ? null : item.url);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: selected ? 1 : .55,
          duration: BuMotion.of(context, BuMotion.short),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? t.prText : Colors.transparent, width: 2),
              color: kChatdNavy,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(fit: StackFit.expand, children: [
                if (src != null)
                  Image.network(
                    chatMediaUrl(src),
                    headers: headers,
                    fit: BoxFit.cover,
                    cacheWidth: (size * dpr).ceil(),
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                if (item.isVideo)
                  Center(child: Icon(BuIcons.video, size: 18, color: t.prText)),
              ]),
            ),
          ),
        ),
      ),
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
      MaterialPageRoute<void>(settings: const RouteSettings(name: 'chat_video_player'), 
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
            // Kapak: sunucu posteri, yoksa videodan üretilen kare (önbellekli); hiçbiri yoksa koyu zemin.
            ChatVideoCover(
                videoUrl: item.url,
                posterUrl: thumb,
                headers: headers,
                fit: BoxFit.contain,
                decodeWidth: (w * dpr).ceil().clamp(300, 1600)),
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
                  iconWidget: Icon(BuIcons.video, size: 14, color: t.prText),
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
