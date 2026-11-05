import 'dart:async';
import 'dart:io' show File;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/cache/image_disk_cache.dart';
import '../../core/cache/video_prefetch.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../chat/chat_media.dart' show formatMediaDuration;
import '../chat/chat_video_player.dart' show ChatVideoPlayerPage;
import 'post_api.dart';
import 'post_models.dart';

/// Testlerde sahte denetleyici verilebilsin diye.
typedef PostVideoControllerFactory = VideoPlayerController Function(Uri uri, Map<String, String> headers);

VideoPlayerController _networkController(Uri uri, Map<String, String> headers) =>
    VideoPlayerController.networkUrl(uri, httpHeaders: headers, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));

/// Yerel (önyüklenmiş) dosyadan oynatıcı; testlerde sahte denetleyici verilebilsin diye.
typedef PostVideoFileControllerFactory = VideoPlayerController Function(File file);

VideoPlayerController _fileController(File file) =>
    VideoPlayerController.file(file, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));

/// Test kancası: null değilse tüm gönderi videoları bununla kurulur.
PostVideoControllerFactory? debugPostVideoControllerFactory;

/// Test kancası: null değilse yerel dosyadan oynatılan videolar bununla kurulur.
PostVideoFileControllerFactory? debugPostVideoFileControllerFactory;

/// Dışarıdan (akış kartı) oynat/duraklat tetiklemek için ([PostVideoView.controller]).
class PostVideoController {
  _PostVideoViewState? _state;

  /// Oynuyorsa duraklatır, duraklatılmışsa sürdürür (hazır değilse hiçbir şey yapmaz). İkon kısa süre görünüp solar.
  void toggle() => _state?._togglePlay();

  /// Şu an oynuyor mu.
  bool get playing => _state?._c?.value.isPlaying ?? false;
}

/// Oturum boyunca ortak ses tercihi: akıştaki videolar SESSİZ başlar; biri açılınca sonrakiler de açık kalır.
final ValueNotifier<bool> postVideoMuted = ValueNotifier<bool>(true);

/// Gönderi videosunun tam ekran izlenmesi (sesli, kaydırma çubuklu; sohbet oynatıcısı yeniden kullanılır).
Future<void> openPostVideoViewer(BuildContext context, Session session, Post post) {
  final v = post.video;
  if (v == null) return Future<void>.value();
  return Navigator.of(context).push<void>(MaterialPageRoute<void>(settings: const RouteSettings(name: 'post_video'), 
    fullscreenDialog: true,
    builder: (_) => ChatVideoPlayerPage(
      url: v.url,
      headers: postAuthHeaders(session),
      durationMs: v.durationMs,
      controllerFactory: debugPostVideoControllerFactory ?? _networkController,
    ),
  ));
}

/// Akış kartındaki video alanının oranı (genişlik/yükseklik): dikey videolar 3:4'e, çok yatay olanlar 16:9'a kıstırılır
/// (tam görüntü için tam ekran düğmesi vardır).
double postVideoCardRatio(Post p) => (p.video?.aspect ?? 4 / 5).clamp(.75, 16 / 9).toDouble();

