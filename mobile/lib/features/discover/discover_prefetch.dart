import 'dart:async';

import '../../core/cache/image_disk_cache.dart';
import '../../core/cache/video_prefetch.dart';
import '../../core/session.dart';
import '../posts/post_models.dart';

/// Keşfet önyüklemesi: akış sayfası geldiği an, kullanıcı bakmadan ÖNCE yakında görünecek gönderilerin küçük
/// resimlerini diske, videolarını yerel dosyaya indirir ([DiskNetworkImage.warm], [VideoPrefetcher]). Ekrana gelince
/// görsel/video zaten yereldedir. Hata sessizdir; aynı adres iki kez istenmez.
class DiscoverPrefetch {
  DiscoverPrefetch(this.session, {this.imageAhead = 16, this.videoAhead = 6, VideoPrefetcher? videos})
      : _videos = videos;

  final Session session;

  /// Görünür konumdan itibaren küçük resmi ısıtılacak en çok kutu sayısı.
  final int imageAhead;

  /// Dosyası indirilecek en çok video sayısı.
  final int videoAhead;
  final VideoPrefetcher? _videos;

  final Set<String> _warmed = <String>{};

  VideoPrefetcher get _v => _videos ?? VideoPrefetcher.instance;

  /// [items] tam liste, [from] kullanıcının şu an ulaştığı (görünen) en uzak indeks. Ondan SONRAKİLER yakınlık sırasıyla
  /// hazırlanır: önce görsel, sonra video planı.
  void onItems(List<Post> items, {int from = -1}) {
    final start = (from + 1).clamp(0, items.length);
    final headers = postAuthHeaders(session);
    final images = items.skip(start).take(imageAhead);
    for (final p in images) {
      final m = p.photo;
      if (m == null) continue;
      final url = m.thumbUrl ?? m.url;
      if (_warmed.add(url)) unawaited(DiskNetworkImage.warm(url, headers: headers));
    }
    final videos = <VideoPrefetchItem>[];
    for (final p in items.skip(start)) {
      final v = p.video;
      if (v == null || v.url.isEmpty) continue;
      videos.add(VideoPrefetchItem(v.url, headers));
      if (videos.length >= videoAhead) break;
    }
    if (videos.isNotEmpty) _v.plan(videos);
  }
}
