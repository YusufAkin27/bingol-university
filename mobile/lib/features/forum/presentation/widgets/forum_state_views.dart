import 'package:flutter/material.dart';

import '../../../../core/api.dart';
import '../../../../core/locale_controller.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../widgets/bu.dart';

/// Forum hata kodunu kısa, anlaşılır mesaja çevirir (tüm forum ekranları bu TEK fonksiyonu kullanır).
/// Bilinen kodlar yerelleştirilmiş metne, bilinmeyenler sunucu mesajına, o da yoksa genel mesaja düşer.
String forumErrorText(Object e, AppLocalizations l) {
  if (e is! ApiError) return l.forumStateGeneric;
  if (e.isNetwork) return l.forumStateOffline;
  switch (e.code) {
    case 'FORUM_TOPIC_NOT_FOUND':
    case 'FORUM_COMMENT_NOT_FOUND':
    case 'NOT_FOUND':
      return l.forumStateNotFound;
    case 'FORUM_TOPIC_REMOVED':
      return l.forumStateTopicRemoved;
    case 'FORUM_COMMENT_REMOVED':
      return l.forumStateCommentRemoved;
    case 'FORUM_TOPIC_LOCKED':
      return l.forumStateLocked;
    case 'FORUM_NOT_OWNER':
    case 'ADMIN_PERMISSION_DENIED':
      return l.forumStateNotOwner;
    case 'FORUM_DUPLICATE_CONTENT':
      return l.forumStateDuplicate;
    case 'CONTENT_PROFANITY':
      return l.forumStateProfanity;
    case 'FORUM_POLL_CLOSED':
      return l.forumStatePollClosed;
    case 'FORUM_POLL_ALREADY_VOTED':
      return l.forumStateAlreadyVoted;
    case 'FORUM_EMPTY_CONTENT':
      return l.forumStateEmptyContent;
  }
  if (e.isAuthRejected) return l.forumStateSessionExpired;
  if (e.status == 429) return l.forumStateRateLimited;
  if (e.status == 403) return l.forumStateNoAccess;
  if (e.status == 404) return l.forumStateNotFound;
  if (e.status >= 500) return l.forumStateServerError;
  if (e.message.isNotEmpty) return e.message;
  return l.forumStateGeneric;
}

/// Boş liste durumu (kısa başlık + açıklama + isteğe bağlı eylem).
class ForumEmptyView extends StatelessWidget {
  const ForumEmptyView({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.compact = false,
  });

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) => BuEmptyState(
        title: title,
        message: message,
        icon: icon ?? BuIcons.messageSquareText,
        actionLabel: actionLabel,
        onAction: onAction,
        compact: compact,
      );
}

/// Hata / çevrimdışı durumu + "Yeniden dene". Mesaj [forumErrorText] ile üretilir.
class ForumErrorView extends StatelessWidget {
  const ForumErrorView({super.key, required this.error, required this.onRetry, this.compact = false});

  final Object error;
  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) =>
      BuErrorState(error: error, message: forumErrorText(error, context.l10n), onRetry: onRetry, compact: compact);
}

/// Satır içi bilgi şeridi: kilitli konu, kaldırılmış içerik, silinmiş yorum gibi sessiz durumlar için.
class ForumNoticeBar extends StatelessWidget {
  const ForumNoticeBar({super.key, required this.text, this.icon, this.margin});

  final String text;
  final IconData? icon;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      child: Container(
        margin: margin,
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
        decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.sm)),
        child: Row(children: [
          if (icon != null) ...[
            ExcludeSemantics(child: Icon(icon, size: 18, color: t.mut)),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(text, style: tx.bodyMedium?.copyWith(color: t.mut, height: 1.4))),
        ]),
      ),
    );
  }
}
