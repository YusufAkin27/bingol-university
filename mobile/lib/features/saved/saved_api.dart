import '../../core/session.dart';

/// Birleşik kaydedilenler türleri (sunucu `type` süzgeci). Boş/ALL = hepsi.
const kSavedTypeAll = 'ALL';

/// Birleşik kaydedilenler satırı (`GET /bookmarks`). `news` yalnız haber satırında doludur.
class SavedItem {
  const SavedItem({
    required this.type,
    required this.targetId,
    required this.title,
    this.subtitle = '',
    this.imageUrl,
    this.link = '',
    this.news,
  });

  factory SavedItem.fromJson(Map<String, dynamic> j) => SavedItem(
        type: (j['type'] ?? '').toString(),
        targetId: (j['targetId'] as num?)?.toInt() ?? 0,
        title: (j['title'] ?? '').toString(),
        subtitle: (j['subtitle'] ?? '').toString(),
        imageUrl: j['imageUrl']?.toString(),
        link: (j['link'] ?? '').toString(),
        news: j['news'] is Map ? (j['news'] as Map).cast<String, dynamic>() : null,
      );

  final String type;
  final int targetId;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String link;
  final Map<String, dynamic>? news;

  String get key => '$type:$targetId';
}

class SavedPage {
  const SavedPage(this.items, this.nextCursor);
  final List<SavedItem> items;
  final int? nextCursor;
}

/// Kaydedilenler ve yer imi uçları. Gönderi/forum kaydı kendi modüllerinin uçlarındadır.
class SavedApi {
  SavedApi(this.session);
  final Session session;

  Future<SavedPage> list({String type = kSavedTypeAll, int? cursor, int size = 20}) async {
    final q = StringBuffer('/bookmarks?type=$type&size=$size');
    if (cursor != null) q.write('&cursor=$cursor');
    final r = await session.api.get(q.toString()) as Map<String, dynamic>;
    final items = [
      for (final e in (r['items'] as List? ?? const [])) if (e is Map<String, dynamic>) SavedItem.fromJson(e),
    ];
    return SavedPage(items, (r['nextCursor'] as num?)?.toInt());
  }

  /// [kind]: news | event | community | poll | academic.
  Future<void> save(String kind, int id) => session.api.put('/bookmarks/$kind/$id');
  Future<void> unsave(String kind, int id) => session.api.delete('/bookmarks/$kind/$id');

  Future<bool> isSaved(String kind, int id) async {
    final r = await session.api.get('/bookmarks/$kind/ids') as Map<String, dynamic>;
    return (r['ids'] as List? ?? const []).any((e) => (e as num?)?.toInt() == id);
  }

  /// Birleşik listedeki satırın silme ucu (gönderi/forum kendi uçlarını kullanır).
  Future<void> unsaveItem(SavedItem it) async {
    switch (it.type) {
      case 'NEWS':
        return unsave('news', it.targetId);
      case 'EVENT':
        return unsave('event', it.targetId);
      case 'COMMUNITY':
        return unsave('community', it.targetId);
      case 'POLL':
        return unsave('poll', it.targetId);
      case 'ACADEMIC':
        return unsave('academic', it.targetId);
      case 'POST':
        await session.api.delete('/posts/${it.targetId}/save');
      case 'FORUM_TOPIC':
        await session.api.delete('/forum/topics/${it.targetId}/bookmark');
      case 'FORUM_COMMENT':
        await session.api.delete('/forum/comments/${it.targetId}/bookmark');
    }
  }
}

/// Kulüp/etkinlik bildirimlerini sessize alma.
class MuteApi {
  MuteApi(this.session);
  final Session session;

  /// [scope]: communities | events.
  Future<bool> isMuted(String scope, int id) async {
    final r = await session.api.get('/$scope/$id/notification-mute') as Map<String, dynamic>;
    return r['muted'] == true;
  }

  Future<bool> setMuted(String scope, int id, bool muted) async {
    final r = await session.api.put('/$scope/$id/notification-mute', {'muted': muted});
    return r is Map ? r['muted'] == true : muted;
  }

  /// Hepsi: `{communities:[ids], events:[ids]}`.
  Future<({List<int> communities, List<int> events})> mine() async {
    final r = await session.api.get('/me/notification-mutes') as Map<String, dynamic>;
    List<int> ids(Object? v) => [for (final e in (v as List? ?? const [])) (e as num).toInt()];
    return (communities: ids(r['communities']), events: ids(r['events']));
  }
}

/// Şikayetlerim satırı: yalnız genel durum (hedef/karar/not yoktur).
class MyReport {
  const MyReport({required this.id, required this.targetType, required this.reason, required this.status, this.createdAt, this.resolvedAt});

  factory MyReport.fromJson(Map<String, dynamic> j) => MyReport(
        id: (j['id'] as num?)?.toInt() ?? 0,
        targetType: (j['targetType'] ?? '').toString(),
        reason: (j['reason'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString())?.toLocal(),
        resolvedAt: DateTime.tryParse((j['resolvedAt'] ?? '').toString())?.toLocal(),
      );

  final int id;
  final String targetType;
  final String reason;
  final String status;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  bool get resolved => status == 'RESOLVED';
}

class MyReportsPage {
  const MyReportsPage(this.items, this.nextCursor);
  final List<MyReport> items;
  final int? nextCursor;
}

class MyReportsApi {
  MyReportsApi(this.session);
  final Session session;

  Future<MyReportsPage> list({int? cursor, int limit = 20}) async {
    final r = await session.api.get('/reports/mine?limit=$limit${cursor == null ? '' : '&cursor=$cursor'}') as Map<String, dynamic>;
    return MyReportsPage([
      for (final e in (r['items'] as List? ?? const [])) if (e is Map<String, dynamic>) MyReport.fromJson(e),
    ], (r['nextCursor'] as num?)?.toInt());
  }
}
