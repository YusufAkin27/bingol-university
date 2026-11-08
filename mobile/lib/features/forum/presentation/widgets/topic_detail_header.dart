import '../../../chat/emoji_presentation.dart';
import 'package:flutter/material.dart';

import '../../../../core/icons/bu_icons.dart';
import '../../../../core/locale_controller.dart';
import '../../../../core/session.dart';
import '../../../../core/theme.dart';
import '../../../../widgets/bu_image.dart';
import '../../../../widgets/bu_pressable.dart';
import '../../../../widgets/bu_skeleton.dart';
import '../../../../widgets/bu_widgets.dart';
import '../../../../widgets/common.dart' show relativeTime;
import '../../../../widgets/linkified_text.dart';
import '../../../posts/post_models.dart' show postAuthHeaders;
import '../../data/forum_models.dart';

/// Konu detayının üst bölümü: yazar satırı, rozetler (kategori / sabit / kilit), başlık, TAM açıklama, görseller.
/// [topic] tam konuysa gövde ve görseller çizilir; yalnız özet (liste kartından hızlı açılış) varsa gövde yerine
/// iskelet gösterilir.
class TopicHeaderBlock extends StatelessWidget {
  const TopicHeaderBlock({super.key, required this.summary, required this.session, this.full, this.onOpenProfile});

  final TopicSummary summary;
  final TopicView? full;
  final Session session;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final s = summary;
    final a = s.author;
    final name = a.displayName.isEmpty ? l.forumDetailDeletedAccount : a.displayName;
    final time = relativeTime(s.createdAt, context: context);
    final sub = [
      if ((a.department ?? '').isNotEmpty && !a.anonymous) a.department!,
      if (time.isNotEmpty) time,
      if (s.edited) l.forumDetailEdited,
    ].join(' · ');
    final tappable = a.userId != null && !a.anonymous && onOpenProfile != null;
    final av = BuAvatar(
      name: name,
      url: a.anonymous ? null : a.avatarUrl,
      size: 40,
      headers: postAuthHeaders(session),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          tappable ? GestureDetector(behavior: HitTestBehavior.opaque, onTap: onOpenProfile, child: av) : av,
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(color: t.ink)),
              if (sub.isNotEmpty) Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (s.category != null) _Chip(key: const ValueKey('topicCategory'), icon: null, label: s.category!.name),
          if (s.pinned) _Chip(key: const ValueKey('topicPinnedChip'), icon: BuIcons.pin, label: l.forumDetailPinned, accent: true),
          if (s.locked) _Chip(key: const ValueKey('topicLockedChip'), icon: BuIcons.lock, label: l.forumDetailLockedChip),
        ]),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: Text.rich(emojiAwareSpan(s.title, tx.headlineSmall!.copyWith(color: t.ink, height: 1.3)), key: const ValueKey('topicTitle')),
        ),
        const SizedBox(height: 12),
        if (full != null)
          LinkifiedText(full!.body, style: tx.bodyLarge!.copyWith(color: t.ink, height: 1.55))
        else
          const _BodySkeleton(),
        if (full != null && full!.images.isNotEmpty) ...[
          const SizedBox(height: 16),
          TopicGallery(images: full!.images, session: session),
        ],
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.label, this.icon, this.accent = false});

  final String label;
  final IconData? icon;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    // Monochrome: dolgu yok; ince kenarlık, vurgulu (sabit) etiket daha güçlü kenarlık + ink metin.
    final fg = accent ? t.ink : t.mut;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(border: Border.all(color: accent ? t.bdStrong : t.bd), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 6)],
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: fg))),
      ]),
    );
  }
}

class _BodySkeleton extends StatelessWidget {
  const _BodySkeleton();

  @override
  Widget build(BuildContext context) => const BuSkeletonScope(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BuSkeleton.line(),
          SizedBox(height: 8),
          BuSkeleton.line(),
          SizedBox(height: 8),
          BuSkeleton.line(width: 220),
        ]),
      );
}

/// Ekli görseller: tek görsel tam genişlik; birden çoksa yatay kayan galeri (sayaç rozetiyle). Dokununca tam ekran
/// AÇILMAZ (kullanıcı kuralı), uzun basma ve yakınlaştırma yoktur.
class TopicGallery extends StatefulWidget {
  const TopicGallery({super.key, required this.images, required this.session});

  final List<ForumImage> images;
  final Session session;

  @override
  State<TopicGallery> createState() => _TopicGalleryState();
}

class _TopicGalleryState extends State<TopicGallery> {
  final PageController _page = PageController(viewportFraction: .9);
  int _i = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final imgs = widget.images;
    final headers = postAuthHeaders(widget.session);