/// Video gönderi önizlemesinin ortasındaki oynat rozeti (yalnız görsel; dokunma altındaki öğeye gider).
class PostPlayBadge extends StatelessWidget {
  const PostPlayBadge({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(child: _Disc(icon: BuIcons.playFilled, size: size, iconSize: size * .45));
}

/// Dokunma davranışı: [sound] ses aç/kapat (akış kartı), [playPause] oynat/duraklat (Reels).
enum PostVideoTap { sound, playPause }

/// Gönderi videosu: poster kare hemen görünür, video hazır olunca üstüne biner.
///
/// * [active] verilmezse oynatma KAYDIRMAYLA belirlenir: video alanının en az %60'ı ekranda ise sessiz ve döngülü
///   oynar, ekran dışına çıkınca durur (üstteki rota açıksa da durur). [active] verilirse (Reels) o belirler.
/// * Ses tercihi [postVideoMuted] ile ortaktır; sağ altta ses düğmesi.
/// * İzlenen süre, video durunca/ekrandan çıkınca `POST /posts/{id}/view {watchedMs, durationMs}` ile bildirilir
///   (en az 1 sn izlenmişse; puana etkisi sunucudadır).
class PostVideoView extends StatefulWidget {
  const PostVideoView({
    super.key,
    required this.session,
    required this.post,
    this.active,
    this.fit = BoxFit.cover,
    this.tap = PostVideoTap.sound,
    this.showFullscreen = true,
    this.showProgress = false,
    this.reportViews = true,
    this.handleTap = true,
    this.inset = EdgeInsets.zero,
    this.soundOnTop = false,
    this.showControls = true,
    this.prepare = false,
    this.api,
    this.controller,
    this.flashIcon = false,
  });

  final Session session;
  final Post post;

  /// Dışarıdan oynat/duraklat için (akış kartı).
  final PostVideoController? controller;

  /// true: oynat/duraklat ikonu yalnız KISA süre görünüp solar (kalıcı "oynat" diski çizilmez).
  final bool flashIcon;

  /// null: kaydırma görünürlüğüne göre; true/false: dışarıdan (Reels sayfa göstergesi).
  final bool? active;
  final BoxFit fit;
  final PostVideoTap tap;

  /// Sağ üstte "tam ekran izle" düğmesi.
  final bool showFullscreen;

  /// Altta ince ilerleme çizgisi (Reels).
  final bool showProgress;
  final bool reportViews;

  /// false: dokunmayı üst öğe yönetir (ör. çift dokunuşla beğeni sarmalayıcısı); düğmeler yine çalışır.
  final bool handleTap;

  /// Denetimlerin (ses, ilerleme, süre) kaçınacağı kenar payı: Reels'te üst çubuk ve yüzen alt gezinme.
  final EdgeInsets inset;

  /// Ses düğmesi sağ üstte (Reels: sağ alt köşe beğeni sütununa ayrılır).
  final bool soundOnTop;

  /// false: ses/tam ekran düğmeleri çizilmez (üst öğe [PostVideoSoundButton]/[PostVideoFullscreenButton] ile kendisi çizer).
  final bool showControls;

  /// true: [active] false iken bile oynatıcı kurulur ve ilk kareye hazırlanır AMA OYNATILMAZ (Reels'te sıradaki video:
  /// kaydırınca gecikmeden başlasın). Yalnız aktif olan oynar.
  final bool prepare;
  final PostApi? api;

  @override
  State<PostVideoView> createState() => _PostVideoViewState();
}

class _PostVideoViewState extends State<PostVideoView> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  /// Kaydırmayla oynatma için gereken görünür oran.
  static const _visibleFraction = .6;

  VideoPlayerController? _c;
  ScrollPosition? _scroll;
  late final PostApi _api = widget.api ?? PostApi(widget.session);

  bool _visible = false;
  bool _foreground = true;
  bool _userPaused = false;
  bool _failed = false;
  bool _initializing = false;
  DateTime? _since;
  int _watchedMs = 0;

  /// Oynat/duraklat ikonunun kısa görünüp solması (sonuç: oynuyor -> oynat ikonu, duraklatıldı -> duraklat ikonu).
  late final AnimationController _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  bool _flashPlay = true;

  PostVideo get _video => widget.post.video!;

  bool get _want => (widget.active ?? _visible) && _foreground && !_userPaused;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    WidgetsBinding.instance.addObserver(this);
    postVideoMuted.addListener(_applyVolume);
    // İlk çerçeveden sonra görünürlük (ya da dışarıdan verilen [active]) uygulanır.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _check();
      _apply();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Üstte rota açılıp kapanınca (tam ekran, profil) görünürlük yeniden değerlendirilir.
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    final pos = Scrollable.maybeOf(context)?.position;
    if (!identical(pos, _scroll)) {
      _scroll?.removeListener(_check);
      _scroll = pos;
      _scroll?.addListener(_check);
    }
  }

