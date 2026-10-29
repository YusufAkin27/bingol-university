import 'package:flutter/widgets.dart' show Locale;

import '../../l10n/app_localizations.dart';

// Anket ve oylama modelleri (docs/API_CONTRACTS_V2.md "Anket ve oylama"). Alanlar eksik/null gelse de çökmez.

int _int(Object? v, [int d = 0]) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? d;
int? _intN(Object? v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
double? _dbl(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
bool _bool(Object? v, [bool d = false]) => v is bool ? v : d;

/// Bağlam verilmezse (testler, bağlamsız çağrılar) Türkçe metin kullanılır.
AppLocalizations pollL10n(AppLocalizations? l) => l ?? lookupAppLocalizations(const Locale('tr'));

String pollTypeLabel(AppLocalizations l, PollType t) => switch (t) {
      PollType.single => l.pollTypeSingle,
      PollType.multi => l.pollTypeMulti,
      PollType.rating => l.pollTypeRating,
      PollType.ranked => l.pollTypeRanked,
    };

enum PollType { single, multi, rating, ranked }

PollType pollTypeOf(Object? v) => switch ('$v'.toUpperCase()) {
      'MULTI' || 'MULTIPLE' => PollType.multi,
      'RATING' => PollType.rating,
      'RANKED' => PollType.ranked,
      _ => PollType.single,
    };

String pollTypeApi(PollType t) => switch (t) {
      PollType.single => 'SINGLE',
      PollType.multi => 'MULTI',
      PollType.rating => 'RATING',
      PollType.ranked => 'RANKED',
    };

class PollOption {
  const PollOption({required this.id, required this.text});

  final int id;
  final String text;

  factory PollOption.fromJson(Map<String, dynamic> j) =>
      PollOption(id: _int(j['id']), text: '${j['text'] ?? j['label'] ?? ''}');
}

/// Seçenek sonucu (`results[]`).
class PollResult {
  const PollResult({required this.optionId, this.count = 0, this.percent = 0, this.score});

  final int optionId;
  final int count;
  final double percent;
  final int? score;

  factory PollResult.fromJson(Map<String, dynamic> j) => PollResult(
        optionId: _int(j['optionId']),
        count: _int(j['count']),
        percent: _dbl(j['percent']) ?? 0,
        score: _intN(j['score']),
      );
}

class Poll {
  const Poll({
    required this.id,
    this.title = '',
    this.description,
    this.type = PollType.single,
    this.scope = 'GLOBAL',
    this.anonymous = false,
    this.allowChangeVote = true,
    this.opensAt,
    this.closesAt,
    this.status = 'OPEN',
    this.state = 'OPEN',
    this.communityId,
    this.communityName,
    this.options = const [],
    this.maxChoices,
    this.myOptionIds = const [],
    this.myRating,
    this.hasVote = false,
    this.canVote = true,
    this.voteBlockedReason,
    this.canManage = false,
    this.resultsVisible = false,
    this.results = const [],
    this.totalVotes,
    this.turnoutVoted,
    this.turnoutEligible,
    this.average,
    this.ratingCount,
    this.menuItems = const [],
    this.showResultsMode = 'ALWAYS',
  });

  final int id;
  final String title;
  final String? description;
  final PollType type;
  final String scope;
  final bool anonymous;
  final bool allowChangeVote;
  final String? opensAt;
  final String? closesAt;
  final String status;
  final String state;
  final int? communityId;
  final String? communityName;
  final List<PollOption> options;
  final int? maxChoices;
  final List<int> myOptionIds;
  final int? myRating;
  final bool hasVote;
  final bool canVote;
  final String? voteBlockedReason;
  final bool canManage;
  final bool resultsVisible;
  final List<PollResult> results;
  final int? totalVotes;
  final int? turnoutVoted;
  final int? turnoutEligible;
  final double? average;
  final int? ratingCount;
  final List<String> menuItems;

  /// Sonuç görünürlüğü ayarı: ALWAYS | AFTER_VOTE | AFTER_CLOSE.
  final String showResultsMode;

  bool get voted => hasVote;

  /// Sunucu durumu ya da bitiş zamanı geçmişse kapalı (iptal dahil).
  bool isClosed([DateTime? now]) {
    if (status == 'CLOSED' || status == 'CANCELLED' || state == 'CLOSED' || state == 'CANCELLED') return true;
    final c = closesAt == null ? null : DateTime.tryParse(closesAt!);
    return c != null && !c.isAfter(now ?? DateTime.now());
  }

  /// Henüz açılmamış (zamanlanmış) ya da taslak.
  bool get notOpenYet => state == 'SCHEDULED' || state == 'DRAFT' || status == 'DRAFT';

  /// Sonuçlar yalnız sunucu görünür dediğinde gösterilir (`showResults` kuralı sunucuda uygulanır).
  bool showResults() => resultsVisible;

  PollResult? resultOf(PollOption o) {
    for (final r in results) {
      if (r.optionId == o.id) return r;
    }
    return null;
  }

  int countOf(PollOption o) => resultOf(o)?.count ?? 0;
  double percentOf(PollOption o) => (resultOf(o)?.percent ?? 0).clamp(0, 100).toDouble();

  /// Katılım sayısı (oy veren kişi); bilinmiyorsa 0.
  int get participants => totalVotes ?? turnoutVoted ?? 0;

  factory Poll.fromJson(Map<String, dynamic>? j) {
    j ??= const {};
    final opts = j['options'] is List
        ? [for (final e in j['options'] as List) if (e is Map) PollOption.fromJson(e.cast<String, dynamic>())]
        : <PollOption>[];
    final res = j['results'] is List
        ? [for (final e in j['results'] as List) if (e is Map) PollResult.fromJson(e.cast<String, dynamic>())]
        : <PollResult>[];
    final mv = j['myVote'] is Map ? (j['myVote'] as Map).cast<String, dynamic>() : null;
    final turnout = j['turnout'] is Map ? (j['turnout'] as Map).cast<String, dynamic>() : null;
    final mine = mv?['optionIds'];
    final type = pollTypeOf(j['type']);
    return Poll(
      id: _int(j['id']),
      title: '${j['title'] ?? ''}',
      description: j['description'] == null || '${j['description']}'.trim().isEmpty ? null : '${j['description']}',
      type: type,
      scope: '${j['scope'] ?? 'GLOBAL'}',
      anonymous: _bool(j['anonymous']),
      allowChangeVote: _bool(j['allowChangeVote'], true),
      opensAt: j['opensAt']?.toString(),
      closesAt: j['closesAt']?.toString(),
      status: '${j['status'] ?? 'OPEN'}'.toUpperCase(),
      state: '${j['state'] ?? j['status'] ?? 'OPEN'}'.toUpperCase(),
      communityId: _intN(j['communityId']),
      communityName: j['communityName']?.toString(),
      options: opts,
      maxChoices: _intN(j['maxChoices']),
      myOptionIds: type == PollType.rating ? const [] : (mine is List ? [for (final e in mine) _int(e)] : const []),
      myRating: _intN(mv?['rating']),
      hasVote: mv != null,
      canVote: _bool(j['canVote'], true),
      voteBlockedReason: j['voteBlockedReason']?.toString(),
      canManage: _bool(j['canManage']),
      resultsVisible: _bool(j['resultsVisible']),
      results: res,
      totalVotes: _intN(j['totalVotes']),
      turnoutVoted: _intN(turnout?['voted']),
      turnoutEligible: _intN(turnout?['eligible']),
      average: _dbl(j['average']),
      ratingCount: _intN(j['ratingCount']),
      menuItems: j['menuItems'] is List ? [for (final e in j['menuItems'] as List) '$e'] : const [],
      showResultsMode: '${j['showResults'] ?? 'ALWAYS'}'.toUpperCase(),
    );
  }
}

/// "3 gün kaldı", "5 sa kaldı", "12 dk kaldı", "Sona erdi"; bitiş yoksa null.
String? pollRemaining(String? closesAt, [DateTime? now, AppLocalizations? l10n]) {
  final l = pollL10n(l10n);
  final c = closesAt == null ? null : DateTime.tryParse(closesAt)?.toLocal();
  if (c == null) return null;
  final diff = c.difference(now ?? DateTime.now());
  if (diff.inSeconds <= 0) return l.pollEnded;
  if (diff.inDays >= 1) return l.pollDaysLeft(diff.inDays.toString());
  if (diff.inHours >= 1) return l.pollHoursLeft(diff.inHours.toString());
  return l.pollMinutesLeft((diff.inMinutes < 1 ? 1 : diff.inMinutes).toString());
}

/// Oy seçimi mantığı (arayüzden bağımsız, test edilebilir). RANKED'de [ids] seçim SIRASINI korur (tercih sırası).
class PollSelection {
  PollSelection(this.type, {Iterable<int> initial = const [], this.rating, this.maxChoices}) : ids = [...initial];

  final PollType type;
  final int? maxChoices;
  final List<int> ids;
  int? rating;

  /// SINGLE: tek seçim; MULTI/RANKED: aç/kapat, üst sınırı aşmaz.
  /// Üst sınır dolduğu için eklenemezse false döner.
  bool toggle(int optionId) {
    if (type == PollType.single) {
      ids
        ..clear()
        ..add(optionId);
      return true;
    }
    if (ids.remove(optionId)) return true;
    if (maxChoices != null && ids.length >= maxChoices!) return false;
    ids.add(optionId);
    return true;
  }

  bool has(int optionId) => ids.contains(optionId);

  /// RANKED sırası (1 tabanlı); seçili değilse null.
  int? rankOf(int optionId) {
    final i = ids.indexOf(optionId);
    return i < 0 ? null : i + 1;
  }

  void setRating(int v) => rating = v.clamp(1, 5);

  bool get canSubmit => type == PollType.rating ? rating != null : ids.isNotEmpty;

  /// Gönderim gövdesi. RANKED'de tercih sırası korunur; MULTI'de sıralanır.
  Map<String, Object?> toBody() {
    if (type == PollType.rating) return {'rating': rating};
    return {'optionIds': type == PollType.ranked ? List<int>.of(ids) : (List<int>.of(ids)..sort())};
  }
}

/// Oluşturma formu doğrulaması: hata metni ya da null.
String? validatePollDraft({
  required String title,
  required PollType type,
  required List<String> options,
  required DateTime? closesAt,
  DateTime? now,
  AppLocalizations? l10n,
}) {
  final l = pollL10n(l10n);
  if (title.trim().isEmpty) return l.pollValTitle;
  if (type != PollType.rating) {
    final filled = options.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (filled.length < 2) return l.pollValMin2;
    if (filled.length > 12) return l.pollValMax12;
    if (filled.map((e) => e.toLowerCase()).toSet().length != filled.length) return l.pollValDistinct;
  }
  if (closesAt == null) return l.pollValEnd;
  if (!closesAt.isAfter(now ?? DateTime.now())) return l.pollValFuture;
  return null;
}

/// İstek için bitiş anı: İstanbul (+03:00) duvar saati, ofsetli ("2026-11-05T18:00:00+03:00").
String pollIstanbulIso(DateTime local) {
  final ist = local.toUtc().add(const Duration(hours: 3));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${ist.year}-${two(ist.month)}-${two(ist.day)}T${two(ist.hour)}:${two(ist.minute)}:00+03:00';
}

/// `voteBlockedReason` için kullanıcı metni.
String pollBlockedText(String? reason, [AppLocalizations? l10n]) {
  final l = pollL10n(l10n);
  return switch (reason) {
    'NOT_ELIGIBLE' => l.pollBlockedNotEligible,
    'CLOSED' => l.pollBlockedClosed,
    'NOT_OPEN' => l.pollBlockedNotOpen,
    'ALREADY_VOTED' => l.pollBlockedAlreadyVoted,
    _ => l.pollBlockedDefault,
  };
}
