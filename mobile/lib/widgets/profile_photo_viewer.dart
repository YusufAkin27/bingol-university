import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../core/cache/image_disk_cache.dart';
import '../core/locale_controller.dart';
import '../core/theme/bu_motion.dart';
import '../core/theme.dart';
import '../core/icons/bu_icons.dart';
import 'bu_widgets.dart' show fileUrl;

/// Profil fotoğrafı önizleme (ortak): arka plan Gaussian blur + yarı saydam koyu örtü, fotoğraf ortada gerçek
/// oranıyla büyür (ölçek + solma, 220-280 ms). Dışa dokunma / geri tuşu / X düğmesi / aşağı sürükleme kapatır;
/// arka plan etkileşimsizdir. Büyük görsel yüklenirken [thumbUrl] (küçük önizleme) görünür.
///
/// Gizlilik: [imageUrl] boş/null ise (fotoğraf yok ya da gizli) HİÇBİR ŞEY açılmaz; sahte yer tutucu gösterilmez.
/// Tüm avatar kullanımlarında [AvatarLongPress] ile takılır (Keşfet, yorumlar, sohbet, kullanıcı listeleri, arama).
abstract final class ProfilePhotoViewer {
  /// Test için: görsel sağlayıcıyı değiştirir (ağ yerine bellek görseli).
  @visibleForTesting
  static ImageProvider Function(String url, Map<String, String>? headers, int cacheWidth)? providerOverride;

  static ImageProvider _provider(String url, Map<String, String>? headers, int cacheWidth) =>
      (providerOverride ?? (u, h, w) => persistentNetworkImage(u, headers: h, cacheWidth: w))(url, headers, cacheWidth);

  /// Önizlemeyi açar; kapanınca tamamlanır. [heroTag] verilirse kaynak avatar ([AvatarLongPress.heroTag]) ile
  /// Hero geçişi yapılır. [title] (ör. kişi adı) fotoğrafın altında ve ekran okuyucu etiketinde görünür.
  static Future<void> show(
    BuildContext context, {
    required String? imageUrl,
    String? thumbUrl,
    String? heroTag,
    Map<String, String>? headers,
    String? title,
  }) async {
    final full = fileUrl(imageUrl);
    if (full == null) return;
    final thumb = fileUrl(thumbUrl);
    final nav = Navigator.of(context, rootNavigator: true);
    await nav.push<void>(PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      fullscreenDialog: true,
      transitionDuration: AppMotion.of(context, const Duration(milliseconds: 260)),
      reverseTransitionDuration: AppMotion.of(context, const Duration(milliseconds: 200)),
      pageBuilder: (ctx, animation, _) => _ViewerPage(
        animation: animation,
        url: full,
        thumbUrl: thumb,
        heroTag: heroTag,
        headers: headers,
        title: title,
      ),
      // Geçiş içeride (blur/örtü + fotoğraf ölçeği) kurulur; burada ek bir sarmalayıcı yok.
      transitionsBuilder: (ctx, animation, _, child) => child,
    ));
  }
}

/// Avatarı sarar: normal dokunuş [onTap] (genelde profil), UZUN BASMA = [ProfilePhotoViewer]. [onTap] verilmezse
/// dokunuş üstteki öğeye (satırın `InkWell`i) düşer. Fotoğraf yoksa uzun basma hiçbir şey yapmaz.
class AvatarLongPress extends StatelessWidget {
  const AvatarLongPress({
    super.key,
    required this.child,
    required this.imageUrl,
    this.thumbUrl,
    this.onTap,
    this.heroTag,
    this.headers,
    this.title,
    this.enabled = true,
  });

  final Widget child;

  /// Büyük fotoğraf adresi (göreli `/files/...` olabilir). Boşsa uzun basma kapalıdır.
  final String? imageUrl;

  /// Küçük önizleme adresi (genelde aynı adres; küçük çözünürlükte hızlı açılır).
  final String? thumbUrl;
  final VoidCallback? onTap;

