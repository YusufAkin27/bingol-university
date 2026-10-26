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
  static const _pageSize = 30;

  List<Map<String, dynamic>>? _items;
  Object? _error;
  String? _next;
  bool _more = false;
  final Set<int> _busy = {};
  final _scroll = ScrollController();

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

  Future<(List<Map<String, dynamic>>, String?)> _fetch([String? cursor]) async {
    final q = 'limit=$_pageSize${cursor == null ? '' : '&cursor=${Uri.encodeQueryComponent(cursor)}'}';
    final r = await widget.session.api.getResponse('/users/me/blocks?$q');
    final body = r.body;
    final list = body is List ? body : (body is Map ? (body['items'] as List? ?? const []) : const []);
    final next = r.headers['x-next-cursor'];
    return (
      list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(),
      (next == null || next.isEmpty) ? null : next,
    );
  }

  Future<void> _load() async {
    try {
      final (items, next) = await _fetch();
      if (!mounted) return;
      setState(() {
        _items = items;
        _next = next;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _loadMore() async {
    final c = _next;
    if (c == null || _more || _items == null) return;
    setState(() => _more = true);
    try {
      final (items, next) = await _fetch(c);
      if (!mounted) return;
      setState(() {
        _items!.addAll(items);
        _next = next;
        _more = false;
      });
    } catch (_) {
      if (mounted) setState(() => _more = false);
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
        child: ListView.builder(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          itemCount: _items!.length + (_more ? 1 : 0),
          itemBuilder: (_, i) {
            if (i >= _items!.length) {
              return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
            }
            final u = _items![i];
            final id = (u['id'] as num).toInt();
            return Container(
              decoration: BoxDecoration(
                color: t.sf,
                border: Border.all(color: t.bd),
                borderRadius: BorderRadius.circular(18),
              ),
              margin: const EdgeInsets.only(bottom: 8),
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
                  busy: _busy.contains(id),
                  onPressed: () => _unblock(u),
                ),
              ]),
            );
          },
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
