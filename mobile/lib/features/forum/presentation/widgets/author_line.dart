import 'package:flutter/material.dart';

import '../../../../core/locale_controller.dart';
import '../../../../core/session.dart';
import '../../../../widgets/bu.dart';
import '../../../posts/post_models.dart' show postAuthHeaders, postRelativeTime;
import '../../../profile/user_profile_page.dart' show openUserProfile;
import '../../data/forum_models.dart';

/// Anonim yazar avatarı: kimlik/fotoğraf yok, nötr daire + kişi simgesi.
class ForumAnonAvatar extends StatelessWidget {
  const ForumAnonAvatar({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return ExcludeSemantics(
      child: Container(
        key: const ValueKey('forum-anon-avatar'),
        width: size,
        height: size,
        decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle, border: Border.all(color: t.bd)),
        child: Icon(BuIcons.user, size: size * .5, color: t.mut),
      ),
    );
  }
}

/// Yazar avatarı (anonimse nötr simge).
class ForumAvatar extends StatelessWidget {
  const ForumAvatar({super.key, required this.session, required this.author, this.size = 36});

  final Session session;
  final ForumAuthor author;
  final double size;

  @override
  Widget build(BuildContext context) => author.anonymous
      ? ForumAnonAvatar(size: size)
      : BuAvatar(name: author.displayName, url: author.avatarUrl, size: size, headers: postAuthHeaders(session));
}

/// Küçük kategori etiketi: dolgusuz, ince kenarlıklı (monochrome; hap/dolgu yok, kırmızı kullanılmaz).
class ForumCategoryTag extends StatelessWidget {
  const ForumCategoryTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return DecoratedBox(
      key: const ValueKey('forum-category-tag'),
      decoration: BoxDecoration(border: Border.all(color: t.bd), borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 6, vertical: 1),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.mut, fontWeight: FontWeight.w400)),
      ),
    );
  }
}

/// Yazar satırı: avatar + ad + "zaman · kategori (· düzenlendi)" + sağda isteğe bağlı eylem (üç nokta).
/// Anonim yazarda profil açılmaz. [badge]: örn. "Yazar" etiketi (adın yanında).
class ForumAuthorLine extends StatelessWidget {
  const ForumAuthorLine({
    super.key,
    required this.session,
    required this.author,
    this.createdAt,
    this.edited = false,
    this.categoryName,
    this.trailing,
    this.avatarSize = 36,
    this.badge,
  });

  final Session session;
  final ForumAuthor author;
  final String? createdAt;
  final bool edited;
  final String? categoryName;
  final Widget? trailing;
  final double avatarSize;
  final Widget? badge;

  void _openProfile(BuildContext context) {
    final id = author.userId;
    if (author.anonymous || id == null) return;
    openUserProfile(context, session, userId: id, name: author.displayName, avatarUrl: author.avatarUrl);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final time = postRelativeTime(context, createdAt);
    final canOpen = !author.anonymous && author.userId != null;
    final meta = <String>[if (time.isNotEmpty) time, if (edited) l.forumHomeEdited].join(' · ');
    final who = Row(children: [
      ForumAvatar(session: session, author: author, size: avatarSize),
      BuGap.w12,
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Flexible(
                child: Text(author.displayName,
                    key: const ValueKey('forum-author-name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleSmall?.copyWith(color: t.ink, fontWeight: FontWeight.w400, height: 1.25)),
              ),
              if (badge != null) ...[BuGap.w6, badge!],
            ]),
            if (meta.isNotEmpty || (categoryName ?? '').isNotEmpty)
              // Büyük yazı/dar ekranda taşmasın: sığmayan parça alt satıra iner.
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 2, children: [
                if (meta.isNotEmpty) Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.bodySmall?.copyWith(color: t.mut)),
                if ((categoryName ?? '').isNotEmpty) ForumCategoryTag(label: categoryName!),
              ]),
          ],
        ),
      ),
    ]);
    return Row(children: [
      Expanded(
        child: canOpen
            ? Semantics(
                button: true,
                label: author.displayName,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openProfile(context),
                  child: ConstrainedBox(constraints: const BoxConstraints(minHeight: BuSize.touch - 4), child: Align(alignment: AlignmentDirectional.centerStart, child: who)),
                ),
              )
            : ConstrainedBox(constraints: const BoxConstraints(minHeight: BuSize.touch - 4), child: Align(alignment: AlignmentDirectional.centerStart, child: who)),
      ),
      if (trailing != null) trailing!,
    ]);
  }
}