  /// Hero etiketi (aynı ekranda benzersiz olmalı); null ise Hero yok.
  final String? heroTag;
  final Map<String, String>? headers;

  /// Önizlemede fotoğrafın altında gösterilen ad.
  final String? title;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final can = enabled && fileUrl(imageUrl) != null;
    Widget body = child;
    if (can && heroTag != null) body = Hero(tag: heroTag!, child: body);
    if (!can) return onTap == null ? body : GestureDetector(onTap: onTap, child: body);
    return Semantics(
      onLongPressHint: context.l10n.srAvatarLongPressHint,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: () {
          unawaited(HapticFeedback.mediumImpact().catchError((Object _) {}));
          ProfilePhotoViewer.show(context,
              imageUrl: imageUrl, thumbUrl: thumbUrl ?? imageUrl, heroTag: heroTag, headers: headers, title: title);
        },
        child: body,
      ),
    );
  }
}

class _ViewerPage extends StatefulWidget {
  const _ViewerPage({
    required this.animation,
    required this.url,
    required this.thumbUrl,
    required this.heroTag,
    required this.headers,
    required this.title,
  });

  final Animation<double> animation;
  final String url;
  final String? thumbUrl;
  final String? heroTag;
  final Map<String, String>? headers;
  final String? title;

  @override
  State<_ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<_ViewerPage> with SingleTickerProviderStateMixin {
  late final ImageProvider _full = ProfilePhotoViewer._provider(widget.url, widget.headers, 1280);
  ImageProvider? _thumb;
  Size? _size; // gerçek görsel oranı (ilk çözülenden)
  bool _fullReady = false;
  bool _failed = false;
  ImageStream? _fullStream;
  ImageStreamListener? _fullListener;
  ImageStream? _thumbStream;
  ImageStreamListener? _thumbListener;

  late final AnimationController _snap = AnimationController(vsync: this, duration: AppMotion.normal);
  double _drag = 0;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    if (widget.thumbUrl != null) _thumb = ProfilePhotoViewer._provider(widget.thumbUrl!, widget.headers, 240);
    _snap.addListener(() {
      if (!_dragging) setState(() => _drag = _snapFrom * (1 - Curves.easeOutCubic.transform(_snap.value)));
    });
  }

