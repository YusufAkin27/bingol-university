import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'chat_media.dart';
import 'chatd_parts.dart';

// Sohbet medya görüntüleyicilerinin (görsel galerisi, video, tek gösterimlik, tam ekran görsel) ortak parçaları.
// Zemin her iki temada siyahtır (`BuTokens.scrim`); yazı/simge `onMedia`.

/// Medya sayfası iskeleti: her iki temada siyah zemin, açık renkli durum çubuğu simgeleri.
class ChatdMediaScaffold extends StatelessWidget {
  const ChatdMediaScaffold({super.key, required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bu.scrim,
      body: AnnotatedRegion<SystemUiOverlayStyle>(value: SystemUiOverlayStyle.light, child: body),
    );
  }
}

/// Üst çubuk için yuvarlak, yarı saydam koyu simge düğmesi (>= 48 dp dokunma alanı).
/// [busy] iken simge yerine küçük ilerleme çemberi (eylem düğmesi içi) ve düğme devre dışıdır.
class ChatdRoundButton extends StatelessWidget {
  const ChatdRoundButton({super.key, required this.icon, required this.tooltip, required this.onPressed, this.busy = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return IconButton(
      tooltip: tooltip,
      onPressed: busy ? null : onPressed,
      icon: busy
          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, strokeCap: StrokeCap.round, color: t.onMedia))
          : Icon(icon, size: 22),
      style: IconButton.styleFrom(
        backgroundColor: t.scrim.withValues(alpha: .4),
        foregroundColor: t.onMedia,
        disabledBackgroundColor: t.scrim.withValues(alpha: .4),
        disabledForegroundColor: t.onMedia.withValues(alpha: .85),
        minimumSize: const Size(48, 48),
        fixedSize: const Size(48, 48),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

/// Koyu zeminde duran cam görünümlü hap düğme ("Yeniden dene"). Yüksekliği en az 48 dp.
class ChatdGlassButton extends StatelessWidget {
  const ChatdGlassButton({super.key, required this.label, required this.onPressed, this.icon});

  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      child: Material(
        color: t.onMedia.withValues(alpha: .14),
        shape: StadiumBorder(side: BorderSide(color: t.onMedia.withValues(alpha: .32))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            buHaptic(BuHaptic.light);
            onPressed();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 128),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: t.onMedia),
                  const SizedBox(width: 8),
                ],
                Flexible(child: Text(label, maxLines: 2, textAlign: TextAlign.center, style: tx.labelLarge!.copyWith(color: t.onMedia, fontWeight: FontWeight.w700))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Koyu zeminde ortalanmış durum iletisi: simge dairesi + metin + isteğe bağlı eylem (hata, tüketildi, çevrimdışı).
class ChatdMediaMessage extends StatelessWidget {
  const ChatdMediaMessage({super.key, required this.icon, this.text, this.actionLabel, this.onAction, this.title});

  final IconData icon;
  final String? title;
  final String? text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(shape: BoxShape.circle, color: t.onMedia.withValues(alpha: .12)),
              alignment: Alignment.center,
              child: Icon(icon, size: 30, color: t.onMedia.withValues(alpha: .9)),
            ),
            const SizedBox(height: 16),
            if (title != null) Semantics(liveRegion: text == null, child: Text(title!, textAlign: TextAlign.center, style: tx.titleMedium!.copyWith(color: t.onMedia))),
            if (title != null && text != null) const SizedBox(height: 6),
            if (text != null)
              Semantics(
                liveRegion: true,
                child: Text(text!, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.onMedia.withValues(alpha: .78))),
              ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ChatdGlassButton(label: actionLabel!, onPressed: onAction!),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Üst çubuk zemini: üstten saydama inen koyu degrade (durum çubuğu payı dahil).
class ChatdTopBar extends StatelessWidget {
  const ChatdTopBar({super.key, required this.child, this.padding = const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 14)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final top = MediaQuery.paddingOf(context).top;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [t.scrim.withValues(alpha: .72), t.scrim.withValues(alpha: 0)]),
      ),
      child: Padding(padding: padding.add(EdgeInsets.only(top: top)), child: child),
    );
  }
}

/// Alt çubuk zemini: alttan saydama çıkan koyu degrade (alt güvenli alan payı dahil).
class ChatdBottomBar extends StatelessWidget {
  const ChatdBottomBar({super.key, required this.child, this.padding = const EdgeInsetsDirectional.fromSTEB(16, 24, 16, 10)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [t.scrim.withValues(alpha: .72), t.scrim.withValues(alpha: 0)]),
      ),
      child: Padding(padding: padding.add(EdgeInsets.only(bottom: bottom)), child: child),
    );
  }
}

