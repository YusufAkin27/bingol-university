import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/cache/image_disk_cache.dart';
import '../../core/cache/video_cover_cache.dart';
import '../../widgets/bu.dart';
import 'chat_media.dart';
import 'chatd_parts.dart';

/// Sohbet videosunun kapak görseli: TEK ortak bileşen (balon, medya şeridi, galeri Videolar sekmesi, görüntüleyici).
///
/// Sıra: (1) sunucu posteri [posterUrl] varsa o; (2) poster yoksa ya da yüklenemezse videodan istemcinin ürettiği
/// kare ([VideoCoverCache]: bellek + disk önbelleği, aynı video için tek üretim, aynı anda en çok 2); (3) hiçbiri
/// yoksa koyu yer tutucu. Oynat simgesi ve süre rozeti çağıranın işidir (her yerin kendi yerleşimi var); bu
/// bileşen yalnız görseli çizer ve her zaman bulunduğu kutuyu doldurur.
class ChatVideoCover extends StatefulWidget {
  const ChatVideoCover({
    super.key,
    required this.videoUrl,
    required this.headers,
    this.posterUrl,
    this.fit = BoxFit.cover,
    this.decodeWidth = 600,
    this.initialBytes,
    this.cache,
  });

  /// Video akış adresi (sunucu yolu ya da tam adres); üretimin ve önbelleğin anahtarı. Null: yalnız yer tutucu.
  final String? videoUrl;

  /// Sunucu posteri (`thumbUrl`); yoksa null.
  final String? posterUrl;
  final Map<String, String> headers;
  final BoxFit fit;

  /// Çözümleme genişliği (px).
  final int decodeWidth;

  /// Gönderenin yerel kapak baytları: sunucu posteri gelene dek altta durur.
  final Uint8List? initialBytes;

  /// Testlerde özel önbellek; null ise [VideoCoverCache.instance].
  final VideoCoverCache? cache;

  @override
  State<ChatVideoCover> createState() => _ChatVideoCoverState();
}

class _ChatVideoCoverState extends State<ChatVideoCover> {
  Uint8List? _bytes;
  bool _posterFailed = false;

  VideoCoverCache get _cache => widget.cache ?? VideoCoverCache.instance;
  bool get _usePoster => widget.posterUrl != null && !_posterFailed;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(ChatVideoCover old) {
    super.didUpdateWidget(old);
    if (old.videoUrl != widget.videoUrl || old.posterUrl != widget.posterUrl) {
      _posterFailed = false;
      _bytes = null;
      _prepare();
    }
  }

  void _prepare() {
    final v = widget.videoUrl;
    if (v == null || _usePoster) return;
    final url = chatMediaUrl(v);
    final hit = _cache.peek(url);
    if (hit != null) {
      _bytes = hit;
      return;
    }
    _bytes = widget.initialBytes;
    _generate(url);
  }

  Future<void> _generate(String url) async {
    final b = await _cache.cover(url, widget.headers, wanted: () => mounted);
    if (!mounted || b == null || chatMediaUrl(widget.videoUrl ?? '') != url) return;
    setState(() => _bytes = b);
  }

  /// Poster indirilemedi / görsel değil: videodan üret.
  void _onPosterError() {
    if (_posterFailed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _posterFailed = true);
      _prepare();
    });
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(color: kChatdNavy);
    Widget fade(Widget child) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: BuMotion.of(context, BuMotion.medium),
          curve: BuMotion.decelerate,
          builder: (c, v, ch) => Opacity(opacity: v, child: ch),
          child: child,
        );
    final bytes = _bytes;
    return Stack(fit: StackFit.expand, children: [
      placeholder,
      if (_usePoster && widget.initialBytes != null)
        Image.memory(widget.initialBytes!,
            fit: widget.fit, cacheWidth: widget.decodeWidth, filterQuality: FilterQuality.medium, gaplessPlayback: true),
      if (widget.posterUrl != null)
        Image(
          image: persistentNetworkImage(chatMediaUrl(widget.posterUrl!), headers: widget.headers, cacheWidth: widget.decodeWidth),
          fit: widget.fit,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          frameBuilder: (c, child, frame, sync) => sync || frame != null ? fade(child) : const SizedBox.shrink(),
          errorBuilder: (c, e, s) {
            _onPosterError();
            return const SizedBox.shrink();
          },
        ),
      if (!_usePoster && bytes != null)
        fade(Image.memory(
          bytes,
          key: const ValueKey('videoCoverGenerated'),
          fit: widget.fit,
          cacheWidth: widget.decodeWidth,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (c, e, s) => const SizedBox.shrink(),
        )),
    ]);
  }
}
