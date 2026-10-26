import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';

/// Engellenen kullanıcılar ve engeli kaldırma.
class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key, required this.session});

  final Session session;

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  List<Map<String, dynamic>>? _items;
  Object? _error;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.session.api.get('/users/me/blocks') as List;
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(r);
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _unblock(Map<String, dynamic> u) async {
    final id = (u['id'] as num).toInt();
    setState(() => _busy.add(id));
    try {
      await widget.session.api.delete('/users/$id/block');
      if (mounted) setState(() => _items!.removeWhere((x) => x['id'] == u['id']));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    Widget body;
    if (_error != null && _items == null) {
      body = ErrorView(error: _error!, onRetry: () {
        setState(() => _error = null);
        _load();
      });
    } else if (_items == null) {
      body = const LoadingView();
    } else if (_items!.isEmpty) {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: const [
          SizedBox(height: 120),
          EmptyView(icon: LucideIcons.ban, text: 'Engellediğiniz kullanıcı yok.'),
        ]),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            BuGroup(children: [
              for (final u in _items!)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    BuAvatar(name: u['displayName'] as String?, url: u['avatarUrl'] as String?, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text((u['displayName'] as String?) ?? 'Kullanıcı',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.ink)),
                    ),
                    BuButton(
                      label: 'Engeli kaldır',
                      compact: true,
                      kind: BuButtonKind.outline,
                      busy: _busy.contains((u['id'] as num).toInt()),
                      onPressed: () => _unblock(u),
                    ),
                  ]),
                ),
            ]),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(title: 'Engellenenler', onBack: () => Navigator.pop(context)),
        Expanded(child: body),
      ]),
    );
  }
}
