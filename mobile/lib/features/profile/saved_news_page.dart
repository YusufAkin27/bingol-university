import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/locale_controller.dart';

import '../../core/session.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../news/news_detail_page.dart';
import '../news/icerik_parts.dart';
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
    final l = context.l10n;
    Widget body;
    if (_items.isEmpty) {
      body = _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(error: _error!, onRetry: _reload)
              : EmptyView(icon: LucideIcons.bookmark, text: l.profileSavedEmpty);
    } else {
      final bottom = MediaQuery.of(context).padding.bottom + 28;
      body = RefreshIndicator(
        color: t.pr,
        onRefresh: _reload,
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(20, 10, 20, bottom),
          itemCount: _items.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            if (i == _items.length) {
              if (_error != null) {
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Center(
                    child: BuButton(
                      label: l.profileRetry,
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
              if (!_hasMore) return const _SaveMoreHint();
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
              thumbSize: 72,
              showSource: false,
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
          IcerikHeader(title: l.icerikFavorites, backLabel: l.commonBack),
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(26, 10, 26, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                    _hasMore
                        ? l.profileNewsCountMore('${_items.length}')
                        : l.icerikSavedCount('${_items.length}'),
                    style: BuType.body.copyWith(fontSize: 13, color: t.mut)),
              ),
            ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Listenin sonunda kesikli çerçeveli ipucu kartı (Ic4).
class _SaveMoreHint extends StatelessWidget {
  const _SaveMoreHint();

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: CustomPaint(
        painter: _DashedBorder(color: t.bd, radius: 20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: SizedBox(
            width: double.infinity,
            child: Column(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
                child: Icon(LucideIcons.bookmark, size: 20, color: t.pr),
              ),
              const SizedBox(height: 8),
              Text(l.icerikSavedMoreTitle,
                  textAlign: TextAlign.center,
                  style: BuType.bodyStrong.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: t.ink)),
              const SizedBox(height: 2),
              Text(l.icerikSavedMoreBody,
                  textAlign: TextAlign.center,
                  style: BuType.body.copyWith(fontSize: 13, height: 1.4, color: t.mut)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)).deflate(.75));
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 6), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color || old.radius != radius;
}