  @override
  void didUpdateWidget(PostVideoView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      if (old.controller?._state == this) old.controller!._state = null;
      widget.controller?._state = this;
    }
    if (old.post.video?.url != widget.post.video?.url) {
      _release();
      _failed = false;
    }
    if (old.active != widget.active || old.prepare != widget.prepare) _apply();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _apply();
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller!._state = null;
    _flash.dispose();
    WidgetsBinding.instance.removeObserver(this);
    postVideoMuted.removeListener(_applyVolume);
    _scroll?.removeListener(_check);
    _flushView();
    _c?.dispose();
    _c = null;
    super.dispose();
  }

  /// Video alanının ekranda ne kadarının göründüğüne bakar (yalnız [PostVideoView.active] null iken).
  void _check() {
    if (!mounted || widget.active != null) return;
    final ro = context.findRenderObject();
    var vis = false;
    if (ro is RenderBox && ro.attached && ro.hasSize && ro.size.height > 0) {
      final top = ro.localToGlobal(Offset.zero).dy;
      final h = ro.size.height;
      final screen = MediaQuery.sizeOf(context).height;
      final shown = math.min(top + h, screen) - math.max(top, 0);
      vis = shown / h >= _visibleFraction;
      // Üstte başka bir rota (tam ekran, alt sayfa) varsa oynatma.
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) vis = false;
    }
    if (vis != _visible) {
      _visible = vis;
      // Görünümden çıkınca duraklatma isteği unutulur: dönüşte yeniden kendiliğinden oynar.
      if (!vis) _userPaused = false;
      _apply();
    }
  }

  void _apply() {
    if (!mounted) return;
    if (_want) {
      if (_userPaused) return;
      final c = _c;
      if (c == null) {
        _init();
      } else if (c.value.isInitialized && !c.value.isPlaying) {
        _applyVolume();
        c.play();
        _since ??= DateTime.now();
        setState(() {});
      }
    } else {
      final c = _c;
      if (c != null && widget.active == null && !widget.prepare) {
        // Kaydırmayla yönetilen video ekrandan çıktı: oynatıcı atılır (bellek); dönüşte yerel dosyadan hızla kurulur.
        _release();
        setState(() {});
      } else if (c != null && c.value.isInitialized && c.value.isPlaying) {
        c.pause();
        _flushView();
        setState(() {});
      } else if (c == null && widget.prepare && _foreground) {
        _init(); // hazırlık: kur + ilk kare, oynatma yok (_init yalnız _want iken oynatır)
      }
    }
  }

  Future<void> _init() async {
    if (_initializing || _failed) return;
    _initializing = true;
    final headers = postAuthHeaders(widget.session);
    final item = VideoPrefetchItem(_video.url, headers);
    VideoPlayerController? c;
    try {
      // Önce YEREL dosya (önyükleme hattı): hazırsa hemen, indiriliyorsa kısa süre beklenir. O sırada POSTER görünür
      // kalır ve oynatıcı kurulmaz (donma yok). Dosya gelmezse (zaman aşımı/hata/ölçülü ağ) ağdan oynatılır.
      final pf = VideoPrefetcher.instance;
      final file = _want ? await pf.ensure(item) : await pf.localFile(item.url);
      if (!mounted) return;
      if (!_want && !widget.prepare) return; // beklerken kaydırıldı: oynatıcı kurulmaz
      var local = file != null;
      c = file != null
          ? (debugPostVideoFileControllerFactory ?? _fileController)(file)
          : (debugPostVideoControllerFactory ?? _networkController)(Uri.parse(_video.url), headers);
      _c = c;
      try {
        await c.initialize();
      } catch (_) {
        if (!local) rethrow;
        // Bozuk yerel dosya: ağdan yeniden dene.
        local = false;
        unawaited(c.dispose());
        c = (debugPostVideoControllerFactory ?? _networkController)(Uri.parse(_video.url), headers);
        _c = c;
        await c.initialize();
      }
      if (!mounted || _c != c) return;
      await c.setLooping(true);
      c.addListener(_onTick);
      _applyVolume();
      if (_want) {
        await c.play();
        _since = DateTime.now();
      }
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted && c != null && _c == c) {
        setState(() {
          _failed = true;
        });
      }
    } finally {
      _initializing = false;
    }
  }

  void _onTick() {
    final c = _c;
    if (c == null || !mounted) return;
    if (c.value.hasError && !_failed) setState(() => _failed = true);
  }

  void _applyVolume() {
    final c = _c;
    if (c != null && c.value.isInitialized) c.setVolume(postVideoMuted.value ? 0 : 1);
    if (mounted) setState(() {});
  }

  /// Oynama süresini toplar (gönderim yok): kullanıcı duraklatınca erken olay göndermemek için.
  void _accumulate() {
    final s = _since;
    if (s != null) {
      _watchedMs += DateTime.now().difference(s).inMilliseconds;
      _since = null;
    }
  }

  /// İzlenen süreyi toplar ve bildirir. Sunucu olayı 6 saatte bir sayar ve hızlı geçmeyi (< 1,5 sn) kendisi çıkarır;
  /// bu yüzden video ekrandan ÇIKINCA/kapanınca BİR kez gönderilir (duraklatmada değil). 300 ms altı yok sayılır.
  void _flushView() {
    _accumulate();
    final ms = _watchedMs;
    _watchedMs = 0;
    if (!widget.reportViews || ms < 300) return;
    final dur = _c?.value.duration.inMilliseconds ?? _video.durationMs ?? 0;
    final id = widget.post.id;
    unawaited(_api.view(id, watchedMs: ms, durationMs: dur > 0 ? dur : (_video.durationMs ?? ms)));
  }

  void _release() {
    _flushView();
    _c?.removeListener(_onTick);
    _c?.dispose();
    _c = null;
  }

  void _onTap() {
    if (widget.tap == PostVideoTap.sound) {
      buHaptic(BuHaptic.selection);
      postVideoMuted.value = !postVideoMuted.value;
      return;
    }
    _togglePlay();
  }

  /// Oynuyorsa duraklatır, duraklatılmışsa sürdürür.
  void _togglePlay() {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    buHaptic(BuHaptic.selection);
    if (c.value.isPlaying) {
      _userPaused = true;
      c.pause();
      _accumulate();
      _flashPlay = false;
    } else {
      _userPaused = false;
      _apply();
      _flashPlay = true;
    }
    if (widget.flashIcon) _flash.forward(from: 0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final c = _c;
    final ready = c != null && c.value.isInitialized && !_failed;
    final playing = ready && c.value.isPlaying;
    final dur = _video.durationMs ?? 0;
    return Semantics(
      container: true,
      label: [if (widget.post.hasText) widget.post.text!.trim(), l.chatMiscVideoWithDuration(formatMediaDuration(dur))].join(', '),
      child: GestureDetector(
        key: const ValueKey('postVideo'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.handleTap ? _onTap : null,
        child: Stack(fit: StackFit.expand, children: [
          ColoredBox(color: t.sf2),
          _Poster(post: widget.post, session: widget.session, fit: widget.fit),
          if (ready)
            RepaintBoundary(
              child: FittedBox(
                fit: widget.fit,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: c.value.size.width > 0 ? c.value.size.width : 720,
                  height: c.value.size.height > 0 ? c.value.size.height : 1280,
                  child: VideoPlayer(c),
                ),
              ),
            ),
          if (_failed)
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(BuIcons.videoOff, size: 28, color: t.onMedia),
                const SizedBox(height: 8),
                Text(l.postComposeVideoPlayFailed, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: t.onMedia)),
                TextButton(
                  onPressed: () {
                    _release();
                    setState(() => _failed = false);
                    _apply();
                  },
                  style: TextButton.styleFrom(minimumSize: const Size(BuSize.touch, BuSize.touch), foregroundColor: t.onMedia),
                  child: Text(l.postViewRetry),
                ),
              ]),
            )
          else if (!playing && widget.tap == PostVideoTap.playPause && _userPaused && !widget.flashIcon)
            // Reels'te kullanıcı duraklattıysa ortada sade oynat simgesi.
            Center(child: _Disc(icon: BuIcons.playFilled, size: 56, semantics: l.chatMiscPlayVideo)),
          if (widget.flashIcon)
            Center(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _flash,
                  builder: (_, __) {
                    // Önce görünür kalır, son %65'te solar; ikon yalnız animasyon sürerken çizilir.
                    if (!_flash.isAnimating) return const SizedBox.shrink();
                    final v = _flash.value;
                    final o = v < .35 ? 1.0 : (1 - (v - .35) / .65).clamp(0.0, 1.0);
                    return Opacity(
                      key: const ValueKey('postVideoFlash'),
                      opacity: o,
                      child: _Disc(icon: _flashPlay ? BuIcons.playFilled : BuIcons.pauseFilled, size: 56),
                    );
                  },
                ),
              ),
            ),
          if (widget.showProgress && ready)
            PositionedDirectional(start: 0, end: 0, bottom: widget.inset.bottom, child: _Progress(controller: c)),
          // Ses ve tam ekran düğmeleri (akış kartı bunları çift dokunuş sarmalayıcısının DIŞINDA kendisi çizer: aksi halde
          // dokunma çift dokunuş süresi (300 ms) kadar gecikir).
          if (widget.showControls) ...[
            PositionedDirectional(
              end: 6,
              top: widget.soundOnTop ? widget.inset.top + 6 : null,
              bottom: widget.soundOnTop ? null : widget.inset.bottom + 6,
              child: const PostVideoSoundButton(),
            ),
            if (widget.showFullscreen)
              PositionedDirectional(end: 6, top: 6, child: PostVideoFullscreenButton(session: widget.session, post: widget.post)),
          ],
          if (dur > 0 && !playing)
            PositionedDirectional(start: 10, bottom: widget.inset.bottom + 10, child: DurationChip(durationMs: dur)),
        ]),
      ),
    );
  }
}

