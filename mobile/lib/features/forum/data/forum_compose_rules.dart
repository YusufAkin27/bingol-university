/// Forum konu formu sınırları ve saf doğrulama kuralları (sunucu sözleşmesiyle birebir; sunucu yine doğrular).
abstract final class ForumComposeLimits {
  static const titleMax = 150;
  static const bodyMax = 10000;
  static const maxImages = 4;
  static const pollMinOptions = 2;
  static const pollMaxOptions = 6;
  static const pollOptionMax = 80;
  static const pollQuestionMax = 200;
  static const pollMaxDays = 30;
}

/// Yalnız boşluk / görünmez karakterden oluşan metin "boş" sayılır (sunucu da reddeder).
bool isBlankText(String s) => s.replaceAll(_invisible, '').trim().isEmpty;

final _invisible = RegExp('[​-‍⁠﻿ ]');

/// Anket taslağı (oluşturucu durumu). Bitiş gün sayısı olarak tutulur: taslak günler sonra geri yüklense de
/// bitiş yayınlama anında hesaplanır, geçmişe düşmez.
class PollDraft {
  const PollDraft({
    this.question = '',
    this.options = const ['', ''],
    this.endsInDays,
    this.allowChangeVote = false,
  });

  final String question;
  final List<String> options;

  /// null = süresiz; 1..30.
  final int? endsInDays;
  final bool allowChangeVote;

  PollDraft copyWith({
    String? question,
    List<String>? options,
    int? endsInDays,
    bool clearEnds = false,
    bool? allowChangeVote,
  }) =>
      PollDraft(
        question: question ?? this.question,
        options: options ?? this.options,
        endsInDays: clearEnds ? null : (endsInDays ?? this.endsInDays),
        allowChangeVote: allowChangeVote ?? this.allowChangeVote,
      );

  /// Boş olmayan, kırpılmış seçenekler.
  List<String> get filledOptions => [for (final o in options) if (!isBlankText(o)) o.trim()];

  bool get isValid {
    final f = filledOptions;
    if (f.length < ForumComposeLimits.pollMinOptions || f.length > ForumComposeLimits.pollMaxOptions) return false;
    if (f.any((o) => o.length > ForumComposeLimits.pollOptionMax)) return false;
    final d = endsInDays;
    if (d != null && (d < 1 || d > ForumComposeLimits.pollMaxDays)) return false;
    return true;
  }

  /// Bitiş anı (UTC). 30 günde saat farkı payı için 1 saat kısılır (sunucu "en çok 30 gün" der).
  DateTime? endsAt(DateTime now) {
    final d = endsInDays;
    if (d == null) return null;
    var t = now.toUtc().add(Duration(days: d));
    if (d >= ForumComposeLimits.pollMaxDays) t = t.subtract(const Duration(hours: 1));
    return t;
  }

  /// `POST /forum/topics` gövdesindeki `poll` nesnesi.
  Map<String, dynamic> toRequest(DateTime now) {
    final q = question.trim();
    final e = endsAt(now);
    return {
      if (q.isNotEmpty) 'question': q,
      'options': filledOptions,
      if (e != null) 'endsAt': e.toIso8601String(),
      'allowChangeVote': allowChangeVote,
    };
  }

  Map<String, dynamic> toJson() => {
        'q': question,
        'o': options,
        if (endsInDays != null) 'd': endsInDays,
        'c': allowChangeVote,
      };

  factory PollDraft.fromJson(Map<String, dynamic> j) {
    final raw = j['o'];
    var opts = raw is List ? [for (final e in raw) e?.toString() ?? ''] : <String>[];
    while (opts.length < ForumComposeLimits.pollMinOptions) {
      opts = [...opts, ''];
    }
    if (opts.length > ForumComposeLimits.pollMaxOptions) opts = opts.sublist(0, ForumComposeLimits.pollMaxOptions);
    final d = j['d'];
    return PollDraft(
      question: j['q']?.toString() ?? '',
      options: opts,
      endsInDays: d is int && d >= 1 && d <= ForumComposeLimits.pollMaxDays ? d : null,
      allowChangeVote: j['c'] == true,
    );
  }
}

/// Konu formunun doğrulama sonucu: ilk eksik alan (yoksa [ComposeIssue.none]).
enum ComposeIssue { none, title, body, category, poll, imagesPending, imageFailed }

/// Yayınlamadan önce formu denetler. [categoryId] seçili kategori, [imagesBusy] yüklemesi süren,
/// [imagesFailed] hatalı görsel sayıları.
ComposeIssue validateCompose({
  required String title,
  required String body,
  required int? categoryId,
  PollDraft? poll,
  int imagesBusy = 0,
  int imagesFailed = 0,
}) {
  if (isBlankText(title) || title.trim().length > ForumComposeLimits.titleMax) return ComposeIssue.title;
  if (isBlankText(body) || body.trim().length > ForumComposeLimits.bodyMax) return ComposeIssue.body;
  if (categoryId == null) return ComposeIssue.category;
  if (poll != null && !poll.isValid) return ComposeIssue.poll;
  if (imagesFailed > 0) return ComposeIssue.imageFailed;
  if (imagesBusy > 0) return ComposeIssue.imagesPending;
  return ComposeIssue.none;
}
