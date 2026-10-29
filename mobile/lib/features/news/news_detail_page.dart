import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'icerik_parts.dart';
import 'news_tile.dart' show newsLocalDate, newsSourceHost, newsTypeIcon, newsTypeLabel, newsTypeTint;

/// Haber detayı (Ic3): kapak (paylaşılan geçişle listeden uçar) + kaydırınca daralan başlık, okuma süresi,
/// makale metni, altta "Kaynak sitede aç" çubuğu. Veri: `GET /news/{id}`, `PUT/DELETE /bookmarks/news/{id}`.
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
  static const _coverHeight = 320.0;

  late Future<dynamic> _detail = _fetch();
  late bool _saved = widget.saved ?? false;
  final _scroll = ScrollController();

  /// Başlık daraldı mı (düğme/başlık görünümü değişir); yalnız eşik geçilince yeniden kurulur.
  final _collapsed = ValueNotifier<bool>(false);

  int get _id => (widget.item['id'] as num).toInt();

  Future<dynamic> _fetch() => widget.session.api.get('/news/$_id');

  bool get _hasCover {
    final img = widget.item['imageUrl'] as String?;
    return img != null && img.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    if (widget.saved == null) _loadSaved();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _collapsed.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final limit = _hasCover ? _coverHeight - kToolbarHeight - MediaQuery.paddingOf(context).top - 24 : 8;
    final c = _scroll.offset > limit;
    if (c != _collapsed.value) _collapsed.value = c;
  }

  Future<void> _loadSaved() async {
    try {
      final r = await widget.session.api.get('/bookmarks/news/ids') as Map<String, dynamic>;
      if (mounted) setState(() => _saved = (r['ids'] as List).contains(_id));
    } catch (_) {}
  }

  Future<void> _toggle() async {
    final l = context.l10n;
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
      if (mounted) BuToast.show(context, was ? l.p05UnsavedToast : l.p05SavedToast, kind: BuToastKind.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saved = was);
      BuToast.show(context, errorText(e), kind: BuToastKind.error);
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
      BuToast.show(context, context.l10n.newsLinkOpenFailed, kind: BuToastKind.error);
    }
  }

  /// Paylaşım paketi olmadığından haber bağlantısı panoya kopyalanır.
  Future<void> _share(String? url) async {
    final n = widget.item;
    final text = (url != null && url.isNotEmpty) ? url : ((n['title'] as String?) ?? '');
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    BuToast.show(context, context.l10n.icerikLinkCopied, kind: BuToastKind.success);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final n = widget.item;
    final type = n['type'] as String?;
    final img = n['imageUrl'] as String?;
    final hasCover = _hasCover;
    return FutureBuilder(
      future: _detail,
      builder: (context, snap) {
        final d = snap.data is Map<String, dynamic> ? snap.data as Map<String, dynamic> : null;
        final content = d?['content'] as String?;
        final url = (d?['url'] ?? n['url']) as String?;
        final canOpen = url != null && (url.startsWith('https://') || url.startsWith('http://'));
        final eventDate = (d?['eventDate'] ?? n['eventDate']) as String?;
        final isEvent = type == 'ETKINLIK' && eventDate != null && eventDate.isNotEmpty;
        final source = newsSourceHost({'url': url});
        final done = snap.connectionState == ConnectionState.done;
        final hasText = content != null && content.trim().isNotEmpty;
        final minutes = hasText ? _readMinutes(content) : 0;
        final tint = newsTypeTint(t, type);
        final title = (n['title'] as String?) ?? '';
        final tx = Theme.of(context).textTheme;

        Widget bodyChild;
        if (!done) {
          bodyChild = const _ArticleSkeleton();
        } else if (snap.hasError) {
          bodyChild = SizedBox(
            height: 280,
            child: BuErrorState(
              error: snap.error,
              compact: true,
              onRetry: () => setState(() {
                _detail = _fetch();
              }),
            ),
          );
        } else if (hasText) {
          bodyChild = _Article(content: content, source: source);
        } else {
          bodyChild = Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.md)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(LucideIcons.info, size: 18, color: t.mut),
              const SizedBox(width: 12),
              Expanded(child: Text(l.newsFullContent, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.45))),
            ]),
          );
        }

        return Scaffold(
          backgroundColor: t.bg,
          bottomNavigationBar: canOpen
              ? DecoratedBox(
                  decoration: BoxDecoration(color: t.bg, border: Border(top: BorderSide(color: t.bd))),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: BuButton(
                        key: const ValueKey('news-open-source'),
                        label: l.icerikOpenSource,
                        icon: LucideIcons.externalLink,
                        onPressed: () => _openOriginal(url),
                      ),
                    ),
                  ),
                )
              : null,
          body: CustomScrollView(
            controller: _scroll,
            slivers: [
              ValueListenableBuilder<bool>(
                valueListenable: _collapsed,
                builder: (context, collapsed, _) {
                  final overlay = hasCover && !collapsed;
                  return SliverAppBar(
                    pinned: true,
                    stretch: hasCover,
                    expandedHeight: hasCover ? _coverHeight : null,
                    backgroundColor: t.bg,
                    surfaceTintColor: Colors.transparent,
                    scrolledUnderElevation: 0,
                    automaticallyImplyLeading: false,
                    leadingWidth: 64,
                    leading: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8),
                      child: IcerikIconButton(
                          icon: buDirIcon(context, LucideIcons.arrowLeft),
                          label: l.commonBack,
                          overlay: overlay,
                          onTap: () => Navigator.pop(context)),
                    ),
                    title: AnimatedOpacity(
                      opacity: collapsed ? 1 : 0,
                      duration: BuMotion.of(context, BuMotion.medium),
                      child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(color: t.ink)),
                    ),
                    centerTitle: false,
                    actions: [
                      IcerikIconButton(
                        key: const ValueKey('news-save'),
                        icon: _saved ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
                        label: _saved ? l.newsSaveRemove : l.newsSaveAdd,
                        on: _saved,
                        toggled: _saved,
                        overlay: overlay,
                        onTap: _toggle,
                      ),
                      IcerikIconButton(
                          key: const ValueKey('news-share'),
                          icon: LucideIcons.share,
                          label: l.icerikShare,
                          overlay: overlay,
                          onTap: () => _share(url)),
                      const SizedBox(width: 8),
                    ],
                    flexibleSpace: hasCover
                        ? FlexibleSpaceBar(
                            collapseMode: CollapseMode.parallax,
                            stretchModes: const [StretchMode.zoomBackground],
                            background: Stack(fit: StackFit.expand, children: [
                              Hero(
                                tag: 'news-img-$_id',
                                child: SizedBox.expand(
                                  child: BuImage(img, width: double.infinity, height: double.infinity, maxDecodeWidth: 1400),
                                ),
                              ),
                              // Geri/kaydet/paylaş simgelerinin okunması için üstte durağan karartma.
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: 120,
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [t.scrim.withValues(alpha: .5), t.scrim.withValues(alpha: 0)],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // İçerik sayfasının yuvarlak üst kenarı (kapağın üstüne biner).
                              PositionedDirectional(
                                start: 0,
                                end: 0,
                                bottom: -1,
                                height: 28,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: t.bg,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                                  ),
                                ),
                              ),
                            ]),
                          )
                        : null,
                  );
                },
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, hasCover ? 0 : 4, 20, MediaQuery.paddingOf(context).bottom + 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        IcerikBadge(newsTypeLabel(context, type), soft: tint == null, tint: tint),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(LucideIcons.clock, size: 13, color: t.mut),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text('${newsLocalDate(context, n['publishedDate'] as String?)} · $source',
                                style: tx.bodySmall!.copyWith(color: t.mut)),
                          ),
                        ]),
                        if (minutes > 0)
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(LucideIcons.bookOpen, size: 13, color: t.mut),
                            const SizedBox(width: 5),
                            Text(l.p05ReadMinutes('$minutes'), style: tx.bodySmall!.copyWith(color: t.mut)),
                          ]),
                      ]),
                      if (isEvent) ...[
                        const SizedBox(height: 14),
                        _EventDateChip(text: l.newsEventDate(newsLocalDate(context, eventDate)), icon: newsTypeIcon(type)),
                      ],
                      const SizedBox(height: 14),
                      Semantics(
                        header: true,
                        child: Text(title, style: tx.headlineSmall!.copyWith(fontWeight: FontWeight.w800, height: 1.25, color: t.ink)),
                      ),
                      const SizedBox(height: 18),
                      BuFadeThrough(key: const ValueKey('news-body'), child: KeyedSubtree(key: ValueKey('body-$done-${snap.hasError}'), child: bodyChild)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Dakikada ~200 sözcük; en az 1.
  int _readMinutes(String text) {
    final words = text.trim().split(RegExp(r'\s+')).length;
    return (words / 200).ceil().clamp(1, 99);
  }
}