/// Video üstünde ses aç/kapat düğmesi (sağ alt/üst köşe; 48 dp dokunma alanı). Tercih oturum boyunca ortaktır.
class PostVideoSoundButton extends StatelessWidget {
  const PostVideoSoundButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ValueListenableBuilder<bool>(
      valueListenable: postVideoMuted,
      builder: (_, muted, __) => Semantics(
        button: true,
        label: muted ? l.postComposeUnmute : l.postComposeMute,
        child: GestureDetector(
          key: const ValueKey('postVideoSound'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            buHaptic(BuHaptic.selection);
            postVideoMuted.value = !postVideoMuted.value;
          },
          child: SizedBox(
            width: BuSize.touch,
            height: BuSize.touch,
            child: Center(child: _Disc(icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, size: 32, iconSize: 18)),
          ),
        ),
      ),
    );
  }
}

/// "Tam ekran izle" düğmesi: sesli tam ekran oynatıcıyı açar (arkadaki küçük video üst rota açıkken kendiliğinden durur).
class PostVideoFullscreenButton extends StatelessWidget {
  const PostVideoFullscreenButton({super.key, required this.session, required this.post});

  final Session session;
  final Post post;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: context.l10n.kesFullscreen,
        child: GestureDetector(
          key: const ValueKey('postVideoFullscreen'),
          behavior: HitTestBehavior.opaque,
          onTap: () => openPostVideoViewer(context, session, post),
          child: const SizedBox(
            width: BuSize.touch,
            height: BuSize.touch,
            child: Center(child: _Disc(icon: Icons.fullscreen_rounded, size: 32, iconSize: 20)),
          ),
        ),
      );
}

