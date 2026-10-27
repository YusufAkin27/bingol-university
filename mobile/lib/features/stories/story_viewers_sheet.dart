import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../posts/post_models.dart' show postAuthHeaders;
import '../posts/social_api.dart';
import '../posts/social_models.dart';

/// Kendi hikâyeni izleyenlerin listesi (`GET /stories/{id}/viewers`).
Future<void> showStoryViewersSheet(BuildContext context, Session session, Story story) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ViewersSheet(session: session, story: story),
    );

class _ViewersSheet extends StatefulWidget {
  const _ViewersSheet({required this.session, required this.story});

  final Session session;
  final Story story;

  @override
  State<_ViewersSheet> createState() => _ViewersSheetState();
}

class _ViewersSheetState extends State<_ViewersSheet> {
  List<SocialUser>? _items;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await SocialApi(widget.session).viewers(widget.story.id);
      if (mounted) setState(() => _items = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final h = MediaQuery.sizeOf(context).height * .6;
    final items = _items;
    Widget body;
    if (_error != null && items == null) {
      body = ErrorView(error: _error!, onRetry: _load);
    } else if (items == null) {
      body = const LoadingView();
    } else if (items.isEmpty) {
      body = const EmptyView(icon: LucideIcons.eye, text: 'Henüz kimse görüntülemedi.');
    } else {
      body = ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final u = items[i];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              BuAvatar(name: u.displayName, url: u.avatarUrl, size: 40, headers: postAuthHeaders(widget.session)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(u.displayName,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.bodyStrong.copyWith(color: t.ink)),
              ),
              if (u.at != null) Text(relativeTime(u.at), style: BuType.caption.copyWith(color: t.mut)),
            ]),
          );
        },
      );
    }
    return SizedBox(
      height: h,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text('Görüntüleyenler (${widget.story.viewCount})', style: BuType.heading.copyWith(color: t.ink)),
          ),
        ),
        Expanded(child: body),
      ]),
    );
  }
}
