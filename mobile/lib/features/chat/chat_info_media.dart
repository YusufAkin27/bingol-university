import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'chat_info_parts.dart';
import 'chat_media_viewer.dart';
import 'message_bubble.dart' show chatMediaUrl;

/// Sohbet görsellerini mesaj geçmişini sayfalayarak süzer (backend'de ayrı medya listesi yok).
/// Her yüklemede en çok [batch] görsel toplanır, istek sayısı [maxRequestsPerLoad] ile sınırlıdır.
/// Tek gösterimlik (`viewOnce`) ekler listeye girmez.
class ChatMediaFeed extends ChangeNotifier {
  ChatMediaFeed(
      {required this.api,
      required this.conversationId,
      required this.senderName});

  static const batch = 30;
  static const pageSize = 40;
  static const maxRequestsPerLoad = 8;

  final ApiClient api;
  final int conversationId;
  final String? Function(Map<String, dynamic> message) senderName;

  final items = <ChatMediaItem>[];
  final _seen = <int>{};
  int? _cursor;
  bool more = true;
  bool loading = true;
  bool loadingMore = false;
  Object? error;
  Object? moreError;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Video ekleri: öğe URL'si -> süre (ms, bilinmiyorsa null). Ham ek haritasından türetilir;
  /// `ChatMediaItem` alanlarına bağımlı değildir.
  final videoMeta = <String, int?>{};

  bool isVideo(ChatMediaItem item) => videoMeta.containsKey(item.url);

  void _collect(List raw) {
    for (final r in raw) {
      if (r is! Map) continue;
      final m = Map<String, dynamic>.from(r);
      if (m['deleted'] == true || m['removed'] == true) continue;
      final at =
          DateTime.tryParse((m['createdAt'] as String?) ?? '')?.toLocal();
      for (final a
          in (m['attachments'] as List? ?? const []).whereType<Map>()) {
        if (a['removed'] == true || a['viewOnce'] == true) continue;
        final url = (a['url'] ?? a['thumbUrl']) as String?;
        if (url == null) continue;
        final aid = (a['id'] as num?)?.toInt();
        if (aid != null && !_seen.add(aid)) continue;
        if (a['kind'] == 'VIDEO') {
          videoMeta[url] = (a['durationMs'] as num?)?.toInt();
        }
        items.add(ChatMediaItem(
          url: url,
          thumbUrl: (a['thumbUrl'] ?? a['url']) as String?,
          sender: senderName(m),
          at: at,
          id: aid,
        ));
      }
    }
  }

  /// [first]: baştan yükle. [want]: bu yüklemede hedeflenen ek görsel sayısı.
  Future<void> load({bool first = false, int want = batch}) async {
    if (loadingMore && !first) return;
    if (!first && (!more || loading || error != null)) return;
    if (first) {
      loading = true;
      error = null;
      items.clear();
      _seen.clear();
      _cursor = null;
      more = true;
    } else {
      loadingMore = true;
      moreError = null;
    }
    _notify();
    final target = items.length + want;
    try {
      var requests = 0;
      while (more && items.length < target && requests < maxRequestsPerLoad) {
        final q = _cursor == null ? '' : '&before=$_cursor';
        final page = await api
                .get('/conversations/$conversationId/messages?size=$pageSize$q')
            as Map<String, dynamic>;
        if (_disposed) return;
        _collect(page['items'] as List? ?? const []);
        _cursor = (page['nextCursor'] as num?)?.toInt();
        more = _cursor != null;
        requests++;
      }
      loading = false;
      loadingMore = false;
    } catch (e) {
      if (_disposed) return;
      if (first) {
        error = e;
      } else {
        moreError = e;
      }
      loading = false;
      loadingMore = false;
    }
    _notify();
  }
}

/// Küçük kare görsel önizlemesi. Video: ortada oynat dairesi + sağ altta süre; [moreCount] doluysa
/// üstte "+N" örtüsü (önizleme şeridinin son karosu).
class ChatInfoThumb extends StatelessWidget {
  const ChatInfoThumb(
      {super.key,
      required this.item,
      required this.headers,
      required this.onTap,
      this.video = false,
      this.durationMs,
      this.radius = 12,
      this.moreCount});

