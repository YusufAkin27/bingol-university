import 'package:flutter/material.dart';

import '../../../../core/locale_controller.dart';
import '../../../../widgets/bu.dart';
import '../../../../widgets/common.dart' show relativeTime;
import '../../data/forum_models.dart';
import '../../data/forum_search_text.dart';

/// Arama / kaydedilenler / faaliyet listelerinin ortak, kompakt konu kartı. Görünüm Forum ana sayfasındaki konu
/// kartıyla aynı dildedir (yüzey + ince çizgi, w400, kategori etiketi, 2 satır önizleme); kaydet/paylaş gibi eylemler
/// detay sayfasındadır, listede yalnız sayaçlar görünür.
class ForumTopicTile extends StatelessWidget {
  const ForumTopicTile({
    super.key,
    required this.topic,
    required this.onTap,
    this.previewOverride,
    this.highlight,
    this.matchLabel,
    this.trailing,
    this.showMineAnonymous = true,
    this.headers,
  });

  /// Yetkili medya/avatar uçları için istek başlıkları (`postAuthHeaders(session)`).
  final Map<String, String>? headers;

  final TopicSummary topic;
  final VoidCallback onTap;

  /// Verilirse gövde önizlemesi yerine bu metin (ör. arama kesiti) çizilir.
  final String? previewOverride;

  /// Arama terimi: başlıkta ve önizlemede eşleşen yerler marka tonunda (kalın DEĞİL) vurgulanır.
  final String? highlight;

  /// "Başlıkta" / "Yorumda" gibi eşleşme etiketi (arama).
  final String? matchLabel;

  /// Sayaç satırının sonunda eylem (ör. kaydı kaldır düğmesi).
  final Widget? trailing;

