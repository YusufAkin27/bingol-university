import 'package:flutter/material.dart';

import '../../core/theme.dart';

import '../../core/session.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../news/news_detail_page.dart';
import '../news/news_tile.dart';
import '../../core/typography.dart';

/// Favoriye eklenen haberler (imleçli sayfalama).
class SavedNewsPage extends StatefulWidget {
  const SavedNewsPage({super.key, required this.session});

  final Session session;

  @override
  State<SavedNewsPage> createState() => _SavedNewsPageState();
}

class _SavedNewsPageState extends State<SavedNewsPage> {
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
      final c = _cursor == null ? '' : '&cursor=$_cursor';
      final r = await widget.session.api.get('/bookmarks?size=20$c') as Map<String, dynamic>;
      for (final b in (r['items'] as List)) {
        final news = (b as Map<String, dynamic>)['news'];
        if (news is Map<String, dynamic>) _items.add(news);
      }
      _cursor = (r['nextCursor'] as num?)?.toInt();
      _hasMore = _cursor != null;
    } catch (e) {
      _error = e;
      _hasMore = false; // otomatik tekrar döngüsünü kes; "Yeniden dene" düğmesi açar
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _remove(Map<String, dynamic> n) async {
    final idx = _items.indexOf(n);
    setState(() => _items.remove(n));
    try {
      await widget.session.api.delete('/bookmarks/news/${n['id']}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _items.insert(idx.clamp(0, _items.length), n));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
    }
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
              : const EmptyView(
                  icon: LucideIcons.bookmark,
                  text: 'Henüz kaydettiğiniz bir haber yok. Haberlerdeki yer imi simgesine dokunun.');
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
            final n = _items[i];
            return NewsTile(
              item: n,
              saved: true,
              onToggleSave: () => _remove(n),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NewsDetailPage(session: widget.session, item: n, saved: true),
                ),
              ),
            );
          },
        ),
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(
            title: 'Kaydedilenler',
            onBack: () => Navigator.pop(context),
            actions: [
              if (_items.isNotEmpty)
                Text('${_items.length}${_hasMore ? '+' : ''} haber',
                    style: BuType.label.copyWith(color: t.mut)),
            ],
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
