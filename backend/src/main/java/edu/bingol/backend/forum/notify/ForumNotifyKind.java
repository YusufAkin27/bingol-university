package edu.bingol.backend.forum.notify;

import edu.bingol.backend.notification.NotificationSubtype;
import edu.bingol.backend.notification.NotificationType;
import java.util.function.Predicate;

/**
 * Forum bildirim turleri (sozlesme: FORUM_API.md 2-E). Hepsi {@code type=FORUM} + {@code subtype=FORUM_*} gider;
 * moderasyon istisna: {@code type=SYSTEM} (tercihle susturulamaz) ve veride {@code forumKind=FORUM_MODERATION}.
 */
public enum ForumNotifyKind {
    FORUM_TOPIC_COMMENT(NotificationType.FORUM, NotificationSubtype.FORUM_TOPIC_COMMENT, "topicComment",
            ForumNotificationPref::isTopicComments),
    FORUM_COMMENT_REPLY(NotificationType.FORUM, NotificationSubtype.FORUM_COMMENT_REPLY, "commentReply",
            ForumNotificationPref::isCommentReplies),
    FORUM_COMMENT_LIKE(NotificationType.FORUM, NotificationSubtype.FORUM_COMMENT_LIKE, "commentLike",
            ForumNotificationPref::isLikes),
    FORUM_TOPIC_LIKE(NotificationType.FORUM, NotificationSubtype.FORUM_TOPIC_LIKE, "topicLike",
            ForumNotificationPref::isLikes),
    FORUM_FOLLOWED_TOPIC_COMMENT(NotificationType.FORUM, NotificationSubtype.FORUM_FOLLOWED_TOPIC_COMMENT,
            "followedTopic", ForumNotificationPref::isFollowedTopics),
    FORUM_MODERATION(NotificationType.SYSTEM, null, "moderation", p -> true);

    private final NotificationType type;
    private final NotificationSubtype subtype;
    private final String i18nKey;
    private final Predicate<ForumNotificationPref> allowedBy;

    ForumNotifyKind(NotificationType type, NotificationSubtype subtype, String i18nKey,
                    Predicate<ForumNotificationPref> allowedBy) {
        this.type = type;
        this.subtype = subtype;
        this.i18nKey = i18nKey;
        this.allowedBy = allowedBy;
    }

    public NotificationType type() {
        return type;
    }

    public NotificationSubtype subtype() {
        return subtype;
    }

    /** {@code notif.forum.<anahtar>.title|body} */
    public String i18nKey() {
        return i18nKey;
    }

    /** Alicinin tercihi bu turu gonderilmeye izin veriyor mu (moderasyon her zaman evet). */
    public boolean allowed(ForumNotificationPref p) {
        if (this == FORUM_MODERATION) {
            return true;
        }
        return p == null || (p.isAllEnabled() && allowedBy.test(p));
    }

    /** Birlesme/tekrar defteri anahtari onek kisaltmasi. */
    public String ledgerKind() {
        return switch (this) {
            case FORUM_TOPIC_COMMENT -> "TC";
            case FORUM_COMMENT_REPLY -> "CR";
            case FORUM_COMMENT_LIKE -> "CL";
            case FORUM_TOPIC_LIKE -> "TL";
            case FORUM_FOLLOWED_TOPIC_COMMENT -> "FT";
            case FORUM_MODERATION -> "MD";
        };
    }
}
