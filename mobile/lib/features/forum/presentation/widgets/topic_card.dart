
import '../../../chat/emoji_presentation.dart';
import 'package:flutter/material.dart';

import '../../../../core/cache/image_disk_cache.dart';
import '../../../../core/locale_controller.dart';
import '../../../../core/session.dart';
import '../../../../widgets/bu.dart';
import '../../../posts/post_models.dart' show postAuthHeaders;
import '../../data/forum_api.dart';
import '../../data/forum_models.dart';
import '../../forum_routes.dart' show openTopicShare;
import 'author_line.dart';
import 'forum_like_button.dart';
import 'forum_state_views.dart';
import 'topic_actions.dart';

/// Eylem düğmesi: simge + isteğe bağlı sayı, en az 44 dp dokunma alanı, basış ölçeği. Etiket ekran okuyucu içindir.
class ForumActionButton extends StatelessWidget {
  const ForumActionButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.label,
    this.color,
    this.size = 22,
    this.selected = false,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;
  final String? label;
  final Color? color;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final c = color ?? t.mut;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      child: BuPressable(
        onTap: onTap,
        scale: .94,
        haptic: BuHaptic.selection,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BuSize.touch, minWidth: BuSize.touch),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
            child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
              BuPopIcon(icon, size: size, color: c),
              if (label != null) ...[
                const SizedBox(width: 6),
                Text(label!,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: c, fontWeight: FontWeight.w400, fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// Konu görseli (yetkili uç: Bearer başlığıyla, küçük resim önce). Oran 1:1,25 ile 1,91 arasına sıkıştırılır,
/// yükseklik en çok 300 dp. [count] > 1 ise köşede "+N" rozeti.
class ForumTopicImage extends StatelessWidget {
  const ForumTopicImage({super.key, required this.session, required this.image, this.count = 1, this.radius = BuRadius.md, this.maxHeight = 300});

  final Session session;
  final ForumImage image;
  final int count;
  final double radius;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final headers = postAuthHeaders(session);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth.isFinite ? c.maxWidth : 360.0;
      final h = (w / image.aspect.clamp(0.8, 1.91)).clamp(0.0, maxHeight);
      final px = (w * dpr).ceil().clamp(240, 1080);
      final fade = BuMotion.of(context, BuMotion.medium);
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: w,
          height: h,
          child: ColoredBox(
            color: t.sf2,
            child: Stack(fit: StackFit.expand, children: [
              Image(
                image: persistentNetworkImage(image.thumbUrl ?? image.url, headers: headers, cacheWidth: px),
                key: ValueKey('forum-image-${image.id}'),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                excludeFromSemantics: true,
                frameBuilder: (context, child, frame, sync) =>
                    sync ? child : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: fade, curve: BuMotion.standard, child: child),
                errorBuilder: (_, __, ___) => Center(child: Icon(BuIcons.imageOff, color: t.mut)),
              ),
              if (count > 1)
                PositionedDirectional(
                  end: 8,
                  bottom: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: t.scrim.withValues(alpha: .6), borderRadius: BorderRadius.circular(6)),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 3),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(BuIcons.images, size: 14, color: t.onMedia),
                        const SizedBox(width: 4),
                        Text('$count', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.onMedia, fontWeight: FontWeight.w400)),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      );
    });
  }
}

/// Küçük durum rozeti (sabitlenmiş, kilitli, anket): nötr simge + metin, kırmızı kullanılmaz.
class ForumStatusChip extends StatelessWidget {
  const ForumStatusChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return DecoratedBox(
      decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.pill)),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 3, 10, 3),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          ExcludeSemantics(child: Icon(icon, size: 14, color: t.mut)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.mut, fontWeight: FontWeight.w500)),
          ),
        ]),
      ),
    );
  }
}

/// Forum akışı konu satırı (monochrome, metin odaklı): kart kutusu/gölge YOK, satırlar ince `bdSubtle` çizgiyle
/// ayrılır. Yazar satırı (+ üç nokta), rozetler, başlık (boyutla güçlü, kalın değil), 3 satırlık önizleme, görsel,
/// eylemler (beğeni, yorum, kaydet, paylaş). Beğeni/kaydet iyimser güncellenir; durum [onChanged] ile listeye yansır.
/// [showDivider] false ise alt çizgiyi çağıran çizer (altına şerit eklenen liste öğeleri).
class TopicCard extends StatelessWidget {
  const TopicCard({
    super.key,
    required this.session,
    required this.api,
    required this.topic,
    required this.onOpen,
    required this.onChanged,
    required this.onMenuResult,
    this.showDivider = true,
  });

  final Session session;
  final ForumApi api;
  final TopicSummary topic;
  final bool showDivider;

  /// Karta/yorum düğmesine dokunuş: konu detayı.
  final VoidCallback onOpen;
  final ValueChanged<TopicSummary> onChanged;
  final void Function(TopicSummary topic, TopicMenuResult result) onMenuResult;

  Future<void> _toggleSave(BuildContext context) async {
    final l = context.l10n;
    final want = !topic.savedByMe;
    onChanged(topic.copyWith(savedByMe: want));
    try {
      final ok = await setTopicSaved(api, topic, want);
      if (ok != want) onChanged(topic.copyWith(savedByMe: ok));
    } catch (_) {
      onChanged(topic);
      if (context.mounted) {
        BuToast.show(context, l.forumHomeSaveFailed,
            kind: BuToastKind.warning, actionLabel: l.commonRetryShort, onAction: () => _toggleSave(context));
      }
    }
  }

