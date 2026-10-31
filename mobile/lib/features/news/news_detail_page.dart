import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'icerik_parts.dart';
import 'news_tile.dart' show newsLocalDate, newsTypeIcon, newsTypeLabel, newsTypeTint;

/// Haber detayı: kapak (paylaşılan geçişle listeden uçar; üstünde geri/favori/paylaş, altında tür rozeti) ya da
/// kapaksız sade başlık; beyaz içerik kartı (tarih, başlık, metin, "içeriğin tamamı" notu, "Kaynak sayfada aç").
/// Veri: `GET /news/{id}`, `PUT/DELETE /bookmarks/news/{id}`.
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
  static const _coverHeight = 300.0;

  late Future<dynamic> _detail = _fetch();
  late bool _saved = widget.saved ?? false;
  final _scroll = ScrollController();

  /// Başlık daraldı mı (düğme/başlık görünümü değişir); yalnız eşik geçilince yeniden kurulur.
  final _collapsed = ValueNotifier<bool>(false);

  /// Kaynak bağlantısı açılamadıysa düğmenin altında satır içi hata gösterilir.
  bool _linkFailed = false;

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
    if (uri == null || uri.scheme != 'https') {
      setState(() => _linkFailed = true);
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) setState(() => _linkFailed = !ok);
    } catch (_) {
      if (mounted) setState(() => _linkFailed = true);
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
        final done = snap.connectionState == ConnectionState.done;
        final hasText = content != null && content.trim().isNotEmpty;
        final tint = newsTypeTint(t, type);
        final title = (n['title'] as String?) ?? '';
        final tx = Theme.of(context).textTheme;
        final badge = IcerikBadge(newsTypeLabel(context, type), soft: tint == null, tint: tint);
        final published = newsLocalDate(context, n['publishedDate'] as String?);

        Widget bodyChild;
        if (!done) {
          bodyChild = const _ArticleSkeleton();
        } else if (snap.hasError) {
          bodyChild = _NewsError(onRetry: () => setState(() {
            _detail = _fetch();
          }));
        } else {
          bodyChild = _Article(content: hasText ? content : null);
        }
        final showActions = done && !snap.hasError;

        return Scaffold(
          backgroundColor: t.bg,
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
                    surfaceTintColor: t.bg,
                    scrolledUnderElevation: 0,
                    // Kapak fotoğrafı üstteki karartmayla birlikte durum çubuğunun arkasındadır: saat/simgeler açık renk.
                    systemOverlayStyle: overlay
                        ? const SystemUiOverlayStyle(
                            statusBarColor: Colors.transparent,
                            statusBarIconBrightness: Brightness.light,
                            statusBarBrightness: Brightness.dark,
                          )
                        : null,
                    automaticallyImplyLeading: false,
                    leadingWidth: 72,
                    leading: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 16),
                      child: IcerikIconButton(
                          icon: buDirIcon(context, LucideIcons.arrowLeft),
                          label: l.commonBack,
                          overlay: overlay,
                          onTap: () => Navigator.pop(context)),
                    ),
                    // Daralınca ince alt çizgi belirir (içerik başlığın altından kayarken ayrışma).
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(1),
                      child: AnimatedOpacity(
                        key: const ValueKey('news-bar-hairline'),
                        opacity: collapsed ? 1 : 0,
                        duration: BuMotion.of(context, BuMotion.short),
                        child: Divider(height: 1, thickness: 1, color: t.bd),
                      ),
                    ),
                    // Başlık çubuğunda belirirken hafifçe yukarı kayar (yalnız opaklık + öteleme).
                    title: AnimatedSlide(
                      offset: Offset(0, collapsed ? 0 : .25),
                      duration: BuMotion.of(context, BuMotion.medium),
                      curve: BuMotion.emphasizedDecelerate,
                      child: AnimatedOpacity(
                        opacity: collapsed ? 1 : 0,
                        duration: BuMotion.of(context, BuMotion.medium),
                        child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(color: t.ink)),
                      ),
                    ),
                    centerTitle: false,
                    actions: [
                      IcerikIconButton(
                        key: const ValueKey('news-save'),
                        icon: _saved ? Icons.bookmark : LucideIcons.bookmark,
                        label: _saved ? l.newsSaveRemove : l.newsSaveAdd,
                        on: _saved,
                        toggled: _saved,
                        overlay: overlay,
                        onTap: _toggle,
                      ),
                      const SizedBox(width: 8),
                      IcerikIconButton(
                          key: const ValueKey('news-share'),
                          icon: LucideIcons.share2,
                          label: l.icerikShare,
                          overlay: overlay,
                          onTap: () => _share(url)),
                      const SizedBox(width: 16),
                    ],
                    flexibleSpace: hasCover
                        ? FlexibleSpaceBar(
                            collapseMode: CollapseMode.parallax,
                            stretchModes: const [StretchMode.zoomBackground],
                            background: Stack(fit: StackFit.expand, children: [
                              newsHero(
                                id: _id,
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
                              // Tür rozeti kapağın sol altında.
                              PositionedDirectional(start: 20, bottom: 36, child: badge),
                              // İçerik sayfasının yuvarlak üst kenarı (kapağın üstüne biner).
                              PositionedDirectional(
                                start: 0,
                                end: 0,
                                bottom: -1,
                                height: 24,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: t.bg,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                  padding: EdgeInsets.fromLTRB(20, hasCover ? 0 : 8, 20, MediaQuery.paddingOf(context).bottom + 32),
                  child: BuCard(
                    radius: 20,
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isEvent)
                            Row(children: [
                              Icon(newsTypeIcon(type), size: 16, color: t.pr),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(l.newsEventDate(newsLocalDate(context, eventDate)),
                                    style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w600, color: t.mut)),
                              ),
                            ])
                          else if (hasCover)
                            Row(children: [
                              Icon(LucideIcons.calendar, size: 16, color: t.pr),
                              const SizedBox(width: 8),
                              Expanded(child: Text(published, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w600, color: t.mut))),
                            ])
                          else
                            Row(children: [
                              Flexible(child: badge),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                  Icon(LucideIcons.calendar, size: 15, color: t.mut),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(published,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w600, color: t.mut)),
                                  ),
                                ]),
                              ),
                            ]),
                          const SizedBox(height: 14),
                          Semantics(
                            header: true,
                            child: Text(title, style: tx.headlineSmall!.copyWith(fontWeight: FontWeight.w800, height: 1.25, color: t.ink)),
                          ),
                          const SizedBox(height: 16),
                          BuFadeThrough(
                              key: const ValueKey('news-body'),
                              child: KeyedSubtree(key: ValueKey('body-$done-${snap.hasError}'), child: bodyChild)),
                          if (showActions) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.md)),
                              child: Row(children: [
                                Icon(LucideIcons.info, size: 18, color: t.mut),
                                const SizedBox(width: 12),
                                Expanded(child: Text(l.newsFullContent, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.4))),
                              ]),
                            ),
                            if (canOpen) ...[
                              const SizedBox(height: 16),
                              BuButton(
                                key: const ValueKey('news-open-source'),
                                label: l.p05NewsOpenSource,
                                icon: LucideIcons.externalLink,
                                kind: BuButtonKind.outline,
                                onPressed: () => _openOriginal(url),
                              ),
                              if (_linkFailed)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(BuRadius.md)),
                                    child: Row(children: [
                                      Icon(LucideIcons.triangleAlert, size: 18, color: t.onSoft),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Semantics(
                                          liveRegion: true,
                                          child: Text(l.newsLinkOpenFailed, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: t.onSoft)),
                                        ),
                                      ),
                                    ]),
                                  ),
                                ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// İçerik yüklenemedi kartı.
