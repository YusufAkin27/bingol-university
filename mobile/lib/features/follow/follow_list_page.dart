import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../posts/post_models.dart' show PostPage, postAuthHeaders;
import '../posts/social_models.dart';
import '../profile/profily_widgets.dart';
import '../profile/user_profile_page.dart';
import 'follow_widgets.dart';
import '../../core/academic_catalog.dart';

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
  final classYear = <int, int>{}; // yalnız API alanı gelirse dolar (`classYear` / `grade`)
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
      if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _load(_tab);
    // Öbür sekmenin sayacı da görünsün diye sessizce önden yüklenir.
    _load(1 - _tab, silent: true);
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
    // `followsMe` / `classYear` henüz her sürümde yok: yalnız alan varsa ve türü uygunsa kaydedilir.
    if (res is Map && res['items'] is List) {
      for (final e in (res['items'] as List).whereType<Map>()) {
        final id = e['id'] ?? e['userId'];
        if (id is! num) continue;
        final v = e['followsMe'];
        if (v is bool) st.followsMe[id.toInt()] = v;
        final y = e['classYear'] ?? e['grade'];
        final n = y is num ? y.toInt() : int.tryParse('${y ?? ''}');
        if (n != null && n > 0 && n <= 6) st.classYear[id.toInt()] = n;
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
        // Sessiz ön yükleme hatası kullanıcıya gösterilmez; sekmeye geçince yeniden denenir.
        if (!silent) st.error = e;
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

  FollowRelation _relation(SocialUser u, _Tab st) {
    if (st.followsMe[u.id] == true) return u.followedByMe ? FollowRelation.mutual : FollowRelation.followsYou;
    return u.followedByMe ? FollowRelation.following : FollowRelation.none;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final st = _cur;
    final name = (widget.name ?? '').trim();
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? st.items
        : st.items.where((u) => '${u.displayName} ${u.department ?? ''} ${context.departmentName(u.department)}'.toLowerCase().contains(q)).toList();

    // Sekmeler ve arama her durumda görünür; durum (iskelet / hata / boş / liste) altında değişir.
    final Widget body;
    if (st.loading) {
      body = const FollowSkeletonCard(count: 5);
    } else if (st.error != null && st.items.isEmpty) {
      body = FollowStatusCard(
        error: true,
        icon: LucideIcons.wifiOff,
        title: l.p18FollowErrorTitle,
        message: errorText(st.error!),
        onRetry: () => _load(_tab),
      );
    } else if (st.items.isEmpty) {
      body = FollowStatusCard(
        icon: _tab == 0 ? LucideIcons.users : LucideIcons.userPlus,
        title: _tab == 0 ? l.followersEmpty : l.followingEmpty,
        message: _tab == 0 ? l.p18FollowersEmptyBody : l.p18FollowingEmptyBody,
      );
    } else if (shown.isEmpty) {
      body = FollowStatusCard(
        icon: LucideIcons.userSearch,
        title: l.profilyardFollowNoMatch,
        message: l.p18FollowNoMatchBody,
        actionLabel: l.p18ClearSearch,
        actionIcon: LucideIcons.delete,
        onAction: () => setState(() {
          _search.clear();
          _query = '';
        }),
      );
    } else {
      final total = st.total ?? st.items.length;
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (q.isEmpty) FollowSectionLabel(_tab == 0 ? l.p18AllFollowers('$total') : l.p18AllFollowing('$total')),
        FollowCard(children: [
          for (var i = 0; i < shown.length; i++)
            BuStaggerItem(
              index: i,
              child: FollowPersonRow(
                session: widget.session,
                user: shown[i],
                relation: _relation(shown[i], st),
                classLabel: st.classYear[shown[i].id] == null ? null : l.p18ClassYear('${st.classYear[shown[i].id]}'),
              ),
            ),
        ]),
        if (st.more) const Padding(padding: EdgeInsets.only(top: 12), child: FollowSkeletonCard(count: 2)),
      ]);
    }

    return Scaffold(
      backgroundColor: context.bu.bg,
      body: Column(children: [
        BuHeader(
          title: name.isEmpty ? (widget.followers ? l.followersTitle : l.followingTitle) : name,
          onBack: () => Navigator.maybePop(context),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(_tab, silent: true),
            child: BuStaggerScope(
              child: ListView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.paddingOf(context).bottom + 24),
                children: [
                  FollowTabs(
                    labels: [l.followersTitle, l.followingTitle],
                    counts: [_tabs[0].total, _tabs[1].total],
                    index: _tab,
                    onChanged: _switch,
                  ),
                  const SizedBox(height: 12),
                  ProfilySearchField(
                    controller: _search,
                    hint: _tab == 0 ? l.profilyardFollowersSearch : l.profilyardFollowingSearch,
                    label: _tab == 0 ? l.profilyardFollowersSearch : l.profilyardFollowingSearch,
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 16),
                  body,
                ],
              ),
            ),
          ),
        ),
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
    final self = user.id == session.userId;
    return Semantics(
      container: true,
      label: user.displayName,
      child: ProfilyRow(
        minHeight: 68,
        padding: const EdgeInsetsDirectional.fromSTEB(0, 8, 0, 8),
        onTap: () =>
            openUserProfile(context, session, userId: user.id, name: user.displayName, avatarUrl: user.avatarUrl),
        child: Row(children: [
          BuAvatar(name: user.displayName, url: user.avatarUrl, size: 46, headers: postAuthHeaders(session)),
          const SizedBox(width: 12),
          Expanded(child: ProfilyTitleBlock(title: user.displayName, sub: context.departmentName(user.department))),
          if (trailing != null)
            trailing!
          else if (!self)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: ProfilyFollowButton(session: session, userId: user.id, followed: user.followedByMe),
            ),
        ]),
      ),
    );
  }
}
