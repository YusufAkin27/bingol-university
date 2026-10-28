import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../../core/typography.dart';
import 'icerik_parts.dart';
import 'news_tile.dart' show newsLocalDate, newsSourceHost, newsTypeLabel;

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
          .showSnackBar(SnackBar(content: Text(context.l10n.newsLinkOpenFailed)));
    }
  }

  /// Paylaşım paketi olmadığından haber bağlantısı panoya kopyalanır.
  Future<void> _share(String? url) async {
    final n = widget.item;
    final text = (url != null && url.isNotEmpty) ? url : ((n['title'] as String?) ?? '');
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.icerikLinkCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final n = widget.item;
    final type = n['type'] as String?;
    final img = n['imageUrl'] as String?;
    final hasCover = img != null && img.isNotEmpty;
    final top = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: t.bg,
      body: FutureBuilder(
        future: _detail,
        builder: (context, snap) {
          final d = snap.data is Map<String, dynamic> ? snap.data as Map<String, dynamic> : null;
          final content = d?['content'] as String?;
          final url = (d?['url'] ?? n['url']) as String?;
          final canOpen = url != null && (url.startsWith('https://') || url.startsWith('http://'));
          final eventDate = (d?['eventDate'] ?? n['eventDate']) as String?;
          final isEvent = type == 'ETKINLIK' && eventDate != null && eventDate.isNotEmpty;
          final source = newsSourceHost({'url': url});
          // Kapak varsa içerik kartı 270 dp'den başlar; yoksa düğme satırının altından.
          final gap = hasCover ? 270.0 : top + 72;
          return Stack(
            children: [
              if (hasCover)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 300,
                  child: Stack(fit: StackFit.expand, children: [
                    ColoredBox(color: t.sf2),
                    Image.network(img,
                        cacheWidth: 1000,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                    const Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: 110,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x800A0E1C), Color(0x000A0E1C)],
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(top: gap),
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - gap),
                    padding: EdgeInsets.fromLTRB(20, 22, 20, 120 + bottomInset),
                    decoration: BoxDecoration(
                      color: t.bg,
                      borderRadius: hasCover ? const BorderRadius.vertical(top: Radius.circular(28)) : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          IcerikBadge(newsTypeLabel(context, type), soft: type != 'HABER'),
                          Text('${newsLocalDate(context, n['publishedDate'] as String?)} · $source',
                              style: BuType.body.copyWith(fontSize: 13, color: t.mut)),
                        ]),
                        if (isEvent) ...[
                          const SizedBox(height: 10),
                          Row(children: [
                            Icon(LucideIcons.calendar, size: 14.5, color: t.pr),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(l.newsEventDate(newsLocalDate(context, eventDate)),
                                  style: BuType.label.copyWith(color: t.ink)),
                            ),
                          ]),
                        ],
                        const SizedBox(height: 12),
                        Semantics(
                          header: true,
                          child: Text((n['title'] as String?) ?? '',
                              style: BuType.display
                                  .copyWith(fontSize: 24, height: 1.25, letterSpacing: -.4, color: t.ink)),
                        ),
                        const SizedBox(height: 14),
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
                            child: Text(l.newsFullContent, style: BuType.body.copyWith(color: t.mut)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (canOpen)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        stops: const [.55, 1],
                        colors: [t.bg, t.bg.withValues(alpha: 0)],
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 36, 20, 24 + bottomInset),
                      child: _SourceButton(label: l.icerikOpenSource, onTap: () => _openOriginal(url)),
                    ),
                  ),
                ),
              Positioned(
                left: 20,
                right: 20,
                top: top + 8,
                child: Row(children: [
                  IcerikIconButton(
                      icon: buDirIcon(context, LucideIcons.arrowLeft),
                      label: l.commonBack,
                      shadow: true,
                      onTap: () => Navigator.pop(context)),
                  const Spacer(),
                  IcerikIconButton(
                    key: const ValueKey('news-save'),
                    icon: _saved ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
                    label: _saved ? l.newsSaveRemove : l.newsSaveAdd,
                    on: _saved,
                    toggled: _saved,
                    onTap: _toggle,
                  ),
                  const SizedBox(width: 10),
                  IcerikIconButton(
                      key: const ValueKey('news-share'),
                      icon: LucideIcons.share,
                      label: l.icerikShare,
                      onTap: () => _share(url)),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.pr,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: t.pr.withValues(alpha: .6), blurRadius: 26, offset: const Offset(0, 14), spreadRadius: -12)],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            key: const ValueKey('news-open-source'),
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: SizedBox(
              height: 56,
              width: double.infinity,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(LucideIcons.externalLink, size: 20, color: t.onPr),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BuType.heading.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: t.onPr)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// Düz metni paragraf paragraf gösterir (boş satırlarla ayrılmış bloklar).
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
    // Uzun okuma metni: kalın değil normal ağırlık.
    final style = BuType.body.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.6, color: t.ink);
    // SelectionArea: metin seçilip kopyalanabilir; SelectableText gibi sahte "dokunma hedefi" üretmez.
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(p, style: style),
            ),
        ],
      ),
    );
  }
}
