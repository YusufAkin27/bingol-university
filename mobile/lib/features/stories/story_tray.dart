import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../posts/post_models.dart' show postAuthHeaders;
import '../posts/social_api.dart';
import '../posts/social_models.dart';
import 'story_create_page.dart';
import 'story_viewer_page.dart';

/// Dışarıdan şeridi tazelemek için.
class StoryTrayController {
  _StoryTrayState? _state;

  Future<void> refresh() async => _state?._load();
}

/// Keşfet üstündeki hikâye şeridi (`GET /stories/tray`). İlk balon kendi hikâyen; görülmemiş hikâyeler renkli halkalı.
/// Şerit yüklenemezse yalnız "Hikâyen" balonu kalır (akış çalışmaya devam eder).
class StoryTray extends StatefulWidget {
  const StoryTray({super.key, required this.session, this.controller});

  final Session session;
  final StoryTrayController? controller;

  @override
  State<StoryTray> createState() => _StoryTrayState();
}

class _StoryTrayState extends State<StoryTray> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<StoryGroup>? _groups;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _load();
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller!._state = null;
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final g = await SocialApi(widget.session).tray();
      if (mounted) setState(() => _groups = g);
    } catch (_) {
      if (mounted) setState(() => _groups ??= const []);
    }
  }

  Future<void> _create() async {
    final ok = await Navigator.push<bool>(
        context, MaterialPageRoute<bool>(builder: (_) => StoryCreatePage(session: widget.session)));
    if (ok == true) _load();
  }

  Future<void> _open(List<StoryGroup> all, StoryGroup g) async {
    await Navigator.push<void>(
      context,
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) =>
            StoryViewerPage(session: widget.session, groups: all, initialGroup: all.indexOf(g)),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final groups = _groups;
    if (groups == null) return const _TraySkeleton();
    final mine = groups.where((g) => g.mine).toList();
    final others = groups.where((g) => !g.mine).toList();
    final viewable = [...mine, ...others];
    return SizedBox(
      key: const ValueKey('storyTray'),
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Bubble(
            session: widget.session,
            label: 'Hikâyen',
            name: widget.session.displayName,
            url: mine.isEmpty ? null : mine.first.avatarUrl,
            ring: mine.isNotEmpty ? (mine.first.hasUnseen ? _Ring.unseen : _Ring.seen) : _Ring.none,
            plus: true,
            onTap: mine.isEmpty ? _create : () => _open(viewable, mine.first),
            onPlus: _create,
          ),
          for (final g in others)
            _Bubble(
              session: widget.session,
              label: g.displayName,
              name: g.displayName,
              url: g.avatarUrl,
              ring: g.hasUnseen ? _Ring.unseen : _Ring.seen,
              onTap: () => _open(viewable, g),
            ),
        ],
      ),
    );
  }
}

enum _Ring { none, seen, unseen }

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.session,
    required this.label,
    required this.name,
    required this.url,
    required this.ring,
    required this.onTap,
    this.plus = false,
    this.onPlus,
  });

  final Session session;
  final String label;
  final String? name;
  final String? url;
  final _Ring ring;
  final VoidCallback onTap;
  final bool plus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final unseen = ring == _Ring.unseen;
    return Semantics(
      button: true,
      label: plus ? 'Hikâyen' : (unseen ? '$label, yeni hikâye' : '$label, hikâye'),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 72,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: ring == _Ring.none ? null : Border.all(color: unseen ? t.pr : t.bd, width: unseen ? 2.5 : 1.5),
                ),
                child: BuAvatar(name: name, url: url, size: 56, headers: postAuthHeaders(session)),
              ),
              if (plus)
                PositionedDirectional(
                  end: -2,
                  bottom: -2,
                  child: GestureDetector(
                    key: const ValueKey('storyAdd'),
                    onTap: onPlus,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle, border: Border.all(color: t.bg, width: 2)),
                      child: Icon(LucideIcons.plus, size: 13, color: t.onPr),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 4),
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3, // şerit yüksekliği sabit (96 dp)
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: BuType.caption.copyWith(color: t.ink)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _TraySkeleton extends StatelessWidget {
  const _TraySkeleton();

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (var i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 4),
              child: Column(children: [
                Container(width: 60, height: 60, decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle)),
                const SizedBox(height: 8),
                Container(width: 44, height: 8, decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(4))),
              ]),
            ),
        ],
      ),
    );
  }
}