/// Çubukları belirir/kaybolur yapar (opaklık + hafif kayma; "animasyonları azalt" açıkken anlık).
class ChatdChrome extends StatelessWidget {
  const ChatdChrome({super.key, required this.visible, required this.child, this.fromTop = true});

  final bool visible;
  final bool fromTop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : Offset(0, fromTop ? -.25 : .25),
        duration: BuMotion.of(context, BuMotion.short),
        curve: BuMotion.standard,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: BuMotion.of(context, BuMotion.short),
          curve: BuMotion.standard,
          child: child,
        ),
      ),
    );
  }
}

/// Yakınlaştırılabilir ağ görseli: iki parmakla yakınlaştır, çift dokunuşla 2.5x / sıfırla (animasyonlu),
/// yüklenirken (varsa) küçük resim + ilerleme halkası, hatada "Yeniden dene".
class ChatZoomImage extends StatefulWidget {
  const ChatZoomImage({super.key, required this.url, required this.headers, this.thumbUrl, this.onZoom});

  final String url;
  final String? thumbUrl;
  final Map<String, String> headers;

  /// Yakınlaştırma durumu değişince (true: 1x'in üstünde) çağrılır; galeri kaydırmayı kilitlemek için.
  final ValueChanged<bool>? onZoom;

  @override
  State<ChatZoomImage> createState() => _ChatZoomImageState();
}

class _ChatZoomImageState extends State<ChatZoomImage> with SingleTickerProviderStateMixin {
  final _tc = TransformationController();
  late final AnimationController _anim = AnimationController(vsync: this, duration: BuMotion.medium);
  Matrix4Tween? _tween;
  Offset _focal = Offset.zero;
  bool _zoomed = false;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _tc.addListener(_onTransform);
    _anim.addListener(() {
      final tw = _tween;
      if (tw != null) _tc.value = tw.lerp(BuMotion.standard.transform(_anim.value));
    });
  }

  void _onTransform() {
    final z = _tc.value.getMaxScaleOnAxis() > 1.02;
    if (z == _zoomed) return;
    _zoomed = z;
    widget.onZoom?.call(z);
  }

  @override
  void dispose() {
    _anim.dispose();
    _tc.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    const s = 2.5;
    final begin = _tc.value;
    final end = _zoomed
        ? Matrix4.identity()
        : Matrix4(s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, -_focal.dx * (s - 1), -_focal.dy * (s - 1), 0, 1);
    buHaptic(BuHaptic.selection);
    if (BuMotion.reduced(context)) {
      _tc.value = end;
      return;
    }
    _tween = Matrix4Tween(begin: begin, end: end);
    _anim.forward(from: 0);
  }

  /// Yüklenirken: (varsa) küçük resim + ilerleme halkası.
  Widget _loading(ImageChunkEvent? p) {
    final total = p?.expectedTotalBytes;
    final thumb = widget.thumbUrl;
    return Stack(alignment: Alignment.center, fit: StackFit.expand, children: [
      if (thumb != null && thumb != widget.url)
        Image.network(chatMediaUrl(thumb), headers: widget.headers, fit: BoxFit.contain, cacheWidth: 600, gaplessPlayback: true, errorBuilder: (c, e, s) => const SizedBox.shrink()),
      Center(child: ChatdRing(value: (p == null || total == null) ? null : p.cumulativeBytesLoaded / total, icon: LucideIcons.image, semantics: context.l10n.chatdPhotoLoading)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final screenW = MediaQuery.sizeOf(context).width;
    // Yakınlaştırma payı için ekranın ~2 katı genişlikte çözülür (tam çözünürlük belleğe açılmaz).
    final cacheW = (screenW * dpr * 2).ceil().clamp(512, 2400);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: (d) => _focal = d.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _tc,
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: Image.network(
            chatMediaUrl(widget.url),
            key: ValueKey(_attempt),
            headers: widget.headers,
            fit: BoxFit.contain,
            cacheWidth: cacheW,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            frameBuilder: (c, child, frame, sync) => sync
                ? child
                : frame == null
                    ? _loading(null)
                    : TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: BuMotion.of(c, BuMotion.medium),
                        curve: BuMotion.decelerate,
                        builder: (c, v, ch) => Opacity(opacity: v, child: ch),
                        child: child,
                      ),
            loadingBuilder: (c, child, p) => p == null ? child : _loading(p),
            errorBuilder: (c, e, s) => ChatdMediaMessage(
              icon: LucideIcons.imageOff,
              text: l.chatMiscImageLoadFailed,
              actionLabel: l.chatMiscRetry,
              onAction: () => setState(() => _attempt++),
            ),
          ),
        ),
      ),
    );
  }
}
