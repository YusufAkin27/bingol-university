import 'package:flutter/material.dart';

import '../../core/analytics.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../events/etkinlik_parts.dart' show EtkinlikSubChips;
import '../events/event_form_page.dart';
import '../events/event_parts.dart' show eventIsExpired;
import 'club_detail_page.dart';
import 'club_form_page.dart';
import 'club_logo.dart';
import 'club_join_qr_page.dart';
import 'club_members_page.dart';
import 'club_requests_page.dart';

/// Yönettiğim bir kulüp: kısa özet için sade bilgi (yönetim merkezinden geçilir).
typedef ManagedClub = ({int id, String name});

/// Kulüp yönetim paneli: kulüp kartı (üye / bekleyen başvuru / yaklaşan etkinlik) + hızlı işlemler.
/// Hızlı işlemler YALNIZ sunucunun verdiği kulüp izinlerine (`GET /communities/{id}/permissions/me`) göre
/// gösterilir; yetki alınamazsa hiçbir yönetim aracı çizilmez (yetki sunucuda da doğrulanır).
class ClubManagePage extends StatefulWidget {
  const ClubManagePage({super.key, required this.session, required this.communityId, this.managed = const []});

  final Session session;
  final int communityId;

  /// Birden fazla kulüp yönetiliyorsa geçiş çipleri için tüm yönetilen kulüpler.
  final List<ManagedClub> managed;

  @override
  State<ClubManagePage> createState() => _ClubManagePageState();
}

class _ClubManagePageState extends State<ClubManagePage> {
  late int _id = widget.communityId;
  Map<String, dynamic>? _club;
  Set<String> _perms = {};
  String? _role;
  int? _pending;
  bool _pendingMore = false;
  int? _events;
  bool _loading = true;
  Object? _error;
  int _gen = 0;

  String get _base => '/communities/$_id';
  bool _can(String p) => _perms.contains(p);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    final gen = ++_gen;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final api = widget.session.api;
      final club = await api.get(_base);
      final acc = await api.get('$_base/permissions/me');
      if (!mounted || gen != _gen) return;
      final perms = <String>{
        for (final p in (acc is Map ? acc['permissions'] as List? ?? const [] : const [])) p.toString(),
      };
      setState(() {
        _club = Map<String, dynamic>.from(club as Map);
        _perms = perms;
        _role = acc is Map ? acc['role']?.toString() : null;
        _loading = false;
        _error = null;
      });
      _loadCounts(gen);
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// Sayaçlar ek bilgidir: hata ekranı açmaz, yalnız boş kalır.
  Future<void> _loadCounts(int gen) async {
    final api = widget.session.api;
    int? pending;
    var more = false;
    int? events;
    if (_can('MANAGE_MEMBERS')) {
      try {
        final r = await api.get('$_base/requests?size=20') as Map;
        pending = (r['items'] as List? ?? []).length;
        more = r['nextCursor'] != null;
      } catch (_) {
        // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
      }
    }
    try {
      final r = await api.get('/events?communityId=$_id&size=20') as Map;
      events = (r['items'] as List? ?? []).whereType<Map>().where((e) => !eventIsExpired(Map<String, dynamic>.from(e))).length;
    } catch (_) {
      // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
    }
    if (!mounted || gen != _gen) return;
    setState(() {
      _pending = pending;
      _pendingMore = more;
      _events = events;
    });
  }

  void _switchTo(int id) {
    if (id == _id) return;
    setState(() {
      _id = id;
      _club = null;
      _perms = {};
      _pending = null;
      _events = null;
    });
    _load();
  }

  Future<void> _go(Widget page, String name) async {
    await Navigator.push(context, MaterialPageRoute(settings: RouteSettings(name: name), builder: (_) => page));
    if (mounted) _load(silent: true);
  }

