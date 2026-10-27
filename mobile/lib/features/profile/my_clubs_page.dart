import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../clubs/club_actions.dart';
import '../clubs/club_detail_page.dart';
import '../clubs/club_form_page.dart';
import '../clubs/club_members_page.dart';
import '../clubs/club_requests_page.dart';

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
      _snack('Kulüpten ayrıldın.');
    }
  }

  Future<void> _withdraw(Map<String, dynamic> c) async {
    final ok = await confirmDialog(context,
        title: 'İsteği geri çek', message: 'Katılma isteğiniz geri çekilsin mi?', confirmLabel: 'Geri çek');
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

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final owned = _items.where((c) => c['myStatus'] != 'PENDING' && c['myRole'] == 'OWNER').toList();
    final member = _items.where((c) => c['myStatus'] != 'PENDING' && c['myRole'] != 'OWNER').toList();
    final pending = _items.where((c) => c['myStatus'] == 'PENDING').toList();

    Widget body;
    if (_loading && _items.isEmpty) {
      body = const LoadingView();
    } else if (_error != null && _items.isEmpty) {
      body = ErrorView(error: _error!, onRetry: _load);
    } else if (_items.isEmpty) {
      body = const EmptyView(icon: LucideIcons.users, text: 'Henüz bir kulübe üye değilsiniz.');
    } else {
      body = RefreshIndicator(
        color: t.pr,
        onRefresh: () => _load(silent: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (owned.isNotEmpty) ..._section(t, 'Kurduklarım', owned, owner: true),
            if (member.isNotEmpty) ..._section(t, 'Üye olduklarım', member),
            if (pending.isNotEmpty) ..._section(t, 'Bekleyen başvurular', pending, pending: true),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(
            title: 'Kulüplerim',
            onBack: () => Navigator.pop(context),
            actions: [
              BuIconButton(
                icon: LucideIcons.plus,
                tooltip: 'Kulüp kur',
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

  List<Widget> _section(BuTokens t, String title, List<Map<String, dynamic>> list,
      {bool owner = false, bool pending = false}) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 0, 10),
        child: Text('$title (${list.length})', style: BuType.label.copyWith(color: t.mut)),
      ),
      for (final c in list) ...[
        _card(t, c, owner: owner, pending: pending),
        const SizedBox(height: 10),
      ],
    ];
  }

  Widget _card(BuTokens t, Map<String, dynamic> c, {required bool owner, required bool pending}) {
    final members = (c['memberCount'] as num?)?.toInt();
    final sub = [
      if ((c['category'] as String?)?.isNotEmpty == true) c['category'] as String,
      if (members != null) '$members üye',
    ].join(' · ');
    final inReview = owner && (c['status'] == 'PENDING_REVIEW' || c['status'] == 'PENDING');
    final manager = isClubManagerRole(c['myRole']?.toString()) && !pending;
    return BuCard(
      onTap: () => _open(c),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        children: [
          BuAvatar(name: c['name'] as String?, url: (c['logoUrl'] ?? c['coverUrl']) as String?, size: 52, square: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((c['name'] as String?) ?? '',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.bodyStrong.copyWith(color: t.ink)),
                if (sub.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(color: t.mut)),
                  ),
                // Dar ekranda satırı taşırmamak için rozet adın altında durur.
                if (pending || inReview)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: BuBadge(pending ? 'Onay bekliyor' : 'Yayın onayı bekleniyor', soft: true),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: manager ? 'Yönet' : 'Seçenekler',
            icon: Icon(LucideIcons.ellipsis, size: 20, color: t.mut),
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
              const PopupMenuItem(value: 'open', child: Text('Aç')),
              if (manager) ...[
                const PopupMenuItem(value: 'edit', child: Text('Yönet: düzenle')),
                const PopupMenuItem(value: 'requests', child: Text('Yönet: başvurular')),
                const PopupMenuItem(value: 'members', child: Text('Yönet: üyeler')),
              ],
              if (pending)
                PopupMenuItem(value: 'withdraw', child: Text('İsteği geri çek', style: dangerItemStyle(context)))
              else if (!owner)
                PopupMenuItem(value: 'leave', child: Text('Kulüpten ayrıl', style: dangerItemStyle(context))),
            ],
          ),
        ],
      ),
    );
  }
}
