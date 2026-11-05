import 'package:flutter/material.dart';

import '../../../../core/locale_controller.dart';
import '../../../../widgets/bu.dart';
import '../../../../widgets/common.dart' show relativeTime;
import '../../data/forum_models.dart';
import '../../data/forum_search_text.dart';

/// Arama sonucu kartının altındaki eşleşme şeridi: "Yorumda" gibi etiket + (varsa) vurgulu kesit. Vurgu `ink`
/// renginde, kalın DEĞİL. Etiket boşsa şerit çizilmez.
class ForumMatchStrip extends StatelessWidget {
  const ForumMatchStrip({super.key, required this.label, required this.query, this.snippet});

  final String label;
  final String query;
  final String? snippet;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final text = (snippet ?? '').trim();
    final base = tx.bodySmall!.copyWith(color: t.mut, height: 1.4, fontWeight: FontWeight.w400);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 16, 0),
      child: Semantics(
        container: true,
        label: text.isEmpty ? label : '$label: $text',
        excludeSemantics: true,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(label, key: const ValueKey('forum-match-label'), style: tx.labelMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  for (final s in splitForumHighlight(text, query))
                    TextSpan(text: s.text, style: s.highlight ? base.copyWith(color: t.ink, fontWeight: FontWeight.w400) : null),
                ]),
                key: const ValueKey('forum-match-snippet'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: base,
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Kendi anonim konumun altında rozet: "Anonim paylaşım - yalnız sen görürsün". Başkasına gösterilmez; kimlik içermez.
class ForumOwnAnonBadge extends StatelessWidget {
  const ForumOwnAnonBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 16, 0),
      child: Semantics(
        container: true,
        label: l.forumActivityAnonBadgeLong,
        excludeSemantics: true,
        child: Row(children: [
          Icon(BuIcons.eyeOff, size: 14, color: t.mut),
          const SizedBox(width: 6),
          Expanded(
            child: Text(l.forumActivityAnonBadgeLong,
                key: const ValueKey('forum-anon-badge'), style: tx.labelMedium!.copyWith(color: t.mut, fontWeight: FontWeight.w400)),
          ),
        ]),
      ),
    );
  }
}

/// Yorum kartı (kaydedilen yorumlar, yorumlarım, başkasının profili): metin 3 satır, yazar satırı, beğeni sayısı.
class ForumCommentTile extends StatelessWidget {
  const ForumCommentTile({super.key, required this.comment, required this.onTap, this.topicTitle, this.trailing, this.headers});

  final Map<String, String>? headers;
  final ForumComment comment;
  final VoidCallback onTap;

  /// Yorumun bağlı olduğu konunun başlığı (varsa küçük bağlam satırı).
  final String? topicTitle;

  /// Sayaç satırının sonunda eylem (ör. kaydı kaldır düğmesi).
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
/// yorumumda ek "Anonim" rozeti (yalnız ben görürüm). Anonim yazara dokunma/profil yoktur.
class ForumAuthorMini extends StatelessWidget {
  const ForumAuthorMini({super.key, required this.author, this.mine = false, this.headers});

  final Map<String, String>? headers;
  final ForumAuthor author;
  final bool mine;

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
      if (anon && mine) ...[
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
        Icon(liked ? BuIcons.heartFilled : BuIcons.heart, size: 15, color: liked ? t.heart : t.mut),
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
