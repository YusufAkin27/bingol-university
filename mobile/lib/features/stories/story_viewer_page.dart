import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/session.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart' show relativeTime;
import '../posts/post_models.dart' show postAuthHeaders;
import '../posts/social_api.dart';
import '../posts/social_models.dart';
import 'story_player.dart';
import 'story_viewers_sheet.dart';

/// `#RRGGBB` / `#AARRGGBB` -> renk; geçersizse [fallback].
Color storyColor(String? hex, {Color fallback = const Color(0xFF1E3A8A)}) {
  var h = (hex ?? '').replaceFirst('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final v = h.length == 8 ? int.tryParse(h, radix: 16) : null;
  return v == null ? fallback : Color(v);
}

/// Tam ekran hikâye görüntüleyici. [groups] sırayla gezilir; her grubun hikâyeleri `GET /users/{id}/stories`.
/// Dokunma: sol üçte bir geri, kalanı ileri; basılı tutma duraklatır; aşağı kaydırma kapatır.
class StoryViewerPage extends StatefulWidget {
  const StoryViewerPage({super.key, required this.session, required this.groups, this.initialGroup = 0});

  final Session session;
  final List<StoryGroup> groups;
  final int initialGroup;

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage> with SingleTickerProviderStateMixin {
  late final SocialApi _api = SocialApi(widget.session);
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;

  late int _g = widget.initialGroup.clamp(0, widget.groups.length - 1);
  int _gen = 0;
  List<Story>? _stories;
  Object? _error;
  StoryPlayer? _player;
  int _shownIndex = -1;
  VideoPlayerController? _video;
  final Set<int> _marked = {};
  bool _sheetOpen = false;

  StoryGroup get _group => widget.groups[_g];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _ticker.start();
    _loadGroup();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _player?.removeListener(_onPlayer);
    _player?.dispose();
    _video?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = elapsed - _last;
    _last = elapsed;
    // Uzun kare atlamaları (arka plan) hikâyeyi tek seferde bitirmesin.
    _player?.tick(dt > const Duration(milliseconds: 200) ? const Duration(milliseconds: 16) : dt);
  }

  Future<void> _loadGroup() async {
    final gen = ++_gen;
    _player?.removeListener(_onPlayer);
    _player?.dispose();
    _player = null;
    _disposeVideo();
    setState(() {
      _stories = null;
      _error = null;
      _shownIndex = -1;
    });
    try {
      final list = await _api.userStories(_group.userId);
      if (!mounted || gen != _gen) return;
      if (list.isEmpty) return _nextGroupOrClose();
      final start = _group.mine ? 0 : firstUnseenIndex(list);
      final player = StoryPlayer(
        durations: [for (final s in list) storyDuration(s)],
        index: start,
        onFinished: () => WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && gen == _gen) _nextGroupOrClose();
        }),
      )..addListener(_onPlayer);
      setState(() {
        _stories = list;
        _player = player;
      });
      _onPlayer();
    } catch (e) {
      if (mounted && gen == _gen) setState(() => _error = e);
    }
  }

  void _nextGroupOrClose() {
    if (_g + 1 < widget.groups.length) {
      _g++;
      _loadGroup();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _onPlayer() {
    final p = _player, list = _stories;
    if (p == null || list == null) return;
    if (p.index != _shownIndex && !p.finished) {
      _shownIndex = p.index;
      _enter(list[p.index], p);
    }
    _syncVideo();
    if (mounted) setState(() {});
  }

  /// Yeni hikâye gösterildi: görüldü işareti, video hazırlığı.
  void _enter(Story s, StoryPlayer p) {
    _disposeVideo();
    if (!_group.mine && !s.seen && _marked.add(s.id)) {
      unawaited(_api.markViewed(s.id).catchError((_) {}));
    }
    if (s.kind == StoryKind.video && s.media != null) {
      p.hold(true);
      final c = VideoPlayerController.networkUrl(Uri.parse(s.media!.url), httpHeaders: postAuthHeaders(widget.session));
      _video = c;
      final idx = p.index;
      c.initialize().then((_) {
        if (!mounted || _video != c) return;
        p.setDuration(idx, storyDuration(s, videoOverride: c.value.duration));
        p.hold(false);
        c.setLooping(false);
        if (p.running) c.play();
        setState(() {});
      }).catchError((_) {
        if (mounted && _video == c) p.hold(false);
      });
    } else if (s.kind == StoryKind.image) {
      p.hold(true); // görsel çizilince bırakılır
    } else {
      p.hold(false);
    }
  }

  void _disposeVideo() {
    final v = _video;
    _video = null;
    v?.dispose();
  }

  void _syncVideo() {
    final v = _video, p = _player;
    if (v == null || p == null || !v.value.isInitialized) return;
    if (p.running && !v.value.isPlaying) {
      v.play();
    } else if (!p.running && v.value.isPlaying) {
      v.pause();
    }
  }

  void _imageReady() {
    final p = _player;
    if (p == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _player == p) p.hold(false);
    });
  }

  Future<void> _showViewers(Story s) async {
    final p = _player;
    if (p == null || _sheetOpen) return;
    _sheetOpen = true;
    p.pause();
    await showStoryViewersSheet(context, widget.session, s);
    _sheetOpen = false;
    if (mounted) p.resume();
  }

  Future<void> _delete(Story s) async {
    final p = _player;
    p?.pause();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hikâye silinsin mi?'),
        content: const Text('Bu işlem geri alınamaz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true || !mounted) {
      p?.resume();
      return;
    }
    try {
      await _api.deleteStory(s.id);
      if (!mounted) return;
      final rest = [for (final x in _stories!) if (x.id != s.id) x];
      if (rest.isEmpty) {
        Navigator.of(context).maybePop();
      } else {
        // Kalanlarla yeniden başlat (basit ve tutarlı).
        _stories = rest;
        _loadAfterDelete(rest);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
      p?.resume();
    }
  }

  void _loadAfterDelete(List<Story> rest) {
    _player?.removeListener(_onPlayer);
    _player?.dispose();
    _disposeVideo();
    final gen = ++_gen;
    final player = StoryPlayer(
      durations: [for (final s in rest) storyDuration(s)],
      onFinished: () => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && gen == _gen) _nextGroupOrClose();
      }),
    )..addListener(_onPlayer);
    setState(() {
      _player = player;
      _shownIndex = -1;
    });
    _onPlayer();
  }

  void _tap(TapUpDetails d, double width) {
    final p = _player;
    if (p == null) return;
    // RTL'de "geri" sağ kenardadır.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final left = d.localPosition.dx < width / 3;
    final back = rtl ? d.localPosition.dx > width * 2 / 3 : left;
    if (back) {
      p.previous();
    } else {
      p.next();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _player, list = _stories;
    Widget body;
    if (_error != null && list == null) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(errorText(_error!), style: BuType.body.copyWith(color: Colors.white), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          BuButton(label: 'Yeniden dene', compact: true, kind: BuButtonKind.outline, onPressed: _loadGroup),
        ]),
      );
    } else if (p == null || list == null) {
      body = const Center(child: CircularProgressIndicator(color: Colors.white));
    } else {
      body = _stage(p, list[p.finished ? list.length - 1 : p.index], list);
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: [
          Positioned.fill(child: body),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              key: const ValueKey('storyClose'),
              tooltip: 'Kapat',
              icon: const Icon(LucideIcons.x, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _stage(StoryPlayer p, Story s, List<Story> list) {
    return LayoutBuilder(builder: (context, c) {
      return GestureDetector(
        key: const ValueKey('storyStage'),
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => _tap(d, c.maxWidth),
        onLongPressStart: (_) => p.pause(),
        onLongPressEnd: (_) {
          if (!_sheetOpen) p.resume();
        },
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 300) Navigator.of(context).maybePop();
        },
        child: Stack(fit: StackFit.expand, children: [
          _content(s),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black54, Colors.transparent]),
                ),
              ),
            ),
          ),
          Positioned(
            top: 6,
            left: 8,
            right: 52,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _bars(p, list.length),
              const SizedBox(height: 8),
              _header(s),
            ]),
          ),
          if ((s.caption ?? '').isNotEmpty && s.kind != StoryKind.text)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(20, 40, 20, _group.mine ? 64 : 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]),
                ),
                child: Text(s.caption!, textAlign: TextAlign.center, style: BuType.body.copyWith(color: Colors.white)),
              ),
            ),
          if (_group.mine)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Row(children: [
                Semantics(
                  button: true,
                  label: '${s.viewCount} görüntülenme, izleyenleri göster',
                  excludeSemantics: true,
                  child: InkWell(
                    key: const ValueKey('storyViewers'),
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _showViewers(s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(children: [
                        const Icon(LucideIcons.eye, size: 20, color: Colors.white),
                        const SizedBox(width: 6),
                        Text('${s.viewCount}', style: BuType.label.copyWith(color: Colors.white)),
                      ]),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  key: const ValueKey('storyDelete'),
                  tooltip: 'Hikâyeyi sil',
                  icon: const Icon(LucideIcons.trash2, color: Colors.white),
                  onPressed: () => _delete(s),
                ),
              ]),
            ),
        ]),
      );
    });
  }

  Widget _bars(StoryPlayer p, int n) {
    return Semantics(
      label: 'Hikâye ${p.index + 1} / $n',
      child: Row(children: [
        for (var i = 0; i < n; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: p.fillOf(i),
                minHeight: 3,
                backgroundColor: Colors.white30,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _header(Story s) {
    return Row(children: [
      BuAvatar(
          name: _group.displayName, url: _group.avatarUrl, size: 34, headers: postAuthHeaders(widget.session)),
      const SizedBox(width: 10),
      Flexible(
        child: Text(_group.mine ? 'Hikâyen' : _group.displayName,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.bodyStrong.copyWith(color: Colors.white)),
      ),
      const SizedBox(width: 8),
      Text(relativeTime(s.createdAt), style: BuType.caption.copyWith(color: Colors.white70)),
    ]);
  }

  Widget _content(Story s) {
    switch (s.kind) {
      case StoryKind.text:
        return Container(
          color: storyColor(s.background),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(s.bodyText ?? '',
              key: const ValueKey('storyText'),
              textAlign: TextAlign.center,
              style: BuType.title.copyWith(color: Colors.white, fontSize: 26, height: 1.3)),
        );
      case StoryKind.video:
        final v = _video;
        if (v != null && v.value.isInitialized) {
          return Center(child: AspectRatio(aspectRatio: v.value.aspectRatio, child: VideoPlayer(v)));
        }
        return const Center(child: CircularProgressIndicator(color: Colors.white));
      case StoryKind.image:
        final m = s.media;
        if (m == null) return const SizedBox.shrink();
        return Image.network(
          m.url,
          key: ValueKey('storyImage-${s.id}'),
          headers: postAuthHeaders(widget.session),
          fit: BoxFit.contain,
          frameBuilder: (c, child, frame, sync) {
            if (frame != null || sync) _imageReady();
            return child;
          },
          errorBuilder: (c, e, st) {
            _imageReady();
            return const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48));
          },
        );
    }
  }
}
