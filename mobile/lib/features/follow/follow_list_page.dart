import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../posts/post_models.dart' show PostPage, postAuthHeaders;
import '../posts/social_models.dart';
import '../profile/user_profile_page.dart';
import '../profile/profil_widgets.dart' show ProfilCard;
import '../profile/profily_widgets.dart';
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

/// Bir sekmenin (takipçiler / takip edilenler) sayfalı durumu.
class _Tab {
  final items = <SocialUser>[];
  final followsMe = <int, bool>{}; // yalnız API alanı gelirse dolar
  String? cursor;
  int? total;
  bool loading = false;
  bool loaded = false;
  bool more = false;
  Object? error;
  int gen = 0;
}

class _FollowListPageState extends State<FollowListPage> {
  final _tabs = [_Tab(), _Tab()];
  final _scroll = ScrollController();
  final _search = TextEditingController();
  late int _tab = widget.followers ? 0 : 1;
  String _query = '';

  _Tab get _cur => _tabs[_tab];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _load(_tab);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<PostPage<SocialUser>> _fetch(int tab, String? cursor, _Tab st) async {
    final path = tab == 0 ? 'followers' : 'following';
    final q = 'size=30${cursor == null ? '' : '&cursor=${Uri.encodeQueryComponent(cursor)}'}';
    final res = await widget.session.api.get('/users/${widget.userId}/$path?$q');
    final page = PostPage.parse(res, SocialUser.fromJson);
    // `followsMe` henüz her sürümde yok: yalnız alan varsa ve bool ise kaydedilir.
    if (res is Map && res['items'] is List) {
      for (final e in (res['items'] as List).whereType<Map>()) {
        final id = e['id'] ?? e['userId'];
        final v = e['followsMe'];
        if (id is num && v is bool) st.followsMe[id.toInt()] = v;
      }
    }
    return page;
  }

  Future<void> _load(int tab, {bool silent = false}) async {
    final st = _tabs[tab];
    final gen = ++st.gen;
    if (!silent) setState(() => st.loading = st.items.isEmpty);
    try {
      final r = await _fetch(tab, null, st);
      if (!mounted || gen != st.gen) return;
      setState(() {
        st.items
          ..clear()
          ..addAll(r.items);
        st.cursor = r.hasMore ? r.nextCursor : null;
        st.total = r.total;
        st.error = null;
        st.loading = false;
        st.loaded = true;
      });
    } catch (e) {
      if (!mounted || gen != st.gen) return;
      setState(() {
        st.error = e;
        st.loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final st = _cur;
    final tab = _tab;
    if (st.cursor == null || st.more || st.loading) return;
    setState(() => st.more = true);
    try {
      final r = await _fetch(tab, st.cursor, st);
      if (!mounted) return;
      setState(() {
        final seen = st.items.map((e) => e.id).toSet();
        st.items.addAll(r.items.where((e) => seen.add(e.id)));
        st.cursor = r.hasMore ? r.nextCursor : null;
        st.more = false;
      });
    } catch (_) {
      if (mounted) setState(() => st.more = false);
    }
  }

  void _switch(int i) {
    if (i == _tab) return;
    setState(() {
      _tab = i;
      _search.clear();
      _query = '';
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (!_tabs[i].loaded) _load(i);
  }

  String _label(int i) {
    final l = context.l10n;
    final total = _tabs[i].total;
    if (total == null) return i == 0 ? l.followersTitle : l.followingTitle;
    return i == 0 ? l.profilyardFollowersTab('$total') : l.profilyardFollowingTab('$total');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final st = _cur;
    final name = (widget.name ?? '').trim();
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? st.items
        : st.items.where((u) => '${u.displayName} ${u.department ?? ''}'.toLowerCase().contains(q)).toList();
    Widget body;
    if (st.loading) {
      body = const LoadingView();
    } else if (st.error != null && st.items.isEmpty) {
      body = ErrorView(error: st.error!, onRetry: () => _load(_tab));
    } else if (st.items.isEmpty) {
      body = ListView(children: [
        const SizedBox(height: 120),
        EmptyView(icon: LucideIcons.users, text: _tab == 0 ? l.followersEmpty : l.followingEmpty),
      ]);
    } else {
      body = RefreshIndicator(
        onRefresh: () => _load(_tab, silent: true),
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 24),
          children: [
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text(l.profilyardFollowNoMatch, style: BuType.body.copyWith(color: t.mut))),
              )
            else
              ProfilCard(children: [for (final u in shown) _row(u, st)]),
            if (st.more) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(
          title: name.isEmpty ? (widget.followers ? l.followersTitle : l.followingTitle) : name,
          onBack: () => Navigator.pop(context),
        ),
        const SizedBox(height: 8),
        ProfilyTabs(labels: [_label(0), _label(1)], index: _tab, onChanged: _switch),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: ProfilySearchField(
            controller: _search,
            hint: l.commonSearchHint,
            label: _tab == 0 ? l.profilyardFollowersSearch : l.profilyardFollowingSearch,
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(child: body),
      ]),
    );
  }

  Widget _row(SocialUser u, _Tab st) {
    final l = context.l10n;
    final self = u.id == widget.session.userId;
    final fm = st.followsMe[u.id];
    final Widget? pill = fm == null
        ? null
        : (fm && u.followedByMe
            ? ProfilyPill(l.profilyardFollowMutual, tone: ProfilyTone.green, small: true)
            : (fm && !u.followedByMe ? ProfilyPill(l.profilyardFollowsYou, tone: ProfilyTone.red, small: true) : null));
    return Semantics(
      container: true,
      label: u.displayName,
      child: ProfilyRow(
        minHeight: 72,
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 10),
        onTap: () => openUserProfile(context, widget.session, userId: u.id, name: u.displayName, avatarUrl: u.avatarUrl),
        child: Row(children: [
          BuAvatar(name: u.displayName, url: u.avatarUrl, size: 44, headers: postAuthHeaders(widget.session)),
          const SizedBox(width: 12),
          Expanded(child: ProfilyTitleBlock(title: u.displayName, sub: u.department, pill: pill)),
          if (!self)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: ProfilyFollowButton(session: widget.session, userId: u.id, followed: u.followedByMe),
            ),
        ]),
      ),
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
