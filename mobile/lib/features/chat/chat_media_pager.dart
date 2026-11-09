import 'package:flutter/foundation.dart';

import '../../core/api.dart';
import 'chat_media_viewer.dart';

/// Tam ekran görüntüleyicinin ESKİYE doğru sonsuz yüklemesi.
/// [items] eskiden yeniye sıralıdır; yeni öğeler listenin BAŞINA eklenir ([prepended] kadar).
/// Kaynak: mesaj geçmişi (`GET /conversations/{cid}/messages?before=`), imleçli ve sınırlı
/// (istek başına 40 mesaj, yükleme başına en çok 6 istek); silinmiş/kaldırılmış/tek gösterimlik ekler girmez.
class ChatMediaPager extends ChangeNotifier {
  ChatMediaPager({
    required this.api,
    required this.conversationId,
    required this.senderName,
    required List<ChatMediaItem> items,
    required int? olderCursor,
  })  : _items = List.of(items),
        _cursor = olderCursor {
    for (final i in _items) {
      if (i.id != null) _seen.add(i.id!);
    }
  }

  static const pageSize = 40;
  static const maxRequestsPerLoad = 6;
  static const wantPerLoad = 20;

  final ApiClient api;
  final int conversationId;
  final String? Function(Map<String, dynamic> message) senderName;

  List<ChatMediaItem> _items;
  final _seen = <int>{};
  int? _cursor;
  bool loadingOlder = false;
  Object? error;
  int prepended = 0;
  bool _disposed = false;

  List<ChatMediaItem> get items => _items;
  bool get hasOlder => _cursor != null;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Bir sayfadaki mesajlardan (yeniden eskiye) eskiden yeniye medya öğeleri.
  List<ChatMediaItem> _collect(List raw) {
    final out = <ChatMediaItem>[];
    for (final r in raw.reversed) {
      if (r is! Map) continue;
      final m = Map<String, dynamic>.from(r);
      if (m['deleted'] == true || m['removed'] == true) continue;
      final at = DateTime.tryParse((m['createdAt'] as String?) ?? '')?.toLocal();
      final who = senderName(m);
      for (final a in (m['attachments'] as List? ?? const []).whereType<Map>()) {
        final it = ChatMediaItem.tryFromAttachment(a, sender: who, at: at);
        if (it == null) continue;
        final id = it.id;
        if (id != null && !_seen.add(id)) continue;
        out.add(it);
      }
    }
    return out;
  }

  Future<void> loadOlder() async {
    if (loadingOlder || _cursor == null) return;
    loadingOlder = true;
    error = null;
    prepended = 0;
    notifyListeners();
    final fresh = <ChatMediaItem>[];
    try {
      var requests = 0;
      while (_cursor != null && fresh.length < wantPerLoad && requests < maxRequestsPerLoad) {
        final page = await api.get('/conversations/$conversationId/messages?size=$pageSize&before=$_cursor')
            as Map<String, dynamic>;
        if (_disposed) return;
        // Bu sayfa daha eski olduğundan öncekilerin önüne gelir.
        fresh.insertAll(0, _collect(page['items'] as List? ?? const []));
        _cursor = (page['nextCursor'] as num?)?.toInt();
        requests++;
      }
    } catch (e) {
      if (_disposed) return;
      error = e;
    }
    if (_disposed) return;
    loadingOlder = false;
    if (fresh.isNotEmpty) {
      _items = [...fresh, ..._items];
      prepended = fresh.length;
    }
    notifyListeners();
  }
}
