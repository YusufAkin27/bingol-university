import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'like_button.dart';
import 'post_actions.dart';
import 'post_api.dart';
import 'post_card.dart';
import 'post_models.dart';

/// Bir kullanıcının gönderileri (imleçli sayfalama). [userId] null ya da kendi kimliğim ise `GET /posts/mine`.
class UserPostsPage extends StatefulWidget {
  const UserPostsPage({super.key, required this.session, this.userId, this.name});

  final Session session;
  final int? userId;
  final String? name;

  bool get isMine => userId == null || userId == session.userId;

  @override
  State<UserPostsPage> createState() => _UserPostsPageState();
}

class _UserPostsPageState extends State<UserPostsPage> {
  final _items = <Post>[];
  final _scroll = ScrollController();
  String? _cursor;
  bool _loading = true;
  bool _more = false;
  Object? _error;

  late final PostApi _api = PostApi(widget.session);

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

  Future<PostPage<Post>> _fetch(String? cursor) =>
      widget.isMine ? _api.minePosts(cursor: cursor) : _api.userPosts(widget.userId!, cursor: cursor);

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = _items.isEmpty);
    try {
      final r = await _fetch(null);
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
      final r = await _fetch(_cursor);
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
    if (i >= 0) setState(() => _items[i] = p);
  }

  void _deleted(int id) => setState(() => _items.removeWhere((e) => e.id == id));

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final title = widget.isMine ? 'Gönderilerim' : ((widget.name ?? '').isEmpty ? 'Gönderiler' : widget.name!);
    Widget body;
    if (_loading) {
      body = const LoadingView();
    } else if (_error != null && _items.isEmpty) {
      body = ErrorView(error: _error!, onRetry: _load);
    } else if (_items.isEmpty) {
      body = RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: ListView(children: const [
          SizedBox(height: 120),
          EmptyView(icon: LucideIcons.newspaper, text: 'Henüz gönderi yok'),
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
              key: ValueKey('upost-${p.id}'),
              session: widget.session,
              post: p,
              onChanged: _changed,
              onDeleted: _deleted,
              likeBuilder: (c, p, ch) => LikeButton(session: widget.session, post: p, onChanged: ch),
              menuBuilder: (c, p, ch, del) =>
                  PostMenuButton(session: widget.session, post: p, onChanged: ch, onDeleted: del),
            );
          },
        ),
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(title: title, onBack: () => Navigator.pop(context)),
        Expanded(child: body),
      ]),
    );
  }
}