  final ChatMediaItem item;
  final Map<String, String> headers;
  final VoidCallback onTap;

  /// Video küçük resmi: oynat ikonu + süre hapı.
  final bool video;
  final int? durationMs;

  /// Köşe yarıçapı (önizleme 12, tam ızgara 8).
  final double radius;

  /// Doluysa karonun üstüne "+N" örtüsü çizilir.
  final int? moreCount;

  static String formatDuration(int ms) {
    final s = (ms / 1000).round();
    final m = s ~/ 60;
    return '$m:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: video ? context.l10n.chatInfoOpenVideo : context.l10n.chatInfoOpenImage,
      child: BuPressable(
        onTap: onTap,
        scale: .97,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: ColoredBox(
            color: t.sf2,
            child: Stack(fit: StackFit.expand, children: [
              Image.network(
                chatMediaUrl(item.thumbUrl ?? item.url),
                headers: headers,
                fit: BoxFit.cover,
                cacheWidth: 360,
                gaplessPlayback: true,
                errorBuilder: (c, e, s) => Center(child: Icon(LucideIcons.imageOff, color: t.mut)),
              ),
              if (video) ...[
                ColoredBox(color: t.scrim.withValues(alpha: .2)),
                Center(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: t.scrim.withValues(alpha: .6), shape: BoxShape.circle),
                    child: Icon(Icons.play_arrow_rounded, size: 22, color: t.onMedia),
                  ),
                ),
                if (durationMs != null)
                  PositionedDirectional(
                    end: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: t.scrim.withValues(alpha: .7), borderRadius: BorderRadius.circular(4)),
                      child: Text(formatDuration(durationMs!),
                          style: tx.labelSmall!.copyWith(color: t.onMedia, fontWeight: FontWeight.w700, height: 1.2)),
                    ),
                  ),
              ],
              if (moreCount != null)
                ColoredBox(
                  color: t.scrim.withValues(alpha: .4),
                  child: Center(
                    child: Text('+$moreCount', style: tx.labelLarge!.copyWith(color: t.onMedia, fontWeight: FontWeight.w700)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Medya durum kartı (Stitch 24-6): yükleniyor / boş / hata.
class _MediaStateCard extends StatelessWidget {
  const _MediaStateCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(kChatInfoMargin, 8, kChatInfoMargin, 0),
      child: ChatInfoCard(padding: const EdgeInsets.all(20), child: child));
}

class _MediaLoadingCard extends StatelessWidget {
  const _MediaLoadingCard();

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return _MediaStateCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(context.l10n.p09MediaLoading,
                style: Theme.of(context).textTheme.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 16),
        BuSkeletonScope(
          child: Row(children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                  child: AspectRatio(
                      aspectRatio: 1,
                      child: _SkeletonTile(icon: i == 1 ? LucideIcons.circlePlay : LucideIcons.image))),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Stack(fit: StackFit.expand, children: [
      const BuSkeleton(radius: 8, height: 200),
      Center(child: Icon(icon, size: 28, color: t.mut.withValues(alpha: .5))),
    ]);
  }
}

class _MediaEmptyCard extends StatelessWidget {
  const _MediaEmptyCard();

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return _MediaStateCard(
      child: Column(children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle),
          child: Icon(LucideIcons.images, size: 32, color: t.mut),
        ),
        const SizedBox(height: 12),
        Text(context.l10n.chatInfoNoMedia, textAlign: TextAlign.center, style: chatInfoTitle16(context)),
        const SizedBox(height: 4),
        Text(context.l10n.p09MediaEmptyBody, textAlign: TextAlign.center, style: chatInfoBody14(context)),
      ]),
    );
  }
}

