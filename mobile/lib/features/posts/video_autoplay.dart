import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

/// Akış tercihleri (ileride Ayarlar'a bağlanır). Mobil veri tespiti yapılmaz: yalnız bu bayrağa bakılır.
class PostPrefs {
  const PostPrefs._();

  /// Akışta görünür videonun sessiz otomatik oynatılması.
  static bool autoplay = true;
}

/// Oynatıcı üretici (testlerde sahte platform ya da özel denetleyici verilebilir).
typedef AutoplayFactory = VideoPlayerController Function(Uri uri, Map<String, String> headers);

VideoPlayerController _defaultFactory(Uri uri, Map<String, String> headers) => VideoPlayerController.networkUrl(
      uri,
      httpHeaders: headers,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

class _Candidate {
  _Candidate(this.uri, this.headers);
  Uri uri;
  Map<String, String> headers;
  double fraction = 0;
  double distance = double.infinity;
  bool enabled = true;
  bool scrolling = false;
}

class _Entry {
  _Entry(this.controller);
  final VideoPlayerController controller;
  bool initialized = false;
  bool failed = false;
  bool disposed = false;
}

/// Akıştaki görünür TEK videoyu sessiz oynatan denetleyici.
///
/// Hücreler [report] ile görünürlük (kesir) ve ekran ortasına uzaklık bildirir; ekran ortasına en yakın
/// ve en az %60 görünen video oynar, diğerleri durur. Kaydırma sürerken, sekme/rota görünmezken ya da
/// uygulama arka plandayken oynatma durur. Bellekte en çok [maxControllers] denetleyici tutulur.
class VideoAutoplayController extends ChangeNotifier with WidgetsBindingObserver {
  VideoAutoplayController({AutoplayFactory? factory, this.maxControllers = 2, bool observeLifecycle = true})
      : factory = factory ?? _defaultFactory {
    if (observeLifecycle) {
      WidgetsFlutterBinding.ensureInitialized();
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
  }

  /// Uygulama geneli örnek.
  static final VideoAutoplayController instance = VideoAutoplayController();

  /// En az bu kesirde görünen video oynayabilir.
  static const double minVisible = 0.6;

  AutoplayFactory factory;
  final int maxControllers;
  bool _observing = false;
  bool _disposed = false;

  final Map<Object, _Candidate> _cands = {};
  // Ekleme sırası = en eski kullanım (LRU).
  final Map<Object, _Entry> _entries = {};
  Object? _active;
  bool _suspended = false;
  bool _scheduled = false;

  /// Ses kapalı (varsayılan). Tüm videolar için ortak.
  bool get muted => _muted;
  bool _muted = true;

  /// Şu an oynatmak üzere seçilen anahtar (başlatma sürerken de dolu).
  Object? get activeKey => _active;

  /// Bellekteki denetleyici sayısı.
  int get controllerCount => _entries.length;

  /// Anahtar için hazır (başlatılmış) denetleyici; yalnız etkin video için döner.
  VideoPlayerController? readyControllerFor(Object key) {
    if (_active != key) return null;
    final e = _entries[key];
    return (e != null && e.initialized && !e.failed && !e.disposed) ? e.controller : null;
  }

  /// Hücre bildirimi. [enabled] false ise (sekme/rota görünmez, ayar kapalı) aday oynamaz.
  void report(
    Object key, {
    required Uri uri,
    required Map<String, String> headers,
    required double visibleFraction,
    required double centerDistance,
    bool scrolling = false,
    bool enabled = true,
  }) {
    if (_disposed) return;
    final c = _cands.putIfAbsent(key, () => _Candidate(uri, headers));
    c
      ..uri = uri
      ..headers = headers
      ..fraction = visibleFraction
      ..distance = centerDistance
      ..scrolling = scrolling
      ..enabled = enabled;
    _schedule();
  }

  /// Hücre ağaçtan kalktı.
  void unregister(Object key) {
    if (_cands.remove(key) == null) return;
    if (_active == key) {
      _activate(null);
    }
    _schedule();
  }

  void setMuted(bool value) {
    if (_muted == value) return;
    _muted = value;
    final key = _active;
    final e = key == null ? null : _entries[key];
    if (e != null && e.initialized && !e.disposed) {
      unawaited(e.controller.setVolume(value ? 0 : 1).catchError((_) {}));
    }
    notifyListeners();
  }

  void toggleMuted() => setMuted(!_muted);

  /// Uygulama arka plana gidince / dışarıdan: tüm oynatmayı durdurur.
  void suspend() {
    if (_suspended) return;
    _suspended = true;
    _activate(null);
  }

  void resume() {
    if (!_suspended) return;
    _suspended = false;
    _schedule();
  }

  /// Tüm denetleyicileri bırakır (aday kayıtları kalır).
  void releaseAll() {
    _activate(null);
    for (final e in _entries.values) {
      _disposeEntry(e);
    }
    _entries.clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      resume();
    } else {
      suspend();
    }
  }

  void _schedule() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      if (!_disposed) _evaluate();
    });
  }

  void _evaluate() {
    Object? best;
    var bestDist = double.infinity;
    if (!_suspended && PostPrefs.autoplay) {
      _cands.forEach((k, c) {
        if (!c.enabled || c.scrolling || c.fraction < minVisible) return;
        // Eşitlikte mevcut etkin video korunur (titremeyi önler).
        if (c.distance < bestDist || (c.distance == bestDist && k == _active)) {
          best = k;
          bestDist = c.distance;
        }
      });
    }
    // Etkin video hâlâ uygunsa ve rakip yalnız çok az yakınsa değiştirme.
    _activate(best);
  }

  void _activate(Object? key) {
    if (key == _active) return;
    final old = _active;
    if (old != null) {
      final oe = _entries[old];
      if (oe != null && oe.initialized && !oe.disposed) {
        unawaited(oe.controller.pause().catchError((_) {}));
      }
    }
    _active = key;
    if (key != null) {
      final cand = _cands[key];
      if (cand != null) _start(key, cand);
    }
    notifyListeners();
  }

  void _start(Object key, _Candidate cand) {
    var e = _entries.remove(key);
    if (e == null) {
      e = _Entry(factory(cand.uri, cand.headers));
      final entry = e;
      unawaited(() async {
        try {
          await entry.controller.initialize();
          if (entry.disposed) return;
          await entry.controller.setLooping(true);
          await entry.controller.setVolume(_muted ? 0 : 1);
          entry.initialized = true;
          if (_active == key && !_suspended && !entry.disposed) {
            await entry.controller.play();
          }
        } catch (_) {
          entry.failed = true;
        }
        if (!_disposed && !entry.disposed) notifyListeners();
      }());
    } else if (e.initialized && !e.failed) {
      final entry = e;
      unawaited(entry.controller.play().catchError((_) {}));
    }
    _entries[key] = e; // en son kullanılan sona
    while (_entries.length > maxControllers) {
      final victim = _entries.keys.firstWhere((k) => k != _active, orElse: () => _entries.keys.first);
      _disposeEntry(_entries.remove(victim)!);
    }
  }

  void _disposeEntry(_Entry e) {
    if (e.disposed) return;
    e.disposed = true;
    try {
      unawaited(e.controller.dispose().catchError((_) {}));
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    for (final e in _entries.values) {
      _disposeEntry(e);
    }
    _entries.clear();
    _cands.clear();
    _active = null;
    super.dispose();
  }
}