    Widget one(ForumImage im, int idx, {required double aspect}) => Semantics(
          image: true,
          label: l.forumDetailImageSemantic((idx + 1).toString(), imgs.length.toString()),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ColoredBox(
              color: t.sf2,
              child: AspectRatio(
                aspectRatio: aspect,
                child: BuImage(im.url, headers: headers, fit: BoxFit.cover, maxDecodeWidth: 1200),
              ),
            ),
          ),
        );

    if (imgs.length == 1) {
      final a = imgs.first.aspect.clamp(.75, 1.91).toDouble();
      return KeyedSubtree(key: const ValueKey('topicGallery'), child: one(imgs.first, 0, aspect: a));
    }
    // Çoklu: ortak oran 4:3; kenarlarda komşu görsel görünür (kaydırılabileceğini belli eder).
    return Column(key: const ValueKey('topicGallery'), children: [
      AspectRatio(
        aspectRatio: 4 / 3 / .9,
        child: PageView.builder(
          controller: _page,
          padEnds: false,
          itemCount: imgs.length,
          onPageChanged: (v) => setState(() => _i = v),
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Stack(fit: StackFit.expand, children: [
              one(imgs[i], i, aspect: 4 / 3),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(l.forumDetailImageIndex((_i + 1).toString(), imgs.length.toString()),
          key: const ValueKey('topicGalleryIndex'), style: tx.bodySmall!.copyWith(color: t.mut)),
    ]);
  }
}

/// Beğeni / yorum / kaydet / takip / paylaş satırı. Her düğme en az 48 dp dokunma alanı; etkin durum ink, beğeni kalbi `heart`.
class TopicActionBar extends StatelessWidget {
  const TopicActionBar({
    super.key,
    required this.topic,
    required this.onLike,
    required this.onComments,
    required this.onSave,
    required this.onFollow,
    required this.onShare,
  });

  final TopicSummary topic;
  final VoidCallback onLike;
  final VoidCallback onComments;
  final VoidCallback onSave;
  final VoidCallback onFollow;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final s = topic;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.bdSubtle), bottom: BorderSide(color: t.bdSubtle))),
      child: Row(children: [
        _Act(
          key: const ValueKey('topicLike'),
          icon: s.likedByMe ? BuIcons.heartFilled : BuIcons.heart,
          count: s.likeCount,
          active: s.likedByMe,
          label: s.likedByMe ? l.forumDetailUnlikeAction : l.forumDetailLikeAction,
          semanticCount: l.forumDetailLikeCount(s.likeCount.toString()),
          onTap: onLike,
        ),
        _Act(
          key: const ValueKey('topicComments'),
          icon: BuIcons.messageCircle,
          count: s.commentCount,
          label: l.forumDetailCommentsAction,
          semanticCount: l.forumDetailCommentCount(s.commentCount.toString()),
          onTap: onComments,
        ),
        _Act(
          key: const ValueKey('topicSave'),
          icon: s.savedByMe ? BuIcons.bookmarkFilled : BuIcons.bookmark,
          active: s.savedByMe,
          label: s.savedByMe ? l.forumDetailUnsaveAction : l.forumDetailSaveAction,
          onTap: onSave,
        ),
        _Act(
          key: const ValueKey('topicFollow'),
          icon: s.followedByMe ? BuIcons.bellFilled : BuIcons.bell,
          active: s.followedByMe,
          label: s.followedByMe ? l.forumDetailUnfollowAction : l.forumDetailFollowAction,
          onTap: onFollow,
        ),
        _Act(
          key: const ValueKey('topicShare'),
          icon: BuIcons.send,
          label: l.forumDetailShareAction,
          onTap: onShare,
        ),
      ]),
    );
  }
}

class _Act extends StatelessWidget {
  const _Act({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.count,
    this.active = false,
    this.semanticCount,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? count;
  final bool active;
  final String? semanticCount;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    // Beğeni kalbi anlamsal kırmızı (`heart`); diğer etkin durumlar ink.
    final color = active ? (icon == BuIcons.heartFilled ? t.heart : t.ink) : t.mut;
    return Expanded(
      child: Semantics(
        button: true,
        toggled: active,
        label: semanticCount == null ? label : '$label, $semanticCount',
        excludeSemantics: true,
        child: BuPressable(
          onTap: onTap,
          haptic: BuHaptic.selection,
          scale: .92,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 22, color: color),
                if (count != null && count! > 0) ...[
                  const SizedBox(width: 6),
                  Text(count.toString(), style: tx.bodySmall!.copyWith(color: color, fontFeatures: const [FontFeature.tabularFigures()])),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kilitli konu bandı (yorum yazma kapalı).
class TopicLockedBand extends StatelessWidget {
  const TopicLockedBand({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('topicLockedBand'),
      margin: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: t.warnSoft, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(BuIcons.lock, size: 18, color: t.onWarnSoft),
        const SizedBox(width: 10),
        Expanded(child: Text(context.l10n.forumDetailLockedBanner, style: tx.bodyMedium!.copyWith(color: t.onWarnSoft))),
      ]),
    );
  }
}