class _MediaErrorCard extends StatelessWidget {
  const _MediaErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return _MediaStateCard(
      child: Column(children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: t.danger.withValues(alpha: .12), shape: BoxShape.circle),
          child: Icon(LucideIcons.cloudOff, size: 32, color: t.danger),
        ),
        const SizedBox(height: 12),
        Text(context.l10n.p09MediaErrorTitle, textAlign: TextAlign.center, style: chatInfoTitle16(context)),
        const SizedBox(height: 4),
        Text(context.l10n.p09MediaErrorBody, textAlign: TextAlign.center, style: chatInfoBody14(context)),
        const SizedBox(height: 16),
        BuPressable(
          scale: .98,
          child: Material(
            color: t.ink,
            borderRadius: BuRadius.bMd,
            child: InkWell(
              borderRadius: BuRadius.bMd,
              onTap: () {
                buHaptic(BuHaptic.selection);
                onRetry();
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(LucideIcons.refreshCw, size: 18, color: t.bg),
                  const SizedBox(width: 8),
                  Flexible(child: Text(context.l10n.chatInfoRetry, style: chatInfoLabel14(context, color: t.bg))),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Tüm görseller: tam ekran, sonsuz kaydırmalı 3 sütunlu ızgara.
class ChatMediaGridPage extends StatefulWidget {
  const ChatMediaGridPage(
      {super.key,
      required this.feed,
      required this.headers,
      required this.onOpen});

  final ChatMediaFeed feed;
  final Map<String, String> headers;
  final void Function(int index) onOpen;

  @override
  State<ChatMediaGridPage> createState() => _ChatMediaGridPageState();
}

class _ChatMediaGridPageState extends State<ChatMediaGridPage> {
  final _scroll = ScrollController();

  ChatMediaFeed get _f => widget.feed;

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

  void _onScroll() {
    if (_scroll.hasClients &&
        _scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
      _f.load();
    }
  }

  /// Izgara ekranı doldurmuyorsa kaydırma olmayacağından devamını kendimiz iste.
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
      if (_scroll.position.maxScrollExtent <= 0) _f.load();
    });
  }

  Widget _tail(BuildContext context) {
    if (_f.items.isEmpty) return const SizedBox.shrink();
    if (_f.moreError != null) {
      return Padding(
        padding: const EdgeInsets.all(kChatInfoMargin),
        child: Center(
          child: BuButton(
            label: context.l10n.chatInfoRetry,
            icon: LucideIcons.refreshCw,
            kind: BuButtonKind.outline,
            compact: true,
            onPressed: () => _f.load(),
          ),
        ),
      );
    }
    if (!_f.more) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(kChatInfoMargin, 8, kChatInfoMargin, 0),
      child: BuSkeletonScope(
        child: Row(children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            const Expanded(child: AspectRatio(aspectRatio: 1, child: BuSkeleton(radius: 8, height: 200))),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final bottom = MediaQuery.paddingOf(context).bottom + 16;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        ChatInfoBar(title: context.l10n.chatInfoMedia),
        Expanded(
          child: ListenableBuilder(
            listenable: _f,
            builder: (context, _) {
              final empty = _f.items.isEmpty;
              return CustomScrollView(
                controller: _scroll,
                slivers: [
                  if (empty)
                    SliverToBoxAdapter(
                      child: _f.loading
                          ? const _MediaLoadingCard()
                          : _f.error != null
                              ? _MediaErrorCard(onRetry: () => _f.load(first: true))
                              : const _MediaEmptyCard(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(kChatInfoMargin, 8, kChatInfoMargin, 0),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (c, i) => ChatInfoThumb(
                              item: _f.items[i],
                              video: _f.isVideo(_f.items[i]),
                              durationMs: _f.videoMeta[_f.items[i].url],
                              radius: 8,
                              headers: widget.headers,
                              onTap: () => widget.onOpen(i)),
                          childCount: _f.items.length,
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(child: _tail(context)),
                  SliverToBoxAdapter(child: SizedBox(height: bottom)),
                ],
              );
            },
          ),
        ),
      ]),
    );
  }
}