  double _snapFrom = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_fullStream == null) {
      final cfg = createLocalImageConfiguration(context);
      _listen(_full, cfg, full: true);
      if (_thumb != null) _listen(_thumb!, cfg, full: false);
    }
  }

  void _listen(ImageProvider p, ImageConfiguration cfg, {required bool full}) {
    final stream = p.resolve(cfg);
    final listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      setState(() {
        _size ??= Size(info.image.width.toDouble(), info.image.height.toDouble());
        if (full) {
          _size = Size(info.image.width.toDouble(), info.image.height.toDouble());
          _fullReady = true;
        }
      });
    }, onError: (_, __) {
      if (mounted && full) setState(() => _failed = true);
    });
    stream.addListener(listener);
    if (full) {
      _fullStream = stream;
      _fullListener = listener;
    } else {
      _thumbStream = stream;
      _thumbListener = listener;
    }
  }

  @override
  void dispose() {
    if (_fullListener != null) _fullStream?.removeListener(_fullListener!);
    if (_thumbListener != null) _thumbStream?.removeListener(_thumbListener!);
    _snap.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).maybePop();

  void _dragEnd(DragEndDetails d) {
    _dragging = false;
    final v = d.primaryVelocity ?? 0;
    if (_drag.abs() > 110 || v.abs() > 900) {
      _close();
      return;
    }
    _snapFrom = _drag;
    _snap
      ..value = 0
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final reduced = BuMotion.reduced(context);
    final curve = CurvedAnimation(parent: widget.animation, curve: AppMotion.enter, reverseCurve: AppMotion.exit);
    final mq = MediaQuery.of(context);
    final maxW = math.min(mq.size.width - 32, 520.0);
    final maxH = (mq.size.height - mq.padding.vertical) * .72;
    // Görsel boyutu bilinene kadar kare yer tutucu; sonra gerçek oran (en çok maxW x maxH, tek yönde ölçek).
    Size box;
    final s = _size;
    if (s == null || s.width <= 0 || s.height <= 0) {
      final side = math.min(maxW, math.min(maxH, 320.0));
      box = Size(side, side);
    } else {
      final k = math.min(maxW / s.width, maxH / s.height);
      box = Size(s.width * k, s.height * k);
    }
    final dragFade = (1 - (_drag.abs() / 400)).clamp(.4, 1.0);

    Widget photo = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        key: const ValueKey('profilePhotoViewerBox'),
        duration: reduced ? Duration.zero : AppMotion.normal,
        curve: AppMotion.standard,
        width: box.width,
        height: box.height,
        color: t.sf2,
        child: Stack(fit: StackFit.expand, children: [
          if (_thumb != null) Image(image: _thumb!, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          AnimatedOpacity(
            opacity: _fullReady ? 1 : 0,
            duration: reduced ? Duration.zero : AppMotion.normal,
            curve: AppMotion.enter,
            child: Image(
              key: const ValueKey('profilePhotoViewerImage'),
              image: _full,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              semanticLabel: widget.title ?? l.srPhotoViewerTitle,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          if (!_fullReady && !_failed && _thumb == null)
            Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.4, color: t.pr))),
          if (_failed && _thumb == null)
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(BuIcons.imageOff, size: 40, color: t.mut),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(l.srPhotoViewerError,
                      textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.mut)),
                ),
              ]),
            ),
        ]),
      ),
    );
    if (widget.heroTag != null) photo = Hero(tag: widget.heroTag!, child: photo);

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: widget.title ?? l.srPhotoViewerTitle,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(fit: StackFit.expand, children: [
          // Blur + koyu örtü: açılışta 0 -> hedef (animasyonlu); dışa dokununca kapanır, altındaki ekran etkileşimsizdir.
          AnimatedBuilder(
            animation: curve,
            builder: (context, _) => BackdropFilter(
              key: const ValueKey('profilePhotoViewerBlur'),
              filter: ImageFilter.blur(sigmaX: 22 * curve.value, sigmaY: 22 * curve.value),
              child: GestureDetector(
                key: const ValueKey('profilePhotoViewerBackdrop'),
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTap: _close,
                child: ColoredBox(color: t.scrim.withValues(alpha: .58 * curve.value * dragFade)),
              ),
            ),
          ),
          SafeArea(
            child: Stack(fit: StackFit.expand, children: [
              Center(
                child: FadeTransition(
                  opacity: curve,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: .86, end: 1).animate(curve),
                    child: GestureDetector(
                      // Fotoğrafa dokunmak kapatmaz; yalnız dikey sürükleme kapatır.
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      onVerticalDragStart: (_) {
                        _dragging = true;
                        _snap.stop();
                      },
                      onVerticalDragUpdate: (d) => setState(() => _drag += d.delta.dy),
                      onVerticalDragEnd: _dragEnd,
                      child: Transform.translate(
                        offset: Offset(0, _drag),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          photo,
                          if ((widget.title ?? '').trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: maxW),
                                child: Text(
                                  widget.title!.trim(),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium!.copyWith(color: t.onMedia, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                top: 8,
                end: 12,
                child: FadeTransition(
                  opacity: curve,
                  child: IconButton(
                    key: const ValueKey('profilePhotoViewerClose'),
                    tooltip: l.srPhotoViewerClose,
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    style: IconButton.styleFrom(backgroundColor: t.scrim.withValues(alpha: .38)),
                    onPressed: _close,
                    icon: Icon(BuIcons.x, color: t.onMedia, size: 22),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
