import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../../core/typography.dart';

class NewsDetailPage extends StatefulWidget {
  const NewsDetailPage({
    super.key,
    required this.session,
    required this.item,
    this.saved,
    this.onToggleSave,
  });

  final Session session;
  final Map<String, dynamic> item;

  /// Favori durumu verilmezse (ana sayfadan açılış) kaydetme düğmesi çalışırken yüklenir.
  final bool? saved;
  final VoidCallback? onToggleSave;

  @override
  State<NewsDetailPage> createState() => _NewsDetailPageState();
}

class _NewsDetailPageState extends State<NewsDetailPage> {
  late Future<dynamic> _detail = _fetch();
  late bool _saved = widget.saved ?? false;

  int get _id => (widget.item['id'] as num).toInt();

  Future<dynamic> _fetch() => widget.session.api.get('/news/$_id');

  @override
  void initState() {
    super.initState();
    if (widget.saved == null) _loadSaved();
  }

  Future<void> _loadSaved() async {
    try {
      final r = await widget.session.api.get('/bookmarks/news/ids') as Map<String, dynamic>;
      if (mounted) setState(() => _saved = (r['ids'] as List).contains(_id));
    } catch (_) {}
  }

  Future<void> _toggle() async {
    if (widget.onToggleSave != null) {
      widget.onToggleSave!();
      setState(() => _saved = !_saved);
      return;
    }
    final was = _saved;
    setState(() => _saved = !was);
    try {
      if (was) {
        await widget.session.api.delete('/bookmarks/news/$_id');
      } else {
        await widget.session.api.put('/bookmarks/news/$_id');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saved = was);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
    }
  }

  /// Yalnızca https bağlantılar açılır.
  Future<void> _openOriginal(String? url) async {
    if (url == null) return;
    final uri = Uri.tryParse(url.startsWith('http://') ? url.replaceFirst('http://', 'https://') : url);
    if (uri == null || uri.scheme != 'https') return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Bağlantı açılamadı.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final n = widget.item;
    final type = n['type'] as String?;
    final img = n['imageUrl'] as String?;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(
            title: TypeBadge.label(type),
            onBack: () => Navigator.pop(context),
            actions: [
              BuIconButton(
                icon: _saved ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
                tooltip: _saved ? 'Favorilerden çıkar' : 'Favorilere ekle',
                filled: _saved,
                onTap: _toggle,
              ),
            ],
          ),
          Expanded(
            child: FutureBuilder(
              future: _detail,
              builder: (context, snap) {
                final d = snap.data is Map<String, dynamic> ? snap.data as Map<String, dynamic> : null;
                final content = d?['content'] as String?;
                final url = (d?['url'] ?? n['url']) as String?;
                final canOpen = url != null && (url.startsWith('https://') || url.startsWith('http://'));
                final eventDate = (d?['eventDate'] ?? n['eventDate']) as String?;
                final isEvent = type == 'ETKINLIK' && eventDate != null && eventDate.isNotEmpty;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  children: [
                    Row(children: [
                      BuBadge(TypeBadge.label(type), soft: type != 'HABER'),
                      const SizedBox(width: 10),
                      Text(niceDate(n['publishedDate'] as String?),
                          style: BuType.caption.copyWith(color: t.mut)),
                    ]),
                    if (isEvent) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        Icon(LucideIcons.calendar, size: 16, color: t.pr),
                        const SizedBox(width: 6),
                        Text('Etkinlik tarihi: ${niceDate(eventDate)}',
                            style: BuType.label.copyWith(color: t.ink)),
                      ]),
                    ],
                    const SizedBox(height: 14),
                    Text((n['title'] as String?) ?? '',
                        style: BuType.display.copyWith(height: 1.25, letterSpacing: -.3, color: t.ink)),
                    if (img != null && img.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(img,
                            width: double.infinity,
                            cacheWidth: 1000,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                      ),
                    ],
                    const SizedBox(height: 18),
                    if (snap.connectionState != ConnectionState.done)
                      const Padding(padding: EdgeInsets.all(24), child: LoadingView())
                    else if (snap.hasError)
                      SizedBox(
                        height: 260,
                        child: ErrorView(
                          error: snap.error!,
                          onRetry: () => setState(() {
                            _detail = _fetch();
                          }),
                        ),
                      )
                    else if (content != null && content.trim().isNotEmpty)
                      _Article(content: content)
                    else
                      BuCard(
                        child: Text('İçeriğin tamamı için kaynak sayfayı açın.',
                            style: BuType.body.copyWith(color: t.mut)),
                      ),
                    if (canOpen) ...[
                      const SizedBox(height: 24),
                      BuButton(
                        label: 'Kaynak sayfada aç',
                        icon: LucideIcons.externalLink,
                        kind: BuButtonKind.outline,
                        onPressed: () => _openOriginal(url),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Düz metni paragraf paragraf gösterir (boş satırlarla ayrılmış bloklar).
class _Article extends StatelessWidget {
  const _Article({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final paragraphs = content
        .split(RegExp(r'[\r\n]+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final style = BuType.heading.copyWith(height: 1.65, color: t.ink);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in paragraphs)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: SelectableText(p, style: style),
          ),
      ],
    );
  }
}
