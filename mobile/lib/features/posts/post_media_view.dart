import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../chat/message_bubble.dart' show PlayBadge, DurationPill;
import 'post_models.dart';
import 'video_autoplay.dart';

/// Gönderi medyası düzeni (akış kartı ve detay sayfası ortak):
/// 1 -> tam genişlik (oran korunur, 0.75-1.6), 2 -> yan yana kare, 3 -> büyük sol + iki küçük sağ,
/// 4 -> 2x2, 5-10 -> 3 sütun ızgara (ilk 6 hücre; fazlası son hücrede "+N").
///
/// Video hücresi: poster + oynat rozeti + süre hapı. [autoplay] açıksa ve tek öğe videoysa, akışta
/// görünür olduğunda sessiz otomatik oynar ([VideoAutoplayController]).
class PostMediaView extends StatelessWidget {
  const PostMediaView({
    super.key,
    required this.session,
    required this.media,
    required this.onOpen,
    this.autoplay = false,
    this.onDoubleTap,
    this.autoplayController,
    this.radius = 12,
  });

  final Session session;
  final List<PostMedia> media;

  /// Hücreye dokununca (galeri açılır): ilgili öğenin dizini.
  final void Function(int index) onOpen;

  /// Akışta tek video için sessiz otomatik oynatma.
  final bool autoplay;

  /// Çift dokunma (beğeni kalbi için); verilmezse çift dokunma algılanmaz.
  final VoidCallback? onDoubleTap;

  /// Testlerde özel denetleyici; verilmezse [VideoAutoplayController.instance].
  final VideoAutoplayController? autoplayController;
  final double radius;

