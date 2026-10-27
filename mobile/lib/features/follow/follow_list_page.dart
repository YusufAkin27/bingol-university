import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../posts/post_models.dart' show PostPage, postAuthHeaders;
import '../posts/social_api.dart';
import '../posts/social_models.dart';
import '../profile/user_profile_page.dart';
import 'follow_button.dart';

/// Takipçiler / Takip edilenler listesi (imleçli).
Future<void> openFollowList(BuildContext context, Session session,
        {required int userId, required bool followers, String? name}) =>
    Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
            builder: (_) => FollowListPage(session: session, userId: userId, followers: followers, name: name)));

class FollowListPage extends StatefulWidget {
  const FollowListPage({super.key, required this.session, required this.userId, required this.followers, this.name});

  final Session session;
  final int userId;
  final bool followers;
  final String? name;

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage> {
  final _items = <SocialUser>[];
  final _scroll = ScrollController();
  late final SocialApi _api = SocialApi(widget.session);
  String? _cursor;
  bool _loading = true;
  bool _more = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<PostPage<SocialUser>> _fetch(String? cursor) => widget.followers
      ? _api.followers(widget.userId, cursor: cursor)
      : _api.following(widget.userId, cursor: cursor);

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
        _items.addAll(r.items.where((e) => seen.add(e.id)));
        _cursor = r.hasMore ? r.nextCursor : null;
        _more = false;
      });
    } catch (_) {
      if (mounted) setState(() => _more = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final title = widget.followers ? 'Takipçiler' : 'Takip edilenler';
    Widget body;
    if (_loading) {
      body = const LoadingView();
    } else if (_error != null && _items.isEmpty) {
      body = ErrorView(error: _error!, onRetry: _load);
    } else if (_items.isEmpty) {
      body = ListView(children: [
        const SizedBox(height: 120),
        EmptyView(
            icon: LucideIcons.users,
            text: widget.followers ? 'Henüz takipçi yok.' : 'Henüz kimse takip edilmiyor.'),
      ]);
    } else {
      body = RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: ListView.builder(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.of(context).padding.bottom + 24),
          itemCount: _items.length + (_more ? 1 : 0),
          itemBuilder: (c, i) {
            if (i >= _items.length) {
              return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
            }
            return SocialUserTile(session: widget.session, user: _items[i]);
          },
        ),
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(
            title: title,
            subtitle: (widget.name ?? '').isEmpty ? null : widget.name,
            onBack: () => Navigator.pop(context)),
        Expanded(child: body),
      ]),
    );
  }
}

/// Kullanıcı satırı: avatar, ad, bölüm, (kendisi değilse) Takip düğmesi. Dokununca profil.
class SocialUserTile extends StatelessWidget {
  const SocialUserTile({super.key, required this.session, required this.user, this.trailing});

  final Session session;
  final SocialUser user;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final self = user.id == session.userId;
    return Semantics(
      container: true,
      label: user.displayName,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => openUserProfile(context, session,
            userId: user.id, name: user.displayName, avatarUrl: user.avatarUrl),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            BuAvatar(name: user.displayName, url: user.avatarUrl, size: 44, headers: postAuthHeaders(session)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user.displayName,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.bodyStrong.copyWith(color: t.ink)),
                if ((user.department ?? '').isNotEmpty)
                  Text(user.department!,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(color: t.mut)),
              ]),
            ),
            if (trailing != null)
              trailing!
            else if (!self)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: FollowButton(session: session, userId: user.id, followed: user.followedByMe),
              ),
          ]),
        ),
      ),
    );
  }
}