/// Akıştaki bir video hücresinin üstüne konan katman: görünürlüğü [VideoAutoplayController]'a bildirir,
/// etkin olduğunda sessiz videoyu poster ([child]) üzerinde çizer ve ses aç/kapat düğmesi gösterir.
class AutoplayVideoSurface extends StatefulWidget {
  const AutoplayVideoSurface({
    super.key,
    required this.videoKey,
    required this.url,
    required this.headers,
    required this.child,
    this.controller,
    this.enabled = true,
  });

  final Object videoKey;
  final String url;
  final Map<String, String> headers;

  /// Poster/arka plan.
  final Widget child;

  /// Verilmezse [VideoAutoplayController.instance].
  final VideoAutoplayController? controller;
  final bool enabled;

  @override
  State<AutoplayVideoSurface> createState() => _AutoplayVideoSurfaceState();
}

class _AutoplayVideoSurfaceState extends State<AutoplayVideoSurface> {
  ScrollPosition? _pos;
  bool _scrolling = false;
  bool _queued = false;

  VideoAutoplayController get _c => widget.controller ?? VideoAutoplayController.instance;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = Scrollable.maybeOf(context)?.position;
    if (!identical(p, _pos)) {
      _pos?.removeListener(_onScroll);
      _pos?.isScrollingNotifier.removeListener(_onScroll);
      _pos = p;
      _pos?.addListener(_onScroll);
      _pos?.isScrollingNotifier.addListener(_onScroll);
    }
    _queue();
  }

  @override
  void didUpdateWidget(covariant AutoplayVideoSurface old) {
    super.didUpdateWidget(old);
    if (old.videoKey != widget.videoKey) {
      (old.controller ?? VideoAutoplayController.instance).unregister(old.videoKey);
    }
    _queue();
  }

  void _onScroll() {
    _scrolling = _pos?.isScrollingNotifier.value ?? false;
    _report();
  }

  void _queue() {
    if (_queued) return;
    _queued = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (mounted) _report();
    });
  }

  void _report() {
    if (!mounted) return;
    final ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return;
    final cell = ro.localToGlobal(Offset.zero) & ro.size;
    Rect viewport;
    final sro = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (sro is RenderBox && sro.attached && sro.hasSize) {
      viewport = sro.localToGlobal(Offset.zero) & sro.size;
    } else {
      viewport = Offset.zero & MediaQuery.sizeOf(context);
    }
    final inter = cell.intersect(viewport);
    final area = cell.width * cell.height;
    final fraction = (inter.isEmpty || area <= 0) ? 0.0 : (inter.width * inter.height) / area;
    final visible = TickerMode.valuesOf(context).enabled && (ModalRoute.of(context)?.isCurrent ?? true);
    _c.report(
      widget.videoKey,
      uri: Uri.parse(widget.url),
      headers: widget.headers,
      visibleFraction: fraction,
      centerDistance: (cell.center.dy - viewport.center.dy).abs(),
      scrolling: _scrolling,
      enabled: widget.enabled && visible && PostPrefs.autoplay,
    );
  }

  @override
  void dispose() {
    _pos?.removeListener(_onScroll);
    _pos?.isScrollingNotifier.removeListener(_onScroll);
    _c.unregister(widget.videoKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Yerleşim değişirse (liste yeniden kuruldu) bir sonraki karede yeniden bildir.
    _queue();
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final vc = _c.readyControllerFor(widget.videoKey);
        return Stack(fit: StackFit.expand, children: [
          widget.child,
          if (vc != null)
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: vc,
              builder: (context, v, _) {
                // İlk kare gelmeden poster görünür kalır.
                if (!v.isInitialized || v.size.isEmpty) return const SizedBox.shrink();
                return ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      key: const ValueKey('autoplayVideo'),
                      width: v.size.width,
                      height: v.size.height,
                      child: VideoPlayer(vc),
                    ),
                  ),
                );
              },
            ),
          if (vc != null)
            PositionedDirectional(
              end: 8,
              bottom: 8,
              child: Semantics(
                button: true,
                label: _c.muted ? 'Sesi aç' : 'Sesi kapat',
                child: GestureDetector(
                  key: const ValueKey('autoplayMute'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _c.toggleMuted,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: .5), shape: BoxShape.circle),
                    child: Icon(_c.muted ? LucideIcons.volumeX : LucideIcons.volume2, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
        ]);
      },
    );
  }
}