  /// Kendi anonim konumda "Anonim" rozetini göster.
  final bool showMineAnonymous;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final thumb = topic.thumbnail?.thumbUrl ?? topic.thumbnail?.url;
    final previewText = (previewOverride ?? topic.bodyPreview).trim();
    final removed = topic.removed;
    final when = relativeTime(topic.createdAt, context: context);
    final semantic = [
      topic.title,
      if (topic.category?.name.isNotEmpty ?? false) topic.category!.name,
      topic.author.displayName,
      when,
      l.forumActivityCounts('${topic.likeCount}', '${topic.commentCount}'),
    ].where((s) => s.isNotEmpty).join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        label: semantic,
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: t.sf,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: t.bd)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      if (topic.category != null && topic.category!.name.isNotEmpty) ...[
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(8)),
                            child: Text(topic.category!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tx.labelSmall!.copyWith(color: t.onSoft, fontWeight: FontWeight.w400)),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (matchLabel != null) ...[
                        Text(matchLabel!, key: const ValueKey('forum-match-label'), style: tx.labelSmall!.copyWith(color: t.prText, fontWeight: FontWeight.w400)),
                        const SizedBox(width: 8),
                      ],
                      Expanded(child: Text(when, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelSmall!.copyWith(color: t.mut))),
                    ]),
                    const SizedBox(height: 8),
                    _hl(
                      removed ? l.forumActivityRemoved : topic.title,
                      tx.titleMedium!.copyWith(color: removed ? t.mut : t.ink, fontWeight: FontWeight.w400, height: 1.3),
                      t,
                      2,
                      const ValueKey('forum-tile-title'),
                      highlight,
                    ),
                    if (previewText.isNotEmpty && !removed) ...[
                      const SizedBox(height: 4),
                      _hl(previewText, tx.bodyMedium!.copyWith(color: t.mut, height: 1.4), t, 2, const ValueKey('forum-tile-preview'), highlight),
                    ],
                    const SizedBox(height: 10),
                    ForumAuthorMini(author: topic.author, mine: topic.mine, showMineAnonymous: showMineAnonymous, headers: headers),
                    const SizedBox(height: 8),
                    Row(children: [
                      _Counts(likes: topic.likeCount, comments: topic.commentCount, liked: topic.likedByMe),
                      const Spacer(),
                      if (trailing != null) trailing!,
                    ]),
                  ]),
                ),
                if (thumb != null) ...[
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BuImage(thumb, width: 64, height: 64, headers: headers, maxDecodeWidth: 200, placeholderIcon: BuIcons.image),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Düz ya da (arama terimi varsa) vurgulu metin.
Widget _hl(String text, TextStyle style, BuTokens t, int maxLines, Key key, String? q) {
  if (q == null || q.isEmpty) return Text(text, key: key, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: style);
  final segs = splitForumHighlight(text, q);
  return Text.rich(
    TextSpan(children: [
      for (final s in segs) TextSpan(text: s.text, style: s.highlight ? style.copyWith(color: t.prText, fontWeight: FontWeight.w400) : null),
    ]),
    key: key,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    style: style,
  );
}

/// Yorum kartı (kaydedilen yorumlar, yorumlarım, başkasının profili): metin 3 satır, yazar satırı, beğeni sayısı.
class ForumCommentTile extends StatelessWidget {
  const ForumCommentTile({super.key, required this.comment, required this.onTap, this.topicTitle, this.trailing, this.headers});

  final Map<String, String>? headers;

  final ForumComment comment;
  final VoidCallback onTap;

  /// Yorumun bağlı olduğu konunun başlığı (varsa küçük bağlam satırı).
  final String? topicTitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final deleted = comment.deleted || (comment.body ?? '').isEmpty;
    final when = relativeTime(comment.createdAt, context: context);
    final author = comment.author;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        label: [deleted ? l.forumActivityCommentDeleted : comment.body!, if (author != null) author.displayName, when].join(', '),
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: t.sf,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: t.bd)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  ExcludeSemantics(child: Icon(BuIcons.messageCircle, size: 14, color: t.mut)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      topicTitle != null && topicTitle!.isNotEmpty ? topicTitle! : when,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tx.labelMedium!.copyWith(color: t.mut),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(
                  deleted ? l.forumActivityCommentDeleted : comment.body!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: tx.bodyLarge!.copyWith(color: deleted ? t.mut : t.ink, fontWeight: FontWeight.w400, height: 1.4),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  if (author != null) Expanded(child: ForumAuthorMini(author: author, mine: comment.mine, headers: headers)) else const Spacer(),
                  if (topicTitle != null && topicTitle!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(when, style: tx.labelSmall!.copyWith(color: t.mut)),
                    const SizedBox(width: 10),
                  ],
                  _Counts(likes: comment.likeCount, comments: comment.replyCount, liked: comment.likedByMe),
                  if (trailing != null) trailing!,
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Küçük yazar satırı: avatar + ad. Anonim yazarda avatar/ad GİZLİ ("Anonim #N" yer tutucusu); kendi anonim
/// içeriğimde ek "Anonim" rozeti (yalnız ben görürüm). Anonim yazara dokunma/profil yoktur.
class ForumAuthorMini extends StatelessWidget {
  const ForumAuthorMini({super.key, required this.author, this.mine = false, this.showMineAnonymous = true, this.headers});

  final Map<String, String>? headers;

  final ForumAuthor author;
  final bool mine;
  final bool showMineAnonymous;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final anon = author.anonymous;
    final name = author.displayName.isNotEmpty ? author.displayName : (anon ? l.forumActivityAnonymous : '');
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (anon)
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle),
          child: ExcludeSemantics(child: Icon(BuIcons.user, size: 13, color: t.mut)),
        )
      else
        BuAvatar(name: name, url: author.avatarUrl, size: 22, headers: headers),
      const SizedBox(width: 8),
      Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w400))),
      if (anon && mine && showMineAnonymous) ...[
        const SizedBox(width: 8),
        Container(
          key: const ValueKey('forum-anon-badge'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(8), border: Border.all(color: t.bd)),
          child: Text(l.forumActivityAnonBadge, style: tx.labelSmall!.copyWith(color: t.mut, fontWeight: FontWeight.w400)),
        ),
      ],
    ]);
  }
}

class _Counts extends StatelessWidget {
  const _Counts({required this.likes, required this.comments, required this.liked});

  final int likes;
  final int comments;
  final bool liked;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final s = tx.labelMedium!.copyWith(color: t.mut, fontWeight: FontWeight.w400);
    return ExcludeSemantics(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(liked ? BuIcons.heartFilled : BuIcons.heart, size: 15, color: liked ? t.pr : t.mut),
        const SizedBox(width: 4),
        Text('$likes', style: s),
        const SizedBox(width: 14),
        Icon(BuIcons.messageCircle, size: 15, color: t.mut),
        const SizedBox(width: 4),
        Text('$comments', style: s),
      ]),
    );
  }
}
