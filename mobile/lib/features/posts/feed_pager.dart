import '../../core/api.dart' show ApiError;
import 'post_api.dart';
import 'post_models.dart';

/// [FeedPager.next] sonucu: ekranda olmayan yeni gönderiler.
class FeedChunk {
  const FeedChunk(this.items, {this.exhausted = false});

  final List<Post> items;

  /// Sunucu görülmüş gönderileri yeniden karıştırıp tekrar ediyor (`exhausted: true`); istemci bunu kesintisiz sürdürür.
  final bool exhausted;
}

/// Keşfet akışının "bitmeyen" sayfalayıcısı (`GET /feed?scope=foryou`).
///
/// * İmleçsiz çağrı yeni oturum tohumu alır (yenileme / yeni rastgele sıra); görülmüşler sunucuda hariç tutulur.
/// * İmleç zinciri bitince (`nextCursor == null`) sonraki istek yeniden imleçsiz yapılır: sunucu görülmemişleri verir,
///   hepsi görüldüyse `exhausted:true` ile baştan karıştırır. Kullanıcı "tükendi" ekranı görmez.
/// * Aynı kimlik ekranda iki kez çıkmaz: [next]'e verilen `have` kümesindekiler elenir. Yalnızca tekrardan oluşan
///   sayfa gelirse en çok [maxAttempts] kez daha denenir; hâlâ yeni gönderi yoksa [ended] olur (küçük havuz).
class FeedPager {
  FeedPager(this.api, {this.scope = 'foryou', this.size = 12, this.cursor, this.renew = true, this.maxAttempts = 3});

  final PostApi api;
  final String scope;
  final int size;
  final int maxAttempts;

  /// Sonraki sayfanın opak imleci (null: imleçsiz).
  String? cursor;

  /// true: sonraki istek imleçsizdir (yeni tohum).
  bool renew;

  /// Yeni gönderi bulunamadı: kaydırma sonu (yenileyince açılır).
  bool ended = false;

  /// Sıfırlar: sonraki istek yeni oturum tohumudur.
  void reset() {
    cursor = null;
    renew = true;
    ended = false;
  }

  Future<FeedChunk> next(Set<int> have) async {
    final seen = {...have};
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final useCursor = renew ? null : cursor;
      PostPage<Post> page;
      try {
        page = await api.feed(scope: scope, cursor: useCursor, size: size);
      } on ApiError catch (e) {
        // Bozuk/başka kapsamın imleci: akışı imleçsiz sürdür (bir deneme hakkı harcanır).
        if (e.code == 'POST_CURSOR_INVALID' && useCursor != null) {
          cursor = null;
          renew = true;
          continue;
        }
        rethrow;
      }
      cursor = page.nextCursor;
      renew = !page.hasMore;
      final fresh = [for (final p in page.items) if (seen.add(p.id)) p];
      if (fresh.isNotEmpty) return FeedChunk(fresh, exhausted: page.exhausted);
      // İmleçsiz çağrı bile boş döndüyse gösterilecek bir şey yok.
      if (useCursor == null && page.items.isEmpty) break;
    }
    ended = true;
    return const FeedChunk([]);
  }
}