/// Etkinlik tarihi vurgusu (yeşil ton).
class _EventDateChip extends StatelessWidget {
  const _EventDateChip({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tint = t.tint(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: tint.bg, borderRadius: BorderRadius.circular(BuRadius.md)),
      child: Row(children: [
        Icon(icon, size: 18, color: tint.fg),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: tint.fg)),
        ),
      ]),
    );
  }
}

/// Makale yüklenirken satır iskeleti.
class _ArticleSkeleton extends StatelessWidget {
  const _ArticleSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: context.l10n.commonLoading,
      child: const ExcludeSemantics(
        child: BuSkeletonScope(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            BuSkeleton.line(height: 14),
            SizedBox(height: 10),
            BuSkeleton.line(height: 14),
            SizedBox(height: 10),
            BuSkeleton.line(width: 220, height: 14),
            SizedBox(height: 26),
            BuSkeleton.line(height: 14),
            SizedBox(height: 10),
            BuSkeleton.line(height: 14),
            SizedBox(height: 10),
            BuSkeleton.line(height: 14),
            SizedBox(height: 10),
            BuSkeleton.line(width: 160, height: 14),
          ]),
        ),
      ),
    );
  }
}

// Düz metni paragraf paragraf gösterir (boş satırlarla ayrılmış bloklar); ilk paragraf öne çıkarılır.
class _Article extends StatelessWidget {
  const _Article({required this.content, required this.source});

  final String content;
  final String source;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final paragraphs = content.split(RegExp(r'[\r\n]+')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    // Uzun okuma metni: normal ağırlık, rahat satır aralığı; ilk paragraf biraz daha vurgulu.
    final lead = tx.titleMedium!.copyWith(fontWeight: FontWeight.w500, height: 1.6, color: t.ink);
    final style = tx.bodyLarge!.copyWith(fontWeight: FontWeight.w400, height: 1.7, color: t.ink);
    // SelectionArea: metin seçilip kopyalanabilir; SelectableText gibi sahte "dokunma hedefi" üretmez.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < paragraphs.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(paragraphs[i], style: i == 0 ? lead : style),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(BuRadius.md), border: Border.all(color: t.bd)),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(BuRadius.sm)),
              child: Icon(LucideIcons.globe, size: 18, color: t.onSoft),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.p05Source, style: tx.labelSmall!.copyWith(color: t.mut)),
                Text(source, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(color: t.ink)),
              ]),
            ),
          ]),
        ),
      ],
    );
  }
}
