import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'chat_media_viewer.dart';
import 'message_bubble.dart' show chatMediaUrl;
import 'sohbety_widgets.dart';

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

/// Küçük kare görsel önizlemesi.
class ChatInfoThumb extends StatelessWidget {
  const ChatInfoThumb(
      {super.key,
      required this.item,
      required this.headers,
      required this.onTap,
      this.video = false,
      this.durationMs});

  final ChatMediaItem item;
  final Map<String, String> headers;
  final VoidCallback onTap;

  /// Video küçük resmi: oynat ikonu + süre hapı.
  final bool video;
  final int? durationMs;

  static String formatDuration(int ms) {
    final s = (ms / 1000).round();
    final m = s ~/ 60;
    return '$m:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: video
          ? context.l10n.chatInfoOpenVideo
          : context.l10n.chatInfoOpenImage,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(
          color: t.sf2,
          child: Stack(fit: StackFit.expand, children: [
            Image.network(
              chatMediaUrl(item.thumbUrl ?? item.url),
              headers: headers,
              fit: BoxFit.cover,
              cacheWidth: 360,
              gaplessPlayback: true,
              errorBuilder: (c, e, s) =>
                  Center(child: Icon(LucideIcons.imageOff, color: t.mut)),
            ),
            if (video) ...[
              const Center(
                  child: Icon(Icons.play_circle_fill_rounded,
                      size: 27, color: Colors.white70)),
              if (durationMs != null)
                PositionedDirectional(
                  start: 4,
                  bottom: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(formatDuration(durationMs!),
                        style: BuType.micro.copyWith(color: Colors.white)),
                  ),
                ),
            ],
          ]),
        ),
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        SohbetyHeader(
            title: context.l10n.chatInfoMedia,
            onBack: () => Navigator.maybePop(context)),
        Expanded(
          child: ListenableBuilder(
        listenable: _f,
        builder: (context, _) => CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                delegate: SliverChildBuilderDelegate(
                  (c, i) => ChatInfoThumb(
                      item: _f.items[i],
                      video: _f.isVideo(_f.items[i]),
                      durationMs: _f.videoMeta[_f.items[i].url],
                      headers: widget.headers,
                      onTap: () => widget.onOpen(i)),
                  childCount: _f.items.length,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _f.moreError != null
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: OutlinedButton.icon(
                          onPressed: () => _f.load(),
                          icon: const Icon(Icons.refresh),
                          label: Text(context.l10n.chatInfoRetry),
                        ),
                      ),
                    )
                  : (_f.more
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                              child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))),
                        )
                      : const SizedBox.shrink()),
            ),
            SliverToBoxAdapter(
                child: SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 16)),
          ],
        ),
          ),
        ),
      ]),
    );
  }
}
