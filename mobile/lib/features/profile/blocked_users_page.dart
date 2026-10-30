import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'profil_widgets.dart' show ProfilCard;
import 'profily_widgets.dart';

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
    final id = ((u['id'] as num?)?.toInt() ?? -1);
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
    final l = context.l10n;
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
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            ProfilyEmptyCard(
              icon: LucideIcons.ban,
              title: l.profilyardBlockedEmptyTitle,
              body: l.profilyardBlockedEmptyBody,
            ),
          ],
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            ProfilyNote(text: l.profilyardBlockedNote),
            const SizedBox(height: 14),
            ProfilCard(children: [for (final u in _items!) _row(context, t, u)]),
            if (_more)
              const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(title: l.profilePrefsBlockedTitle, onBack: () => Navigator.pop(context)),
        Expanded(child: body),
      ]),
    );
  }

  Widget _row(BuildContext context, BuTokens t, Map<String, dynamic> u) {
    final id = ((u['id'] as num?)?.toInt() ?? -1);
    final name = (u['displayName'] as String?) ?? context.l10n.profilePrefsUser;
    final dept = (u['department'] as String?)?.trim();
    // Büyük yazıda ad sıkışıp kaybolmasın: düğme adın altına iner.
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13;
    final info = ProfilyTitleBlock(title: name, sub: (dept == null || dept.isEmpty) ? null : dept);
    final busy = _busy.contains(id);
    final unblockBtn = Semantics(
      button: true,
      label: context.l10n.profilyardUnblockOf(name),
      excludeSemantics: true,
      child: Material(
        color: t.sf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: t.bd, width: 1.5)),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onTap: busy ? null : () => _unblock(u),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 104),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: busy
                    ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: t.pr))
                    : Text(context.l10n.profilePrefsUnblock,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: t.pr)),
              ),
            ),
          ),
        ),
      ),
    );
    final avatar = BuAvatar(name: u['displayName'] as String?, url: u['avatarUrl'] as String?, size: 44);
    return ProfilyRow(
      minHeight: 72,
      child: stacked
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [avatar, const SizedBox(width: 12), Expanded(child: info)]),
              const SizedBox(height: 10),
              unblockBtn,
            ])
          : Row(children: [
              avatar,
              const SizedBox(width: 12),
              Expanded(child: info),
              const SizedBox(width: 8),
              unblockBtn,
            ]),
    );
  }
}
