import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'club_actions.dart';
import 'kulup_widgets.dart';

/// Kulüp üyelerini yönetme: arama, rol değiştirme (yalnız sahip), çıkarma, yasaklama.
/// Pop sonucu: değişiklik olduysa true.
class ClubMembersPage extends StatefulWidget {
  const ClubMembersPage({
    super.key,
    required this.session,
    required this.communityId,
    required this.myRole,
    this.clubName,
    this.memberCount,
  });

  final Session session;
  final int communityId;
  final String? myRole;

  /// Başlık altı satırı için (isteğe bağlı): "Kulüp adı · N üye".
  final String? clubName;
  final int? memberCount;

  @override
  State<ClubMembersPage> createState() => _ClubMembersPageState();
}

class _ClubMembersPageState extends State<ClubMembersPage> {
  final _items = <Map<String, dynamic>>[];
  int? _next;
  bool _loading = true;
  Object? _error;
  bool _changed = false;
  String _query = '';
  final _scroll = ScrollController();
  int _gen = 0;

  String get _base => '/communities/${widget.communityId}';
  bool get _isOwner => widget.myRole == 'OWNER';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300 && _next != null && !_loading) _load();
    });
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    final gen = ++_gen;
    setState(() {
      _loading = true;
      if (reset) _error = null;
    });
    try {
      final cursor = (!reset && _next != null) ? '&cursor=$_next' : '';
      final r = await widget.session.api.get('$_base/members?size=20$cursor') as Map;
      if (!mounted || gen != _gen) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll((r['items'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
        _next = (r['nextCursor'] as num?)?.toInt();
        _loading = false;
      });
    } catch (e) {
      if (mounted && gen == _gen) setState(() { _error = e; _loading = false; });
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _remove(Map<String, dynamic> m, {required bool ban}) async {
    final l = context.l10n;
    final name = (m['displayName'] ?? l.clubMgmtUser).toString();
    final ok = await confirmDialog(
      context,
      title: ban ? l.clubMgmtBan : l.clubMgmtRemoveFromClub,
      message: ban ? l.clubMgmtBanMessage(name) : l.clubMgmtRemoveMessage(name),
      confirmLabel: ban ? l.clubMgmtBan : l.clubMgmtRemoveConfirm,
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await widget.session.api.delete('$_base/members/${m['userId']}${ban ? '?ban=true' : ''}');
      if (!mounted) return;
      setState(() {
        _items.remove(m);
        _changed = true;
      });
    } catch (e) {
      if (mounted) _snack(errorText(e));
    }
  }

  Future<void> _setRole(Map<String, dynamic> m, String role) async {
    try {
      await widget.session.api.put('$_base/members/${m['userId']}/role', {'role': role});
      if (!mounted) return;
      setState(() {
        m['role'] = role;
        _changed = true;
      });
    } catch (e) {
      if (mounted) _snack(errorText(e));
    }
  }

  List<Map<String, dynamic>> get _visible {
    if (_query.isEmpty) return _items;
    final q = _query.toLowerCase();
    return _items.where((m) => (m['displayName'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final list = _visible;
    Widget body;
    if (_loading && _items.isEmpty) {
      body = const LoadingView();
    } else if (_error != null && _items.isEmpty) {
      body = ErrorView(error: _error!, onRetry: () => _load(reset: true));
    } else if (list.isEmpty) {
      body = EmptyView(icon: LucideIcons.users, text: context.l10n.clubMgmtNoMembers);
    } else {
      body = ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        itemCount: list.length + (_loading ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          if (i >= list.length) {
            return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
          }
          return _row(t, list[i]);
        },
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: t.bg,
        body: Column(
          children: [
            BuHeader(
              title: context.l10n.clubMgmtMembersTitle,
              subtitle: (widget.clubName ?? '').isEmpty
                  ? null
                  : context.l10n.kulupdetayMembersSubtitle(widget.clubName!, '${widget.memberCount ?? _items.length}'),
              onBack: () => Navigator.pop(context, _changed),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: BuSearchField(hint: context.l10n.clubMgmtSearchMember, onChanged: (v) => setState(() => _query = v.trim())),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _row(BuTokens t, Map<String, dynamic> m) {
    final role = m['role']?.toString();
    final self = (m['userId'] as num?)?.toInt() == widget.session.userId;
    final target = role == 'OWNER';
    final canAct = !self && !target && (_isOwner || role == 'MEMBER');
    return BuCard(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 6, 10),
      child: Row(
        children: [
          KulupAvatar(name: m['displayName']?.toString(), url: m['avatarUrl']?.toString(), size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((m['displayName'] ?? context.l10n.clubMgmtUser).toString(),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.bodyStrong.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
                if (role == 'OWNER' || role == 'ADMIN' || role == 'MODERATOR')
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: KulupRoleBadge(role == 'OWNER' || role == 'ADMIN'
                          ? context.l10n.clubMgmtRoleManager
                          : context.l10n.clubMgmtRoleModerator),
                    ),
                  ),
              ],
            ),
          ),
          if (canAct)
            PopupMenuButton<String>(
              tooltip: context.l10n.clubMgmtMemberActions,
              color: t.sf,
              elevation: 8,
              shape: kulupMenuShape(context),
              constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
              icon: const KulupDots(),
              onSelected: (v) {
                switch (v) {
                  case 'mod':
                    _setRole(m, 'MODERATOR');
                  case 'member':
                    _setRole(m, 'MEMBER');
                  case 'remove':
                    _remove(m, ban: false);
                  case 'ban':
                    _remove(m, ban: true);
                }
              },
              itemBuilder: (_) => [
                if (_isOwner && role == 'MEMBER')
                  PopupMenuItem(value: 'mod', height: 44, child: KulupMenuRow(context.l10n.clubMgmtMakeModerator)),
                if (_isOwner && role != 'MEMBER')
                  PopupMenuItem(value: 'member', height: 44, child: KulupMenuRow(context.l10n.clubMgmtMakeMember)),
                if (_isOwner) const PopupMenuDivider(height: 9),
                PopupMenuItem(value: 'remove', height: 44, child: KulupMenuRow(context.l10n.clubMgmtRemoveFromClub, danger: true)),
                PopupMenuItem(value: 'ban', height: 44, child: KulupMenuRow(context.l10n.clubMgmtBan, danger: true)),
              ],
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}