  static const double gap = 2;
  static const int maxCells = 6;

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();
    final headers = postAuthHeaders(session);
    return LayoutBuilder(builder: (context, c) {
      final w = c.hasBoundedWidth ? c.maxWidth : MediaQuery.sizeOf(context).width;
      final body = _layout(context, w, headers);
      return ClipRRect(borderRadius: BorderRadius.circular(radius), child: SizedBox(width: w, child: body));
    });
  }

  Widget _cell(BuildContext context, int i, double w, double h, Map<String, String> headers,
      {int more = 0, bool single = false}) {
    return _MediaCell(
      key: ValueKey('postMediaCell$i'),
      media: media[i],
      width: w,
      height: h,
      headers: headers,
      more: more,
      autoplay: autoplay && single && media[i].isVideo,
      controller: autoplayController,
      onTap: () => onOpen(i),
      onDoubleTap: onDoubleTap,
      semanticLabel:
          '${media[i].isVideo ? 'Video' : 'Fotoğraf'} ${i + 1} / ${media.length}${more > 0 ? ', +$more daha' : ''}',
    );
  }

  Widget _layout(BuildContext context, double w, Map<String, String> headers) {
    final n = media.length;
    if (n == 1) {
      final ar = media[0].aspect.clamp(0.75, 1.6).toDouble();
      return _cell(context, 0, w, w / ar, headers, single: true);
    }
    if (n == 2) {
      final s = (w - gap) / 2;
      return Row(children: [
        _cell(context, 0, s, s, headers),
        const SizedBox(width: gap),
        _cell(context, 1, s, s, headers),
      ]);
    }
    if (n == 3) {
      final big = (w - gap) * 0.62;
      final small = w - gap - big;
      final h = big;
      final sh = (h - gap) / 2;
      return SizedBox(
        height: h,
        child: Row(children: [
          _cell(context, 0, big, h, headers),
          const SizedBox(width: gap),
          Column(children: [
            _cell(context, 1, small, sh, headers),
            const SizedBox(height: gap),
            _cell(context, 2, small, sh, headers),
          ]),
        ]),
      );
    }
    if (n == 4) {
      final s = (w - gap) / 2;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [_cell(context, 0, s, s, headers), const SizedBox(width: gap), _cell(context, 1, s, s, headers)]),
        const SizedBox(height: gap),
        Row(children: [_cell(context, 2, s, s, headers), const SizedBox(width: gap), _cell(context, 3, s, s, headers)]),
      ]);
    }
    // 5-10: 3 sütun, en çok 6 hücre.
    final s = (w - 2 * gap) / 3;
    final shown = math.min(n, maxCells);
    final rows = <Widget>[];
    for (var r = 0; r * 3 < shown; r++) {
      final cells = <Widget>[];
      for (var k = 0; k < 3; k++) {
        final i = r * 3 + k;
        if (k > 0) cells.add(const SizedBox(width: gap));
        if (i < shown) {
          final more = (i == maxCells - 1 && n > maxCells) ? n - maxCells : 0;
          cells.add(_cell(context, i, s, s, headers, more: more));
        } else {
          cells.add(SizedBox(width: s, height: s));
        }
      }
      if (r > 0) rows.add(const SizedBox(height: gap));
      rows.add(Row(children: cells));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

class _MediaCell extends StatelessWidget {
  const _MediaCell({
    super.key,
    required this.media,
    required this.width,
    required this.height,
    required this.headers,
    required this.onTap,
    required this.autoplay,
    this.onDoubleTap,
    this.controller,
    this.more = 0,
    this.semanticLabel,
  });

  final String? semanticLabel;
  final PostMedia media;
  final double width;
  final double height;
  final Map<String, String> headers;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final bool autoplay;
  final VideoAutoplayController? controller;
  final int more;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // Küçük resim çözünürlüğü hücre genişliğine göre; tek büyük görsel için tam adres daha net.
    final src = media.isVideo ? media.thumbUrl : (width > 300 ? media.url : (media.thumbUrl ?? media.url));
    final cw = (width * dpr).round().clamp(64, 1600);
    Widget poster = src == null
        ? _Placeholder(t: t, icon: LucideIcons.video)
        : Image.network(
            src,
            headers: headers,
            fit: BoxFit.cover,
            width: width,
            height: height,
            cacheWidth: cw,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, sync) =>
                (sync || frame != null) ? child : _Placeholder(key: const ValueKey('postMediaLoading'), t: t),
            errorBuilder: (context, e, s) =>
                _Placeholder(key: const ValueKey('postMediaError'), t: t, icon: LucideIcons.imageOff),
          );

    Widget stack;
    if (autoplay) {
      final ctrl = controller ?? VideoAutoplayController.instance;
      stack = ListenableBuilder(
        listenable: ctrl,
        builder: (context, _) {
          final playing = ctrl.readyControllerFor(media.id) != null;
          return Stack(fit: StackFit.expand, children: [
            AutoplayVideoSurface(
              videoKey: media.id,
              url: media.url,
              headers: headers,
              controller: controller,
              child: poster,
            ),
            if (!playing) ..._videoBadges(),
          ]);
        },
      );
    } else {
      stack = Stack(fit: StackFit.expand, children: [
        poster,
        if (media.isVideo) ..._videoBadges(),
      ]);
    }

    return RepaintBoundary(
      child: SizedBox(
        width: width,
        height: height,
        child: Semantics(
          button: true,
          label: semanticLabel ?? (media.isVideo ? 'Video' : 'Fotoğraf'),
          excludeSemantics: true,
          onTap: onTap,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            child: Stack(fit: StackFit.expand, children: [
              stack,
              if (more > 0)
                Positioned.fill(
                  child: Container(
                    key: const ValueKey('postMediaMore'),
                    color: Colors.black.withValues(alpha: .55),
                    alignment: Alignment.center,
                    child: Text('+$more',
                        style: BuType.title.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.clip),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  List<Widget> _videoBadges() => [
        Center(
          child: Semantics(
            button: true,
            label: 'Videoyu oynat',
            child: PlayBadge(size: math.min(46, math.max(28, math.min(width, height) * .3))),
          ),
        ),
        if (media.durationMs != null)
          PositionedDirectional(start: 6, bottom: 6, child: DurationPill(ms: media.durationMs!)),
      ];
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({super.key, required this.t, this.icon});

  final BuTokens t;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: t.sf2,
      alignment: Alignment.center,
      child: icon == null ? null : Icon(icon, color: t.mut, size: 24),
    );
  }
}
