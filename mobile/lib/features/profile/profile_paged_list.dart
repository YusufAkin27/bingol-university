import 'package:flutter/material.dart';

import '../../core/theme.dart';

import '../../core/session.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';

/// Profil alt sayfaları için ortak imleçli liste iskeleti (başlık + yenile + sonsuz kaydırma).
class ProfilePagedList extends StatefulWidget {
  const ProfilePagedList({
    super.key,
    required this.session,
    required this.title,
    required this.path,
    required this.emptyIcon,
    required this.emptyText,
    required this.itemBuilder,
  });

  final Session session;
  final String title;
  final String path;
  final IconData emptyIcon;
  final String emptyText;
  final Widget Function(BuildContext context, Map<String, dynamic> item) itemBuilder;

  @override
  State<ProfilePagedList> createState() => _ProfilePagedListState();
}

class _ProfilePagedListState extends State<ProfilePagedList> {
  final _items = <Map<String, dynamic>>[];
  int? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _reload() async {
    setState(() {
      _items.clear();
      _cursor = null;
      _hasMore = true;
      _error = null;
      _loading = false;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sep = widget.path.contains('?') ? '&' : '?';
      final c = _cursor == null ? '' : '&cursor=$_cursor';
      final r = await widget.session.api.get('${widget.path}${sep}size=20$c') as Map<String, dynamic>;
      for (final e in (r['items'] as List? ?? const [])) {
        if (e is Map<String, dynamic>) _items.add(e);
      }
      _cursor = (r['nextCursor'] as num?)?.toInt();
      _hasMore = _cursor != null;
    } catch (e) {
      _error = e;
      _hasMore = false;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    Widget body;
    if (_items.isEmpty) {
      body = _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(error: _error!, onRetry: _reload)
              : EmptyView(icon: widget.emptyIcon, text: widget.emptyText);
    } else {
      body = RefreshIndicator(
        color: t.pr,
        onRefresh: _reload,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          itemCount: _items.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            if (i == _items.length) {
              if (_error != null) {
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Center(
                    child: BuButton(
                      label: 'Yeniden dene',
                      compact: true,
                      kind: BuButtonKind.outline,
                      onPressed: () {
                        setState(() => _hasMore = true);
                        _loadMore();
                      },
                    ),
                  ),
                );
              }
              if (!_hasMore) return const SizedBox.shrink();
              WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
              );
            }
            return widget.itemBuilder(context, _items[i]);
          },
        ),
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(title: widget.title, onBack: () => Navigator.pop(context)),
          Expanded(child: body),
        ],
      ),
    );
  }
}
