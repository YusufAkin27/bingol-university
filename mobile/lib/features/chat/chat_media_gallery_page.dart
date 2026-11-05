import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'chat_info_media.dart';
import 'chat_info_parts.dart';
import 'chat_media_viewer.dart';

/// Sohbet medya galerisi: Fotoğraflar | Videolar | Dosyalar.
///
/// Backend'de ayrı medya listesi yoktur; [ChatMediaFeed] mesaj geçmişini sayfalayarak ekleri süzer.
/// Dosya mesajı (PDF/belge) sunucuda YOK (yalnız IMAGE/VIDEO): Dosyalar sekmesi sahte veri çizmez,
/// "desteklenmiyor" durumunu gösterir.
class ChatMediaGalleryPage extends StatefulWidget {
  const ChatMediaGalleryPage({
    super.key,
    required this.feed,
    required this.headers,
    required this.onOpen,
    this.initialTab = 0,
  });

  final ChatMediaFeed feed;
  final Map<String, String> headers;

  /// Karta dokununca: sekmedeki (süzülmüş) liste ve karonun sırası; görüntüleyiciyi çağıran açar.
  final void Function(List<ChatMediaItem> items, int index) onOpen;
  final int initialTab;

  @override
  State<ChatMediaGalleryPage> createState() => _ChatMediaGalleryPageState();
}

class _ChatMediaGalleryPageState extends State<ChatMediaGalleryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
      length: 3, vsync: this, initialIndex: widget.initialTab.clamp(0, 2));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        ChatInfoBar(title: l.chatInfoMediaFiles),
        Material(
          color: t.bg,
          child: TabBar(
            key: const ValueKey('chatMediaTabs'),
            controller: _tabs,
            dividerColor: t.bd,
            indicatorColor: t.pr,
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: t.ink,
            unselectedLabelColor: t.mut,
            labelStyle: chatInfoLabel14(context),
            unselectedLabelStyle:
                chatInfoLabel14(context).copyWith(fontWeight: BuType.emphasisWeight),
            overlayColor: WidgetStatePropertyAll(t.sf2),
            tabs: [
              Tab(text: l.chatInfoTabPhotos),
              Tab(text: l.chatInfoTabVideos),
              Tab(text: l.chatInfoTabFiles),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(controller: _tabs, children: [
            _GalleryGrid(
                feed: widget.feed,
                headers: widget.headers,
                video: false,
                onOpen: widget.onOpen),
            _GalleryGrid(
                feed: widget.feed,
                headers: widget.headers,
                video: true,
                onOpen: widget.onOpen),
            const _FilesUnsupported(),
          ]),
        ),
      ]),
    );
  }
}

/// Dosyalar sekmesi: dosya mesajı backend'de yok, sahte veri yok.
class _FilesUnsupported extends StatelessWidget {
  const _FilesUnsupported();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SingleChildScrollView(
      key: const ValueKey('chatMediaFilesUnsupported'),
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 16),
      child: ChatMediaEmptyCard(
          icon: BuIcons.fileText,
          title: l.chatInfoFilesUnsupportedTitle,
          body: l.chatInfoFilesUnsupportedBody),
    );
  }
}

/// Tek sekmenin ızgarası: kendi kaydırma konumunu korur, sonsuz kaydırmayla devamını ister.
class _GalleryGrid extends StatefulWidget {
  const _GalleryGrid(
      {required this.feed,
      required this.headers,
      required this.video,
      required this.onOpen});

  final ChatMediaFeed feed;
  final Map<String, String> headers;
  final bool video;
  final void Function(List<ChatMediaItem> items, int index) onOpen;

  @override
  State<_GalleryGrid> createState() => _GalleryGridState();
}

class _GalleryGridState extends State<_GalleryGrid>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();

  ChatMediaFeed get _f => widget.feed;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _f.addListener(_fill);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fill());
  }

  @override
  void dispose() {
    _f.removeListener(_fill);
    _scroll.dispose();
    super.dispose();
  }

  List<ChatMediaItem> get _mine =>
      [for (final i in _f.items) if (_f.isVideo(i) == widget.video) i];

  void _onScroll() {
    if (_scroll.hasClients &&
        _scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
      _f.load();
    }
  }

  /// Sekme ekranı doldurmuyorsa (ya da süzgeçte hiç öğe yoksa) kaydırma olmayacağından devamını kendimiz iste.
  void _fill() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_f.more ||
          _f.loadingMore ||
          _f.loading ||
          _f.moreError != null ||
          !_scroll.hasClients) {
        return;
      }
      if (_mine.isEmpty || _scroll.position.maxScrollExtent <= 0) _f.load();
    });
  }

  Widget _tail(BuildContext context, bool hasItems) {
    if (!hasItems) return const SizedBox.shrink();
    if (_f.moreError != null) {
      return Padding(
        padding: const EdgeInsets.all(kChatInfoMargin),
        child: Center(
          child: BuButton(
            label: context.l10n.chatInfoRetry,
            icon: BuIcons.refreshCw,
            kind: BuButtonKind.outline,
            compact: true,
            onPressed: () => _f.load(),
          ),
        ),
      );
    }
    if (!_f.more) return const SizedBox.shrink();
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(kChatInfoMargin, 8, kChatInfoMargin, 0),
      child: BuSkeletonScope(
        child: Row(children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            const Expanded(
                child: AspectRatio(
                    aspectRatio: 1,
                    child: BuSkeleton(radius: 8, height: 200))),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = context.l10n;
    final bottom = MediaQuery.paddingOf(context).bottom + 16;
    return ListenableBuilder(
      listenable: _f,
      builder: (context, _) {
        final mine = _mine;
        final empty = mine.isEmpty;
        final Widget? state = !empty
            ? null
            : _f.loading ||
                    (_f.more && _f.error == null && _f.moreError == null)
                ? const ChatMediaLoadingCard()
                : (_f.error != null || _f.moreError != null)
                    ? ChatMediaErrorCard(
                        onRetry: () => _f.error != null
                            ? _f.load(first: true)
                            : _f.load())
                    : ChatMediaEmptyCard(
                        icon: widget.video ? BuIcons.video : BuIcons.images,
                        title: widget.video
                            ? l.chatInfoNoVideos
                            : l.chatInfoNoPhotos,
                        body: l.p09MediaEmptyBody);
        return CustomScrollView(
          controller: _scroll,
          slivers: [
            if (state != null)
              SliverToBoxAdapter(child: state)
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    kChatInfoMargin, 8, kChatInfoMargin, 0),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (c, i) => ChatInfoThumb(
                        item: mine[i],
                        video: widget.video,
                        durationMs: _f.videoMeta[mine[i].url],
                        radius: 8,
                        headers: widget.headers,
                        onTap: () => widget.onOpen(mine, i)),
                    childCount: mine.length,
                  ),
                ),
              ),
            SliverToBoxAdapter(child: _tail(context, !empty)),
            SliverToBoxAdapter(child: SizedBox(height: bottom)),
          ],
        );
      },
    );
  }
}
