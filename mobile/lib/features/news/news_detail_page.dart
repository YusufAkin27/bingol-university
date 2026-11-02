import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/analytics.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'icerik_parts.dart';
import 'news_tile.dart' show newsLocalDate, newsSourceHost, newsTypeLabel;

/// Haber detayı (okuma düzeni): kapak (paylaşılan geçişle listeden uçar; üstünde geri/favori/paylaş) ya da kapaksız sade
/// başlık; kartsız tek sütun: soluk meta satırı (tür • tarih), başlık, gövde metni (okunur satır uzunluğu), "Kaynak sayfada aç".
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
  static const _coverHeight = 240.0;

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
    Analytics.instance.track(widget.item['type'] == 'DUYURU' ? 'announcement_open' : 'news_open', props: {'kind': widget.item['type'] == 'ETKINLIK' ? 'event' : 'news'});
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
      if (!was) Analytics.instance.track('favorite_add', props: {'kind': 'news'});
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
    Analytics.instance.track('share', props: {'kind': 'news'});
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
        final title = (n['title'] as String?) ?? '';
        final tx = Theme.of(context).textTheme;
        final host = newsSourceHost({'url': url});
        // Tür etiketi (büyük harf, soluk) + tarih satırı: "26 Ekim 2026 · bingol.edu.tr" (etkinlikte "Etkinlik tarihi: ...").
        final typeText = trUpper(newsTypeLabel(context, type));
        final dateLine = isEvent
            ? l.newsEventDate(newsLocalDate(context, eventDate))
            : '${newsLocalDate(context, n['publishedDate'] as String?)} · $host';

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

        final topInset = MediaQuery.paddingOf(context).top;
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
                    // Kapak toplam 240 dp (durum çubuğu dahil); düğmeler üstten 16 dp + güvenli alan.
                    expandedHeight: hasCover ? _coverHeight - topInset : null,
                    toolbarHeight: hasCover ? 72 : 56,
                    backgroundColor: t.bg,
                    surfaceTintColor: t.bg,
                    scrolledUnderElevation: 0,
                    automaticallyImplyLeading: false,
                    leadingWidth: 64,
                    leading: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 16),
                      child: IcerikIconButton(
                          icon: buDirIcon(context, BuIcons.arrowLeft),
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
                        icon: _saved ? BuIcons.bookmarkFilled : BuIcons.bookmark,
                        label: _saved ? l.newsSaveRemove : l.newsSaveAdd,
                        on: _saved,
                        toggled: _saved,
                        overlay: overlay,
                        onTap: _toggle,
                      ),
                      IcerikIconButton(
                          key: const ValueKey('news-share'),
                          icon: BuIcons.share2,
                          label: l.icerikShare,
                          overlay: overlay,
                          onTap: () => _share(url)),
                      const SizedBox(width: 16),
                    ],
                    flexibleSpace: hasCover
                        ? FlexibleSpaceBar(
                            collapseMode: CollapseMode.parallax,
                            stretchModes: const [StretchMode.zoomBackground],
                            background: newsHero(
                              id: _id,
                              radius: 0,
                              child: SizedBox.expand(
                                child: BuImage(img, width: double.infinity, height: double.infinity, maxDecodeWidth: 1400),
                              ),
                            ),
                          )
                        : null,
                  );
                },
              ),
              SliverToBoxAdapter(
                child: Align(
                  alignment: AlignmentDirectional.topCenter,
                  // Okunur satır uzunluğu: geniş ekranda gövde en çok 640 dp.
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, hasCover ? 24 : 16, 20, MediaQuery.paddingOf(context).bottom + 32),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (typeText.isNotEmpty)
                              Text(typeText,
                                  style: tx.labelMedium!.copyWith(
                                      fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: _isArabic ? 0 : .6, color: t.mut)),
                            const SizedBox(height: 8),
                            Semantics(
                              header: true,
                              child: Text(title, style: tx.headlineSmall!.copyWith(fontSize: 26, fontWeight: FontWeight.w700, height: 1.25, color: t.ink)),
                            ),
                            const SizedBox(height: 8),
                            Text(dateLine, style: tx.bodySmall!.copyWith(fontSize: 13, color: t.mut)),
                            const SizedBox(height: 24),
                            BuFadeThrough(
                                key: const ValueKey('news-body'),
                                child: KeyedSubtree(key: ValueKey('body-$done-${snap.hasError}'), child: bodyChild)),
                            if (showActions) ...[
                              const SizedBox(height: 32),
                              Text(l.newsFullContent, style: tx.bodySmall!.copyWith(fontSize: 13, color: t.mut)),
                              if (canOpen) ...[
                                const SizedBox(height: 8),
                                _SourceButton(
                                  key: const ValueKey('news-open-source'),
                                  label: l.p05NewsOpenSource,
                                  onPressed: () => _openOriginal(url),
                                ),
                                if (_linkFailed)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Semantics(
                                      liveRegion: true,
                                      child: Text(l.newsLinkOpenFailed, style: tx.bodySmall!.copyWith(fontSize: 13, color: t.danger)),
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
              ),
            ],
          ),
        );
      },
    );
  }

  bool get _isArabic => LocaleController.current?.locale.languageCode == 'ar';
}

/// "Kaynak sayfada aç": 48 dp yüksek, beyaz yüzey, 1 dp `bdStrong` çerçeve, 16 köşe, ortalı ink metin (14 sp/600).
class _SourceButton extends StatelessWidget {
  const _SourceButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: BuPressable(
        scale: .98,
        onTap: () {
          buHaptic(BuHaptic.selection);
          onPressed();
        },
        child: Container(
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: t.sf,
            borderRadius: BorderRadius.circular(BuRadius.md),
            border: Border.all(color: t.bdStrong),
          ),
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: t.ink)),
        ),
      ),
    );
  }
}

/// İçerik yüklenemedi: soluk tek cümle + marka renkli metin düğmesi ("Yeniden dene"); simge yok.
class _NewsError extends StatelessWidget {
  const _NewsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return IcerikErrorCard(title: l.p05NewsErrorTitle, retryLabel: l.commonRetry, onRetry: onRetry);
  }
}

/// Makale yüklenirken satır iskeleti: yalnız iki paragraf (gövde satırları).
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
            BuSkeleton.line(width: 160, height: 14),
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
    final style = tx.bodyLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5, color: t.ink);
    // SelectionArea: metin seçilip kopyalanabilir; SelectableText gibi sahte "dokunma hedefi" üretmez.
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < paragraphs.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == paragraphs.length - 1 ? 0 : 16),
              child: Text(paragraphs[i], style: style),
            ),
        ],
      ),
    );
  }
}
