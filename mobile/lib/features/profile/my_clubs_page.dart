import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../clubs/club_actions.dart';
import '../clubs/club_categories.dart';
import '../clubs/club_detail_page.dart';
import '../clubs/club_form_page.dart';
import '../clubs/club_members_page.dart';
import '../clubs/club_requests_page.dart';
import '../clubs/clubs_tab.dart';
import 'profil_widgets.dart' show ProfilCard, ProfilSection;
import 'profily_widgets.dart';

/// Kulüplerim (GET /me/communities): kurduklarım / üye olduklarım / bekleyen başvurular.
class MyClubsPage extends StatefulWidget {
  const MyClubsPage({super.key, required this.session});

  final Session session;

  @override
  State<MyClubsPage> createState() => _MyClubsPageState();
}

class _MyClubsPageState extends State<MyClubsPage> {
  final _items = <Map<String, dynamic>>[];
  bool _loading = true;
  Object? _error;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Tüm sayfaları (en çok 10) çeker: bölümlere ayırmak için liste bütün olmalı.
  Future<void> _load({bool silent = false}) async {
    final gen = ++_gen;
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final all = <Map<String, dynamic>>[];
      int? cursor;
      for (var page = 0; page < 10; page++) {
        final c = cursor == null ? '' : '&cursor=$cursor';
        final r = await widget.session.api.get('/me/communities?size=20$c') as Map;
        all.addAll((r['items'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
        cursor = (r['nextCursor'] as num?)?.toInt();
        if (cursor == null) break;
      }
      if (!mounted || gen != _gen) return;
      setState(() {
        _items
          ..clear()
          ..addAll(all);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted && gen == _gen) setState(() { _error = e; _loading = false; });
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  int _id(Map<String, dynamic> c) => (c['id'] as num).toInt();

  Future<void> _open(Map<String, dynamic> c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClubDetailPage(session: widget.session, communityId: _id(c))),
    );
    if (mounted) _load(silent: true);
  }

  Future<void> _leave(Map<String, dynamic> c) async {
    final left = await leaveClubFlow(
      context,
      widget.session,
      communityId: _id(c),
      clubName: (c['name'] ?? '').toString(),
      isOwner: c['myRole'] == 'OWNER',
    );
    if (left && mounted) {
      setState(() => _items.remove(c));
      _snack(context.l10n.profilePrefsClubLeft);
    }
  }

  Future<void> _withdraw(Map<String, dynamic> c) async {
    final ok = await confirmDialog(context,
        title: context.l10n.profilePrefsWithdrawTitle,
        message: context.l10n.profilePrefsWithdrawBody,
        confirmLabel: context.l10n.profilePrefsWithdrawConfirm);
    if (!ok || !mounted) return;
    try {
      await widget.session.api.delete('/communities/${_id(c)}/membership');
      if (mounted) setState(() => _items.remove(c));
    } catch (e) {
      if (mounted) _snack(errorText(e));
    }
  }

  Future<void> _edit(Map<String, dynamic> c) async {
    // Listede tam alanlar olmayabilir: formu güncel kulüp verisiyle açar.
    Map<String, dynamic> club = c;
    try {
      final r = await widget.session.api.get('/communities/${_id(c)}');
      if (r is Map) club = Map<String, dynamic>.from(r);
    } catch (_) {}
    if (!mounted) return;
    final res = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => ClubFormPage(session: widget.session, club: club)),
    );
    if (res != null && mounted) _load(silent: true);
  }

  Future<void> _requests(Map<String, dynamic> c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClubRequestsPage(session: widget.session, communityId: _id(c))),
    );
    if (mounted) _load(silent: true);
  }

  Future<void> _members(Map<String, dynamic> c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClubMembersPage(
            session: widget.session, communityId: _id(c), myRole: c['myRole']?.toString()),
      ),
    );
    if (mounted) _load(silent: true);
  }

  Future<void> _discover() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Scaffold(body: ClubsTab(session: widget.session))),
    );
    if (mounted) _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final owned = _items.where((c) => c['myStatus'] != 'PENDING' && c['myRole'] == 'OWNER').toList();
    final member = _items.where((c) => c['myStatus'] != 'PENDING' && c['myRole'] != 'OWNER').toList();
    final pending = _items.where((c) => c['myStatus'] == 'PENDING').toList();

    Widget body;
    if (_loading && _items.isEmpty) {
      body = const LoadingView();
    } else if (_error != null && _items.isEmpty) {
      body = ErrorView(error: _error!, onRetry: _load);
    } else if (_items.isEmpty) {
      body = RefreshIndicator(
        color: t.pr,
        onRefresh: () => _load(silent: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ProfilyEmptyCard(
              icon: LucideIcons.users,
              title: l.profilyardClubsEmptyTitle,
              body: l.profilyardClubsEmptyBody,
              action: ProfilyPrimaryButton(label: l.profilyardClubsDiscover, onPressed: _discover),
            ),
          ],
        ),
      );
    } else {
      body = RefreshIndicator(
        color: t.pr,
        onRefresh: () => _load(silent: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (owned.isNotEmpty) ..._section(l.profilyardClubsManaged, owned, owner: true, top: 4),
            if (member.isNotEmpty) ..._section(l.profilyardClubsMember, member),
            if (pending.isNotEmpty) ..._section(l.profilyardClubsPending, pending, pending: true),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(
            title: l.profilePrefsMyClubs,
            onBack: () => Navigator.pop(context),
            actions: [
              BuIconButton(
                icon: LucideIcons.plus,
                tooltip: l.profilePrefsCreateClub,
                filled: true,
                onTap: () async {
                  if (await openCreateClub(context, widget.session) && mounted) _load(silent: true);
                },
              ),
            ],
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  List<Widget> _section(String title, List<Map<String, dynamic>> list,
      {bool owner = false, bool pending = false, double top = 16}) {
    return [
      ProfilSection('$title (${list.length})', top: top),
      ProfilCard(children: [for (final c in list) _row(c, owner: owner, pending: pending)]),
    ];
  }

  (String, ProfilyTone) _role(Map<String, dynamic> c) {
    final l = context.l10n;
    return switch (c['myRole']) {
      'OWNER' => (l.profilyardRoleOwner, ProfilyTone.red),
      'ADMIN' => (l.profilyardRoleAdmin, ProfilyTone.green),
      'MODERATOR' => (l.profilyardRoleModerator, ProfilyTone.green),
      _ => (l.profilyardRoleMember, ProfilyTone.violet),
    };
  }

  Widget _row(Map<String, dynamic> c, {required bool owner, required bool pending}) {
    final t = context.bu;
    final l = context.l10n;
    final members = (c['memberCount'] as num?)?.toInt();
    final sub = [
      if (owner) l.profilyardRoleFounder,
      if ((c['category'] as String?)?.isNotEmpty == true) ClubCategories.labelFor(c['category'] as String),
      if (members != null) l.profilePrefsMembersCount('$members'),
    ].join(' · ');
    final inReview = owner && (c['status'] == 'PENDING_REVIEW' || c['status'] == 'PENDING');
    final manager = isClubManagerRole(c['myRole']?.toString()) && !pending;
    final (roleLabel, roleTone) = _role(c);
    final Widget pill = pending
        ? ProfilyPill(l.profilePrefsAwaitingApproval, tone: ProfilyTone.amber)
        : (inReview ? ProfilyPill(l.profilePrefsAwaitingPublish, tone: ProfilyTone.amber) : ProfilyPill(roleLabel, tone: roleTone));
    return ProfilyRow(
      onTap: () => _open(c),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 8, 12),
      child: Row(
        children: [
          BuAvatar(name: c['name'] as String?, url: (c['logoUrl'] ?? c['coverUrl']) as String?, size: 48, square: true),
          const SizedBox(width: 12),
          Expanded(child: ProfilyTitleBlock(title: (c['name'] as String?) ?? '', sub: sub, pill: pill)),
          PopupMenuButton<String>(
            tooltip: manager ? l.profilePrefsManage : l.profilePrefsOptions,
            icon: Icon(LucideIcons.ellipsisVertical, size: 20, color: t.mut),
            onSelected: (v) {
              switch (v) {
                case 'open':
                  _open(c);
                case 'edit':
                  _edit(c);
                case 'requests':
                  _requests(c);
                case 'members':
                  _members(c);
                case 'leave':
                  _leave(c);
                case 'withdraw':
                  _withdraw(c);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'open', child: Text(l.profilePrefsOpen)),
              if (manager) ...[
                PopupMenuItem(value: 'edit', child: Text(l.profilePrefsManageEdit)),
                PopupMenuItem(value: 'requests', child: Text(l.profilePrefsManageRequests)),
                PopupMenuItem(value: 'members', child: Text(l.profilePrefsManageMembers)),
              ],
              if (pending)
                PopupMenuItem(value: 'withdraw', child: Text(l.profilePrefsWithdrawTitle, style: dangerItemStyle(context)))
              else if (!owner)
                PopupMenuItem(value: 'leave', child: Text(l.profilePrefsLeaveClub, style: dangerItemStyle(context))),
            ],
          ),
        ],
      ),
    );
  }
}
