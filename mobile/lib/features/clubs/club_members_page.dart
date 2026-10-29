import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'club_actions.dart';
import 'club_detail_parts.dart';
import 'club_ref_widgets.dart';

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
  bool _paging = false; // sayfalama ucundaki iskelet; çekerek yenilemede görünmez
  Object? _error;
  bool _changed = false;
  String _query = '';
  final _scroll = ScrollController();
  final _search = TextEditingController();
  int _gen = 0;

  String get _base => '/communities/${widget.communityId}';
  bool get _isOwner => widget.myRole == 'OWNER';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 300 && _next != null && !_loading) _load();
    });
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    final gen = ++_gen;
    setState(() {
      _loading = true;
      _paging = !reset;
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
        _paging = false;
      });
    } catch (e) {
      if (mounted && gen == _gen) {
        setState(() {
          _error = e;
          _loading = false;
          _paging = false;
        });
      }
    }
  }

  void _snack(String m) => BuToast.show(context, m, kind: BuToastKind.error);

  /// Çıkar / yasakla onayı (A26 ailesi) + `DELETE members/{id}`.
  Future<void> _remove(Map<String, dynamic> m, {required bool ban}) async {
    final l = context.l10n;
    final name = (m['displayName'] ?? l.clubMgmtUser).toString();
    final ok = await confirmDialog(
      context,
      title: ban ? l.clubMgmtBan : l.clubMgmtRemoveFromClub,
      message: ban ? l.clubMgmtBanMessage(name) : l.clubMgmtRemoveMessage(name),
      confirmLabel: ban ? l.clubMgmtBan : l.clubMgmtRemoveConfirm,
      danger: true,
      leading: true,
      boldName: name,
      icon: ban ? LucideIcons.ban : LucideIcons.userMinus,
      confirmIcon: ban ? LucideIcons.ban : LucideIcons.userMinus,
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

  /// Üye işlemleri alt sayfası (referans 27-02): üstte üye özeti + kapat, altında rol değiştir (yalnız sahip), çıkar, yasakla.
  Future<void> _openActions(Map<String, dynamic> m) async {
    final l = context.l10n;
    final role = m['role']?.toString();
    final name = (m['displayName'] ?? l.clubMgmtUser).toString();
    final sub = clubMemberSubtitle(context, m);
    final v = await BuSheet.show<String>(
      context,
      builder: (c) {
        final t = c.bu;
        final tx = Theme.of(c).textTheme;
        void pick(String v) => Navigator.of(c).pop(v);
        final badge = clubRoleBadge(c, role);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  ClubRoleAvatar(name: name, url: m['avatarUrl']?.toString(), role: role, size: 48, ring: t.sf3),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                            if (badge != null) badge,
                          ],
                        ),
                        if (sub.isNotEmpty) Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
                      ],
                    ),
                  ),
                  ClubRoundButton(icon: LucideIcons.x, tooltip: l.commonClose, onTap: () => Navigator.of(c).pop(), size: 40),
                ],
              ),
            ),
            if (_isOwner)
              if (role == 'MEMBER')
                ClubSheetRow(icon: LucideIcons.shieldCheck, title: l.clubMgmtMakeModerator, onTap: () => pick('mod'))
              else
                ClubSheetRow(icon: LucideIcons.user, title: l.clubMgmtMakeMember, onTap: () => pick('member')),
            ClubSheetRow(icon: LucideIcons.userMinus, title: l.clubMgmtRemoveFromClub, onTap: () => pick('remove')),
            ClubSheetRow(icon: LucideIcons.ban, title: l.clubMgmtBan, danger: true, onTap: () => pick('ban')),
            const SizedBox(height: 8),
          ],
        );
      },
    );
    if (v == null || !mounted) return;
    switch (v) {
      case 'mod':
        await _setRole(m, 'MODERATOR');
      case 'member':
        await _setRole(m, 'MEMBER');
      case 'remove':
        await _remove(m, ban: false);
      case 'ban':
        await _remove(m, ban: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final list = _visible;
    final state = _loading && _items.isEmpty
        ? BuViewState.loading
        : _error != null && _items.isEmpty
            ? BuViewState.error
            : _items.isEmpty
                ? BuViewState.empty
                : BuViewState.ready;
    final subtitle = (widget.clubName ?? '').isEmpty
        ? null
        : l.kulupdetayMembersSubtitle(widget.clubName!, '${widget.memberCount ?? _items.length}');
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: BuPageScaffold(
        title: l.clubMgmtMembersTitle,
        large: false,
        state: state,
        error: _error,
        onRetry: () => _load(reset: true),
        onRefresh: () => _load(reset: true),
        controller: _scroll,
        loading: const BuSkeletonList(variant: BuSkeletonVariant.row, shrinkWrap: true),
        empty: BuEmptyState(illustration: BuIllustration.club, title: l.clubMgmtNoMembers),
        slivers: [
          if (subtitle != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
                child: Text(subtitle, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.mut)),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onChanged: (v) => setState(() => _query = v.trim()),
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: t.ink),
                decoration: clubFill(
                  context,
                  hint: l.clubMgmtSearchMember,
                  fill: t.sf,
                  pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  prefixIcon: Icon(LucideIcons.search, size: 20, color: t.mut),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l.p11ClearSearch,
                          icon: Icon(LucideIcons.circleX, size: 20, color: t.mut),
                          onPressed: () => setState(() {
                            _query = '';
                            _search.clear();
                          }),
                        ),
                ),
              ),
            ),
          ),
          if (list.isEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 320,
                child: BuEmptyState(
                  illustration: BuIllustration.search,
                  title: l.clubMgmtNoMembers,
                  message: l.p11SearchEmptyBody(_query),
                  secondaryLabel: l.p11ClearSearch,
                  onSecondary: () => setState(() {
                    _query = '';
                    _search.clear();
                  }),
                  compact: true,
                ),
              ),
            )
          else
            BuStaggerScope(
              child: SliverPadding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
                sliver: SliverList.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) => BuStaggerItem(
                    index: i,
                    child: Padding(padding: const EdgeInsets.only(bottom: 10), child: _row(list[i])),
                  ),
                ),
              ),
            ),
          if (_paging)
            const SliverToBoxAdapter(child: BuSkeletonList(variant: BuSkeletonVariant.row, itemCount: 1, shrinkWrap: true)),
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> m) {
    final role = m['role']?.toString();
    final self = (m['userId'] as num?)?.toInt() == widget.session.userId;
    final target = role == 'OWNER';
    final canAct = !self && !target && (_isOwner || role == 'MEMBER');
    return ClubMemberTile(
      member: m,
      nameFallback: context.l10n.clubMgmtUser,
      trailing: canAct
          ? ClubRoundButton(icon: LucideIcons.ellipsis, tooltip: context.l10n.clubMgmtMemberActions, onTap: () => _openActions(m), plain: true)
          : null,
    );
  }
}
