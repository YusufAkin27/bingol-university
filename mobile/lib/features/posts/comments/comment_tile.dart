import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/locale_controller.dart';
import '../../../core/session.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/bu.dart';
import '../avatar_preview.dart';
import '../post_models.dart';
import '../../profile/user_profile_page.dart' show openUserProfile;
import 'comment_models.dart';

/// Tek yorum / yanıt satırı: avatar (üst düzey 36 dp, yanıt 28 dp) + kullanıcı adı + göreli zaman + metin; sağda küçük
/// kalp (beğeni sayısı), altta "Yanıtla" ve ⋯ menüsü. Silinmiş yorum yer tutucu çizer; iyimser/başarısız durum kendi
/// satırında gösterilir. Renkler yalnız `context.bu`; kalın yazı yok; dokunma hedefleri >= 44 dp.
class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.session,
    required this.comment,
    required this.onLike,
    required this.onReply,
    required this.onMenu,
    required this.onRetry,
    this.compact = false,
    this.highlighted = false,
    this.readOnly = false,
    this.replyEnabled = true,
  });

  /// Yorumlar kapalıyken "Yanıtla" gizlenir (beğeni dokunuşu üst katmanda bilgi verir; menü/silme sürer).
  final bool replyEnabled;

  final Session session;
  final PostComment comment;
  final bool compact;
  final bool highlighted;

  /// Önizleme: yalnız okunur (eylem yok, tek satırlık özet).
  final bool readOnly;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final VoidCallback onMenu;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final c = comment;
    final size = compact ? 28.0 : 36.0;
    final a = c.author;
    final sending = c.sendState == CommentSendState.sending;
    final failed = c.sendState == CommentSendState.failed;

    Widget avatar;
    if (c.deleted || a == null) {
      avatar = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle),
        child: Icon(BuIcons.messageCircle, size: size * .5, color: t.mut),
      );
    } else {
      avatar = AvatarPreviewTap(
        session: session,
        url: a.avatarUrl,
        name: a.displayName,
        onTap: () => openUserProfile(context, session, userId: a.userId, name: a.displayName, avatarUrl: a.avatarUrl),
        child: BuAvatar(name: a.displayName, url: a.avatarUrl, size: size, headers: postAuthHeaders(session)),
      );
    }

    final Widget content;
    if (c.deleted) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(l.pcmDeleted,
            key: ValueKey('commentDeleted-${c.id}'), style: tt.bodyMedium?.copyWith(color: t.mut, fontStyle: FontStyle.italic)),
      );
    } else {
      content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(text: a?.handle ?? '', style: tt.bodyMedium?.copyWith(color: t.ink, fontWeight: BuType.emphasisWeight)),
            TextSpan(text: '  ${postRelativeTime(context, c.createdAt)}', style: tt.bodySmall?.copyWith(color: t.mut)),
          ]),
        ),
        const SizedBox(height: 2),
        Text(c.body ?? '',
            maxLines: readOnly ? 2 : null,
            overflow: readOnly ? TextOverflow.ellipsis : null,
            style: tt.bodyMedium?.copyWith(color: t.ink, height: 1.35)),
        if (!readOnly) _actions(context, t, tt, l, sending: sending, failed: failed),
      ]);
    }

    final body = Padding(
      padding: EdgeInsetsDirectional.only(start: BuSpace.page, end: 4, top: compact ? 2 : 6, bottom: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: avatar),
        const SizedBox(width: 10),
        Expanded(child: Opacity(opacity: sending ? .55 : 1, child: content)),
        if (!c.deleted && !readOnly && !c.isLocal)
          _LikeHeart(
            commentId: c.id,
            liked: c.likedByMe,
            count: c.likeCount,
            onTap: onLike,
          )
        else
          const SizedBox(width: 12),
      ]),
    );

    final tile = AnimatedContainer(
      duration: AppMotion.of(context, AppMotion.normal),
      color: highlighted ? t.soft : Colors.transparent,
      child: body,
    );
    if (readOnly || c.deleted) return tile;
    return GestureDetector(behavior: HitTestBehavior.translucent, onLongPress: onMenu, child: tile);
  }

  Widget _actions(BuildContext context, BuTokens t, TextTheme tt, AppLocalizations l, {required bool sending, required bool failed}) {
    if (failed) {
      return Semantics(
        button: true,
        child: InkWell(
          key: ValueKey('commentRetry-${comment.id}'),
          onTap: onRetry,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text('${l.pcmSendFailed} · ${l.pcmRetry}', style: tt.labelMedium?.copyWith(color: t.danger)),
            ),
          ),
        ),
      );
    }
    if (sending) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Align(alignment: AlignmentDirectional.centerStart, child: Text(l.pcmSending, style: tt.labelMedium?.copyWith(color: t.mut))),
      );
    }
    return Row(children: [
      if (replyEnabled)
      InkWell(
        key: ValueKey('commentReply-${comment.id}'),
        onTap: onReply,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Align(
            widthFactor: 1,
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: Text(l.kesCommentsReply, style: tt.labelMedium?.copyWith(color: t.mut)),
            ),
          ),
        ),
      ),
      IconButton(
        key: ValueKey('commentMenu-${comment.id}'),
        tooltip: l.pcmMoreActions,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        padding: EdgeInsets.zero,
        icon: Icon(BuIcons.ellipsis, size: 18, color: t.mut),
        onPressed: onMenu,
      ),
    ]);
  }
}

/// Sağdaki kalp + sayı: 48 dp dokunma alanı; beğenince kısa "pop" (hareket azaltılmışsa animasyonsuz).
class _LikeHeart extends StatefulWidget {
  const _LikeHeart({required this.commentId, required this.liked, required this.count, required this.onTap});

  final int commentId;
  final bool liked;
  final int count;
  final VoidCallback onTap;

  @override
  State<_LikeHeart> createState() => _LikeHeartState();
}

class _LikeHeartState extends State<_LikeHeart> {
  bool _pop = false;

  @override
  void didUpdateWidget(covariant _LikeHeart old) {
    super.didUpdateWidget(old);
    if (!old.liked && widget.liked && !BuMotion.reduced(context)) {
      setState(() => _pop = true);
      Future<void>.delayed(AppMotion.fast, () {
        if (mounted) setState(() => _pop = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final label = widget.liked ? l.pcmUnlikeA11y : l.pcmLikeA11y;
    return Semantics(
      button: true,
      label: widget.count > 0 ? '$label, ${l.pcmLikeCountA11y('${widget.count}')}' : label,
      excludeSemantics: true,
      child: InkResponse(
        key: ValueKey('commentLike-${widget.commentId}'),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        radius: 24,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedScale(
              scale: _pop ? 1.3 : 1,
              duration: AppMotion.of(context, AppMotion.fast),
              curve: BuMotion.standard,
              child: Icon(widget.liked ? BuIcons.heartFilled : BuIcons.heart, size: 18, color: widget.liked ? t.heart : t.mut),
            ),
            if (widget.count > 0)
              Text('${widget.count}',
                  style: tt.labelSmall?.copyWith(color: t.mut, fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
        ),
      ),
    );
  }
}
