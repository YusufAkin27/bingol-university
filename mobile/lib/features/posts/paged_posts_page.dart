import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'like_button.dart';
import 'post_actions.dart';
import 'post_card.dart';
import 'post_media_gallery.dart';
import 'post_media_view.dart';
import 'post_models.dart';

/// İmleçli gönderi listesi sayfası (Kaydedilenler, #etiket akışı). [fetch] bir sayfa getirir.
/// [removeWhenUnsaved] true iken yer imi kaldırılan gönderi listeden düşer.
class PagedPostsPage extends StatefulWidget {
  const PagedPostsPage({
    super.key,
    required this.session,
    required this.title,
    required this.fetch,
    required this.emptyText,
    this.emptyIcon = LucideIcons.newspaper,
    this.removeWhenUnsaved = false,
    this.header,
  });

  final Session session;
  final String title;
  final Future<PostPage<Post>> Function(String? cursor) fetch;
  final String emptyText;
  final IconData emptyIcon;
  final bool removeWhenUnsaved;

  /// Listenin üstünde gösterilen ek parça (örn. gönderi sayısı).
  final Widget? header;

  @override
  State<PagedPostsPage> createState() => _PagedPostsPageState();
}

class _PagedPostsPageState extends State<PagedPostsPage> {
  final _items = <Post>[];
  final _scroll = ScrollController();
  String? _cursor;
  bool _loading = true;
  bool _more = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) _loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = _items.isEmpty);
    try {
      final r = await widget.fetch(null);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(r.items);
        _cursor = r.hasMore ? r.nextCursor : null;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_cursor == null || _more || _loading) return;
    setState(() => _more = true);
    try {
      final r = await widget.fetch(_cursor);
      if (!mounted) return;
      setState(() {
        final seen = _items.map((e) => e.id).toSet();
        _items.addAll(r.items.where((e) => !seen.contains(e.id)));
        _cursor = r.hasMore ? r.nextCursor : null;
        _more = false;
      });
    } catch (_) {
      if (mounted) setState(() => _more = false);
    }
  }

  void _changed(Post p) {
    final i = _items.indexWhere((e) => e.id == p.id);
    if (i < 0) return;
    setState(() {
      if (widget.removeWhenUnsaved && !p.savedByMe) {
        _items.removeAt(i);
      } else {
        _items[i] = p;
      }
    });
  }

  void _deleted(int id) => setState(() => _items.removeWhere((e) => e.id == id));

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    Widget body;
    if (_loading) {
      body = const LoadingView();
    } else if (_error != null && _items.isEmpty) {
      body = ErrorView(error: _error!, onRetry: _load);
    } else if (_items.isEmpty) {
      body = RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: ListView(children: [
          const SizedBox(height: 120),
          EmptyView(icon: widget.emptyIcon, text: widget.emptyText),
        ]),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: ListView.separated(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 24),
          itemCount: _items.length + (_more ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (c, i) {
            if (i >= _items.length) {
              return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
            }
            final p = _items[i];
            return PostCard(
              key: ValueKey('ppost-${p.id}'),
              session: widget.session,
              post: p,
              onChanged: _changed,
              onDeleted: _deleted,
              likeBuilder: (c, p, ch) => LikeButton(session: widget.session, post: p, onChanged: ch),
              menuBuilder: (c, p, ch, del) =>
                  PostMenuButton(session: widget.session, post: p, onChanged: ch, onDeleted: del),
              mediaBuilder: (c, p) => PostMediaView(
                session: widget.session,
                media: p.media,
                autoplay: true,
                onOpen: (i) => openPostMediaGallery(c, widget.session, p.media, i),
              ),
            );
          },
        ),
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(title: widget.title, onBack: () => Navigator.pop(context)),
        if (widget.header != null) widget.header!,
        Expanded(child: body),
      ]),
    );
  }
}