  Future<void> _menu(BuildContext context) async {
    final r = await showTopicMenu(context, session: session, api: api, topic: topic, onChanged: onChanged);
    if (r != TopicMenuResult.none) onMenuResult(topic, r);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    if (topic.removed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ForumNoticeBar(text: l.forumStateTopicRemoved, icon: BuIcons.eyeOff),
      );
    }
    final badges = <Widget>[
      if (topic.pinned) ForumStatusChip(icon: BuIcons.pin, label: l.forumHomePinned),
      if (topic.locked) ForumStatusChip(icon: BuIcons.lock, label: l.forumHomeLocked),
      if (topic.hasPoll) ForumStatusChip(icon: BuIcons.vote, label: l.forumHomePoll),
    ];
    return Semantics(
      container: true,
      child: DecoratedBox(
        key: ValueKey('forum-topic-${topic.id}'),
        decoration: BoxDecoration(
          color: t.sf,
          borderRadius: BorderRadius.circular(BuRadius.lg),
          border: Border.all(color: t.bd),
        ),
        child: Material(
          type: MaterialType.transparency,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(BuRadius.lg),
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ForumAuthorLine(
                  session: session,
                  author: topic.author,
                  createdAt: topic.createdAt,
                  edited: topic.edited,
                  categoryName: topic.category?.name,
                  trailing: Semantics(
                    button: true,
                    label: l.forumHomeMore,
                    excludeSemantics: true,
                    child: BuPressable(
                      onTap: () => _menu(context),
                      scale: .92,
                      child: SizedBox(
                        key: ValueKey('forum-more-${topic.id}'),
                        width: BuSize.touch,
                        height: BuSize.touch,
                        child: Icon(BuIcons.ellipsis, size: 22, color: t.mut),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (badges.isNotEmpty) ...[
                      BuGap.h4,
                      Wrap(spacing: 6, runSpacing: 6, children: badges),
                    ],
                    BuGap.h8,
                    Text.rich(
                        emojiAwareSpan(topic.title,
                            (tt.titleLarge ?? const TextStyle()).copyWith(color: t.ink, fontWeight: BuType.emphasisWeight, height: 1.3), scale: kEmojiTitleScale),
                        key: ValueKey('forum-title-${topic.id}'),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                    if (topic.bodyPreview.trim().isNotEmpty) ...[
                      BuGap.h6,
                      Text.rich(
                          emojiAwareSpan(topic.bodyPreview.trim(),
                              (tt.bodyMedium ?? const TextStyle()).copyWith(color: t.mut, height: 1.5)),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                    ],
                    if (topic.thumbnail != null) ...[
                      BuGap.h12,
                      ForumTopicImage(session: session, image: topic.thumbnail!, count: topic.imageCount),
                    ],
                    BuGap.h4,
                  ]),
                ),
                Row(children: [
                  ForumLikeButton(
                    liked: topic.likedByMe,
                    count: topic.likeCount,
                    onToggle: (want) => api.likeTopic(topic.id, want),
                    onChanged: (liked, count) => onChanged(topic.copyWith(likedByMe: liked, likeCount: count)),
                  ),
                  ForumActionButton(
                    key: ValueKey('forum-comments-${topic.id}'),
                    icon: BuIcons.messageSquare,
                    semanticLabel: l.forumHomeOpenComments,
                    label: topic.commentCount > 0 ? '${topic.commentCount}' : null,
                    onTap: onOpen,
                  ),
                  const Spacer(),
                  ForumActionButton(
                    key: ValueKey('forum-save-${topic.id}'),
                    icon: topic.savedByMe ? BuIcons.bookmarkFilled : BuIcons.bookmark,
                    semanticLabel: topic.savedByMe ? l.forumHomeUnsave : l.forumHomeSave,
                    selected: topic.savedByMe,
                    color: topic.savedByMe ? t.ink : t.mut,
                    onTap: () => _toggleSave(context),
                  ),
                  ForumActionButton(
                    key: ValueKey('forum-share-${topic.id}'),
                    icon: BuIcons.send,
                    semanticLabel: l.forumHomeShare,
                    onTap: () => openTopicShare(context, session, topic),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Yüklenirken konu kartı iskeleti: avatar + iki satır, başlık, önizleme, eylem çubuğu.
class TopicCardSkeleton extends StatelessWidget {
  const TopicCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(BuRadius.lg),
        border: Border.all(color: t.bd),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: BuSkeletonScope(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              BuSkeleton.circle(36),
              BuGap.w12,
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  BuSkeleton.line(width: 120, height: 12),
                  BuGap.h6,
                  BuSkeleton.line(width: 84, height: 10),
                ]),
              ),
            ]),
            BuGap.h16,
            BuSkeleton.line(height: 16),
            BuGap.h8,
            BuSkeleton.line(width: 220, height: 16),
            BuGap.h12,
            BuSkeleton.line(height: 12),
            BuGap.h6,
            BuSkeleton.line(height: 12),
            BuGap.h6,
            BuSkeleton.line(width: 160, height: 12),
            BuGap.h16,
            Row(children: [BuSkeleton.line(width: 48, height: 14), BuGap.w16, BuSkeleton.line(width: 48, height: 14)]),
          ]),
        ),
      ),
    );
  }
}