  bool get _hasAnyTool =>
      _can('EDIT_INFO') || _can('MANAGE_MEMBERS') || _can('MANAGE_EVENTS') || _can('MANAGE_POSTS') || _can('MANAGE_ROLES');

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    Widget body;
    if (_loading && _club == null) {
      body = const BuSkeletonList(variant: BuSkeletonVariant.card, itemCount: 3);
    } else if (_error != null && _club == null) {
      body = BuErrorState(error: _error, onRetry: _load);
    } else if (_club == null) {
      body = const SizedBox.shrink();
    } else {
      body = RefreshIndicator(
        color: t.pr,
        onRefresh: Analytics.pullRefresh(() => _load(silent: true)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (widget.managed.length > 1) ...[
              SingleChildScrollView(
                key: const ValueKey('hub-switcher'),
                scrollDirection: Axis.horizontal,
                child: EtkinlikSubChips(
                  labels: [for (final c in widget.managed) c.name],
                  selected: widget.managed.indexWhere((c) => c.id == _id).clamp(0, widget.managed.length - 1),
                  onSelected: (i) => _switchTo(widget.managed[i].id),
                ),
              ),
              const SizedBox(height: 8),
            ],
            _header(),
            const SizedBox(height: 16),
            if (!_hasAnyTool)
              BuCard(
                style: BuCardStyle.outlined,
                child: Text(l.hubNoAccess, key: const ValueKey('hub-no-access'), style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.mut)),
              )
            else
              BuCard(style: BuCardStyle.outlined, padding: EdgeInsets.zero, child: Column(children: _actions())),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(title: l.hubManageTitle, onBack: () => Navigator.pop(context)),
        Expanded(child: body),
      ]),
    );
  }

  Widget _header() {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final c = _club!;
    final members = (c['memberCount'] as num?)?.toInt();
    final roleLabel = switch (_role) {
      'OWNER' => l.profilyardRoleOwner,
      'ADMIN' => l.profilyardRoleAdmin,
      'MODERATOR' => l.profilyardRoleModerator,
      _ => l.profilyardRoleMember,
    };
    String stat(int? n, {bool more = false}) => n == null ? '–' : '$n${more ? '+' : ''}';
    return BuCard(
      key: const ValueKey('hub-club-card'),
      style: BuCardStyle.outlined,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          ClubLogoBox(club: c, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((c['name'] ?? '').toString(),
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
              const SizedBox(height: 4),
              Text(roleLabel, style: tx.bodySmall!.copyWith(color: t.mut)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _Stat(value: stat(members), label: l.hubStatMembers),
          if (_can('MANAGE_MEMBERS')) _Stat(value: stat(_pending, more: _pendingMore), label: l.hubSumPending, key: const ValueKey('hub-stat-pending')),
          _Stat(value: stat(_events), label: l.hubSumEvents),
        ]),
      ]),
    );
  }

  List<Widget> _actions() {
    final l = context.l10n;
    final club = _club!;
    final name = (club['name'] ?? '').toString();
    final rows = <Widget>[];
    void add(String key, IconData icon, String title, VoidCallback onTap, {String? subtitle, String? badge}) {
      rows.add(_ActionRow(key: ValueKey('hub-act-$key'), icon: icon, title: title, subtitle: subtitle, badge: badge, onTap: onTap));
    }

    if (_can('MANAGE_MEMBERS')) {
      final n = _pending ?? 0;
      add('requests', BuIcons.userPlus, l.clubRequests, badge: n > 0 ? '$n${_pendingMore ? '+' : ''}' : null,
          () => _go(ClubRequestsPage(session: widget.session, communityId: _id), 'club_requests'));
      add('members', BuIcons.users, l.clubManageMembers,
          () => _go(
              ClubMembersPage(
                  session: widget.session,
                  communityId: _id,
                  myRole: _role,
                  clubName: name,
                  memberCount: (club['memberCount'] as num?)?.toInt()),
              'club_members'));
    }
    if (_can('MANAGE_MEMBERS')) {
      add('joinqr', BuIcons.qrCode, l.clubJoinQrAction, subtitle: l.clubJoinQrActionSub,
          () => _go(ClubJoinQrPage(session: widget.session, communityId: _id, clubName: name), 'club_join_qr'));
    }
    if (_can('MANAGE_EVENTS')) {
      add('event', BuIcons.calendarPlus, l.eventListCreate,
          () => _go(EventFormPage(session: widget.session, communityId: _id), 'event_form'));
      add('events', BuIcons.calendarCheck, l.hubActEvents, subtitle: l.hubActEventsSub,
          () => _go(ClubDetailPage(session: widget.session, communityId: _id, initialTab: 'events'), 'club_detail'));
    }
    if (_can('MANAGE_POSTS')) {
      add('announce', BuIcons.megaphone, l.hubActAnnounce,
          () => _go(ClubDetailPage(session: widget.session, communityId: _id, initialTab: 'posts'), 'club_detail'));
      add('posts', BuIcons.image, l.hubActPosts,
          () => _go(ClubDetailPage(session: widget.session, communityId: _id, initialTab: 'posts'), 'club_detail'));
    }
    if (_can('EDIT_INFO')) {
      add('edit', BuIcons.pencilLine, l.clubEdit,
          () => _go(ClubFormPage(session: widget.session, club: club), 'club_form'));
    }
    if (_can('MANAGE_ROLES')) {
      add('roles', BuIcons.shieldCheck, l.hubActRoles,
          () => _go(
              ClubMembersPage(
                  session: widget.session,
                  communityId: _id,
                  myRole: _role,
                  clubName: name,
                  memberCount: (club['memberCount'] as num?)?.toInt()),
              'club_members'));
    }
    final t = context.bu;
    return [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) Divider(height: 1, indent: 64, endIndent: 16, color: t.bd),
        rows[i],
      ],
    ];
  }
}

class _Stat extends StatelessWidget {
  const _Stat({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Expanded(
      child: Column(children: [
        Text(value, style: tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
      ]),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({super.key, required this.icon, required this.title, required this.onTap, this.subtitle, this.badge});

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: title,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BuRadius.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 12, 10),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 20, color: t.ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodyLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
                  if (subtitle != null) Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
                ]),
              ),
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: t.ink, borderRadius: BuRadius.bPill),
                  child: Text(badge!, style: tx.labelSmall!.copyWith(color: t.bg, fontWeight: FontWeight.w400)),
                ),
                const SizedBox(width: 8),
              ],
              ExcludeSemantics(child: Icon(buDirIcon(context, BuIcons.chevronRight), size: 20, color: t.mut)),
            ]),
          ),
        ),
      ),
    );
  }
}
