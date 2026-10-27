import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../profile/user_profile_page.dart';

/// Gönderiyi beğenenler alt sayfası (`GET /posts/{id}/likes`, imleçli sonsuz kaydırma).
Future<void> showLikersSheet(BuildContext context, Session session, int postId, {int? total}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.bu.sf,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => LikersSheet(session: session, postId: postId, total: total),
  );
}

class LikersSheet extends StatefulWidget {
  const LikersSheet({super.key, required this.session, required this.postId, this.total});

  final Session session;
  final int postId;
  final int? total;

  @override
  State<LikersSheet> createState() => _LikersSheetState();
}

class _LikersSheetState extends State<LikersSheet> {
  final _items = <Map<String, dynamic>>[];
  final _scroll = ScrollController();
  String? _cursor;
  int? _total;
  bool _loading = true;
  bool _more = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _total = widget.total;
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) _loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String get _base => '/posts/${widget.postId}/likes?size=30';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.session.api.get(_base) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(((r['items'] as List?) ?? const []).cast<Map<String, dynamic>>());
        _cursor = r['nextCursor']?.toString();
        _total = (r['total'] as num?)?.toInt() ?? _total;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_cursor == null || _more || _loading) return;
    setState(() => _more = true);
    try {
      final r = await widget.session.api
          .get('$_base&cursor=${Uri.encodeQueryComponent(_cursor!)}') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _items.addAll(((r['items'] as List?) ?? const []).cast<Map<String, dynamic>>());
        _cursor = r['nextCursor']?.toString();
        _more = false;
      });
    } catch (_) {
      if (mounted) setState(() => _more = false);
    }
  }

  Map<String, String>? _headersFor(String? url) {
    final tok = widget.session.api.tokens?.access;
    return (tok != null && url != null && url.startsWith('/api/')) ? {'Authorization': 'Bearer $tok'} : null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final h = MediaQuery.sizeOf(context).height;
    final title = _total != null && _total! > 0 ? 'Beğenenler ($_total)' : 'Beğenenler';
    return SizedBox(
      height: h * .7,
      child: Column(children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: t.bd, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(title, style: BuType.title.copyWith(color: t.ink)),
          ),
        ),
        Divider(height: 1, color: t.bd),
        Expanded(child: _body(t)),
      ]),
    );
  }

  Widget _body(BuTokens t) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(errorText(_error!), textAlign: TextAlign.center, style: BuType.body.copyWith(color: t.mut)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Yeniden dene')),
          ]),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.heart, size: 36, color: t.mut),
            const SizedBox(height: 10),
            Text('Henüz beğenen yok', textAlign: TextAlign.center, style: BuType.body.copyWith(color: t.mut)),
          ]),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
      itemCount: _items.length + (_more ? 1 : 0),
      itemBuilder: (c, i) {
        if (i >= _items.length) {
          return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
        }
        final u = _items[i];
        final id = (u['id'] as num?)?.toInt();
        final name = (u['displayName'] as String?) ?? 'Kullanıcı';
        final avatar = u['avatarUrl'] as String?;
        return ListTile(
          key: ValueKey('liker-${id ?? i}'),
          onTap: id == null
              ? null
              : () {
                  final nav = Navigator.of(context);
                  final rootCtx = nav.context;
                  nav.pop();
                  openUserProfile(rootCtx, widget.session, userId: id, name: name, avatarUrl: avatar);
                },
          leading: BuAvatar(name: name, url: avatar, size: 40, headers: _headersFor(avatar)),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.bodyStrong.copyWith(color: t.ink)),
        );
      },
    );
  }
}
