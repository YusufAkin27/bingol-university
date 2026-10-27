import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'club_actions.dart';

/// Kulüp üyelerini yönetme: arama, rol değiştirme (yalnız sahip), çıkarma, yasaklama.
/// Pop sonucu: değişiklik olduysa true.
class ClubMembersPage extends StatefulWidget {
  const ClubMembersPage({super.key, required this.session, required this.communityId, required this.myRole});

  final Session session;
  final int communityId;
  final String? myRole;

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
    final name = (m['displayName'] ?? 'Kullanıcı').toString();
    final ok = await confirmDialog(
      context,
      title: ban ? 'Yasakla' : 'Kulüpten çıkar',
      message: ban
          ? '$name kulüpten çıkarılsın ve bir daha katılamasın mı?'
          : '$name kulüpten çıkarılsın mı? Kulüp sohbetinden de düşer.',
      confirmLabel: ban ? 'Yasakla' : 'Çıkar',
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
      body = const EmptyView(icon: LucideIcons.users, text: 'Üye bulunamadı.');
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
            BuHeader(title: 'Üyeler', onBack: () => Navigator.pop(context, _changed)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: BuSearchField(hint: 'Üye ara', onChanged: (v) => setState(() => _query = v.trim())),
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
      padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 6, 8),
      child: Row(
        children: [
          BuAvatar(name: m['displayName']?.toString(), url: m['avatarUrl']?.toString(), size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((m['displayName'] ?? 'Kullanıcı').toString(),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.bodyStrong.copyWith(color: t.ink)),
                if (role == 'OWNER' || role == 'ADMIN' || role == 'MODERATOR')
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: BuBadge(role == 'OWNER' ? 'Yönetici' : role == 'ADMIN' ? 'Yönetici' : 'Moderatör', soft: true),
                  ),
              ],
            ),
          ),
          if (canAct)
            PopupMenuButton<String>(
              tooltip: 'Üye işlemleri',
              icon: Icon(LucideIcons.ellipsis, size: 18, color: t.mut),
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
                if (_isOwner && role == 'MEMBER') const PopupMenuItem(value: 'mod', child: Text('Moderatör yap')),
                if (_isOwner && role != 'MEMBER') const PopupMenuItem(value: 'member', child: Text('Üye yap')),
                PopupMenuItem(value: 'remove', child: Text('Kulüpten çıkar', style: dangerItemStyle(context))),
                PopupMenuItem(value: 'ban', child: Text('Yasakla', style: dangerItemStyle(context))),
              ],
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}
