import '../../core/api.dart';
import '../../core/session.dart';
import '../posts/post_models.dart' show PostPage;
import '../../l10n/app_localizations.dart';
import 'poll_models.dart';

/// Anket uçları (docs/API_CONTRACTS_V2.md). Tek HTTP katmanı `session.api`; hatalar `ApiError`
/// (POLL_CLOSED, POLL_ALREADY_VOTED, POLL_NOT_ELIGIBLE...) olarak fırlar.
class PollApi {
  PollApi(this.session);

  final Session session;

  /// `scope`: `open` | `mine` | `closed` | `community:{id}`. İmleç sayısaldır (`nextCursor`).
  Future<PostPage<Poll>> list({String scope = 'open', String? cursor, int size = 20}) async {
    final q = <String>[
      'scope=${Uri.encodeQueryComponent(scope)}',
      if (cursor != null && cursor.isNotEmpty) 'cursor=${Uri.encodeQueryComponent(cursor)}',
      'size=$size',
    ];
    final r = await session.api.get('/polls?${q.join('&')}');
    return PostPage.parse(r, Poll.fromJson);
  }

  Future<Poll> get(int id) async => Poll.fromJson((await session.api.get('/polls/$id')) as Map<String, dynamic>?);

  /// Bugünün menü anketi; yemek listesi yoksa sunucu 204 döner (null).
  Future<Poll?> menuToday() async {
    final r = await session.api.get('/polls/menu/today');
    return r is Map<String, dynamic> && r['id'] != null ? Poll.fromJson(r) : null;
  }

  /// Oy ver / oyu değiştir (idempotent). Dönen anket güncel durumla gelir.
  Future<Poll> vote(int id, PollSelection s) async {
    final r = await session.api.post('/polls/$id/vote', s.toBody());
    return r is Map<String, dynamic> && r['id'] != null ? Poll.fromJson(r) : await get(id);
  }

  Future<Poll> retract(int id) async {
    final r = await session.api.delete('/polls/$id/vote');
    return r is Map<String, dynamic> && r['id'] != null ? Poll.fromJson(r) : await get(id);
  }

  /// Kulüp anketi oluşturur (`scope=COMMUNITY`).
  Future<Poll> createCommunity({
    required int communityId,
    required String title,
    String? description,
    required PollType type,
    required bool anonymous,
    required DateTime closesAt,
    List<String> options = const [],
    int? maxChoices,
    bool allowChangeVote = true,
    String showResults = 'ALWAYS',
    bool notify = true,
  }) async {
    final r = await session.api.post('/polls', {
      'title': title.trim(),
      if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
      'type': pollTypeApi(type),
      'scope': 'COMMUNITY',
      'communityId': communityId,
      if (type != PollType.rating) 'options': [for (final o in options) o.trim()],
      if (maxChoices != null && (type == PollType.multi || type == PollType.ranked)) 'maxChoices': maxChoices,
      'anonymous': anonymous,
      'allowChangeVote': allowChangeVote,
      'showResults': showResults,
      'notify': notify,
      'closesAt': pollIstanbulIso(closesAt),
    });
    return Poll.fromJson(r as Map<String, dynamic>?);
  }
}

/// Anket hata kodları için yerel yedek metin (sunucu mesajı boşsa); aksi halde sunucu metni.
String pollErrorText(Object e, [AppLocalizations? l10n]) {
  final l = pollL10n(l10n);
  if (e is ApiError && e.message.isEmpty) {
    switch (e.code) {
      case 'POLL_CLOSED':
        return l.pollErrClosed;
      case 'POLL_NOT_OPEN':
        return l.pollBlockedNotOpen;
      case 'POLL_ALREADY_VOTED':
        return l.pollErrAlreadyVoted;
      case 'POLL_NOT_ELIGIBLE':
        return l.pollBlockedNotEligible;
      case 'POLL_FORBIDDEN':
        return l.pollErrForbidden;
      case 'POLL_NOT_FOUND':
        return l.pollErrNotFound;
      case 'POLL_INVALID_VOTE':
        return l.pollErrInvalidVote;
    }
  }
  return errorText(e);
}

/// Sunucu durumuyla çelişen (ekranın yeniden yüklenmesi gereken) hata kodları.
const pollStateErrors = {'POLL_CLOSED', 'POLL_NOT_OPEN', 'POLL_ALREADY_VOTED', 'POLL_NOT_ELIGIBLE'};