/// Poster kare (yetkili görsel); yoksa düz zemin.
class _Poster extends StatelessWidget {
  const _Poster({required this.post, required this.session, required this.fit});

  final Post post;
  final Session session;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final url = post.video?.posterUrl;
    if (url == null) return const SizedBox.shrink();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final w = MediaQuery.sizeOf(context).width;
    return Image(
      image: persistentNetworkImage(url, headers: postAuthHeaders(session), cacheWidth: (w * dpr).ceil().clamp(320, 1080)),
      key: ValueKey('post-poster-${post.id}'),
      fit: fit,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}

/// Yarı saydam koyu daire içinde simge (video üstü denetimler; renkler tasarım belirteçlerinden).
class _Disc extends StatelessWidget {
  const _Disc({required this.icon, required this.size, this.iconSize, this.semantics});

  final IconData icon;
  final double size;
  final double? iconSize;
  final String? semantics;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final d = DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, color: t.scrim.withValues(alpha: .5)),
      child: SizedBox(width: size, height: size, child: Icon(icon, size: iconSize ?? size * .5, color: t.onMedia)),
    );
    return semantics == null ? ExcludeSemantics(child: d) : Semantics(label: semantics, child: d);
  }
}

/// Süre etiketi ("0:23"): video üstünde sol altta, yarı saydam koyu hap.
class DurationChip extends StatelessWidget {
  const DurationChip({super.key, required this.durationMs});

  final int durationMs;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return DecoratedBox(
      key: const ValueKey('videoDuration'),
      decoration: BoxDecoration(color: t.scrim.withValues(alpha: .55), borderRadius: BorderRadius.circular(BuRadius.pill)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(BuIcons.playFilled, size: 10, color: t.onMedia),
          const SizedBox(width: 4),
          Text(formatMediaDuration(durationMs),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: t.onMedia, fontSize: 11, fontWeight: FontWeight.w400, fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (_, v, __) {
        final total = v.duration.inMilliseconds;
        final f = total <= 0 ? 0.0 : (v.position.inMilliseconds / total).clamp(0.0, 1.0);
        return SizedBox(
          height: 3,
          child: Stack(children: [
            Positioned.fill(child: ColoredBox(color: t.onMedia.withValues(alpha: .25))),
            Positioned.fill(
              child: FractionallySizedBox(alignment: AlignmentDirectional.centerStart, widthFactor: f, child: ColoredBox(color: t.onMedia)),
            ),
          ]),
        );
      },
    );
  }
}