class _NewsError extends StatelessWidget {
  const _NewsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 8),
      ExcludeSemantics(
        child: Center(
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
              child: Icon(LucideIcons.wifiOff, size: 28, color: t.onSoft),
            ),
            PositionedDirectional(
              end: -6,
              bottom: -4,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle, border: Border.all(color: t.sf, width: 2)),
                child: Icon(LucideIcons.x, size: 13, color: t.onPr),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      Semantics(
        liveRegion: true,
        child: Text(l.p05NewsErrorTitle, textAlign: TextAlign.center, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
      ),
      const SizedBox(height: 6),
      Text(l.p05NewsErrorBody, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.45)),
      const SizedBox(height: 16),
      BuButton(label: l.commonRetry, icon: LucideIcons.refreshCw, onPressed: onRetry),
    ]);
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
            Row(children: [BuSkeleton.circle(32), SizedBox(width: 10), BuSkeleton.line(width: 140, height: 12)]),
            SizedBox(height: 18),
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
            SizedBox(height: 22),
            Row(children: [BuSkeleton.circle(32), SizedBox(width: 8), BuSkeleton.circle(32), Spacer(), BuSkeleton.line(width: 80, height: 12)]),
          ]),
        ),
      ),
    );
  }
}

/// Düz metni paragraf paragraf gösterir (satır sonlarıyla ayrılmış bloklar); içerik yoksa boş kalır.
class _Article extends StatelessWidget {
  const _Article({required this.content});

  final String? content;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final paragraphs = (content ?? '').split(RegExp(r'[\r\n]+')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (paragraphs.isEmpty) return const SizedBox.shrink();
    final style = tx.bodyLarge!.copyWith(fontWeight: FontWeight.w400, height: 1.6, color: t.ink);
    // SelectionArea: metin seçilip kopyalanabilir; SelectableText gibi sahte "dokunma hedefi" üretmez.
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < paragraphs.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == paragraphs.length - 1 ? 0 : 14),
              child: Text(paragraphs[i], style: style),
            ),
        ],
      ),
    );
  }
}
