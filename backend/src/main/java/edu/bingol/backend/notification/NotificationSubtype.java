package edu.bingol.backend.notification;

/**
 * Ana turun alt turleri; kullanici tercihleri alt tur bazinda da tutulur (ana bayrak kapaliysa alt tur de kapali).
 * Yeni ozellik yeni alt tur eklerse yalnizca buraya satir ekler.
 */
public enum NotificationSubtype {
    MESSAGE_DIRECT(NotificationType.MESSAGE), MESSAGE_GROUP(NotificationType.MESSAGE),
    EVENT_REMINDER(NotificationType.EVENT), EVENT_UPDATE(NotificationType.EVENT),
    EVENT_ADMISSION(NotificationType.EVENT),
    COMMUNITY_POST(NotificationType.COMMUNITY), COMMUNITY_ROLE(NotificationType.COMMUNITY),
    COMMUNITY_JOIN(NotificationType.COMMUNITY),
    POST_LIKE(NotificationType.POST_LIKE), POST_COMMENT(NotificationType.POST_COMMENT),
    COMMENT_REPLY(NotificationType.COMMENT_REPLY),
    POST_MENTION(NotificationType.POST_MENTION), USER_FOLLOW(NotificationType.USER_FOLLOW),
    FOLLOW_REQUEST(NotificationType.FOLLOW_REQUEST), FOLLOW_ACCEPTED(NotificationType.FOLLOW_ACCEPTED),
    // Kampus Forum (FORUM_MODERATION alt tur DEGIL: SYSTEM alt tur alamaz; veride forumKind=FORUM_MODERATION)
    FORUM_TOPIC_COMMENT(NotificationType.FORUM), FORUM_COMMENT_REPLY(NotificationType.FORUM),
    FORUM_COMMENT_LIKE(NotificationType.FORUM), FORUM_TOPIC_LIKE(NotificationType.FORUM),
    FORUM_FOLLOWED_TOPIC_COMMENT(NotificationType.FORUM),
    // Kendi bayragi olanlar (notification_pref.polls / academic_announcements, V880; ikincisi sinav hatirlatmasina kaldi): ana tur bayragindan bagimsizdir
    POLL(NotificationType.ANNOUNCEMENT),
    // Sinav hatirlatmasi (sinavdan 2 sa once): "Akademik duyurular" bayragini (academic_announcements) paylasir;
    // ayri sutun yok, kullanici tek akademik anahtarla ikisini birden yonetir.
    EXAM_REMINDER(NotificationType.ANNOUNCEMENT),
    // Gunluk menu bildirimi: notification_pref.meal_menu (V1271), varsayilan ACIK (V1461; kullanici tercihlerden kapatir)
    MEAL_MENU(NotificationType.ANNOUNCEMENT);

    private final NotificationType parent;

    NotificationSubtype(NotificationType parent) {
        this.parent = parent;
    }

    public NotificationType parent() {
        return parent;
    }

    /** Alt tur bayragi notification_pref'te ayri sutunda tutuluyor mu (alt tur satiri degil). */
    public boolean flagBacked() {
        return this == POLL || this == EXAM_REMINDER || this == MEAL_MENU;
    }

    /** flagBacked alt turler icin kullanicinin bayragi; digerleri icin true. */
    public boolean flag(NotificationPref p) {
        return switch (this) {
            case POLL -> p.isPolls();
            case EXAM_REMINDER -> p.isAcademicAnnouncements();
            case MEAL_MENU -> p.isMealMenu();
            default -> true;
        };
    }

    /** Gecersiz ad icin null doner. */
    public static NotificationSubtype parse(String s) {
        if (s == null) {
            return null;
        }
        try {
            return valueOf(s.trim().toUpperCase(java.util.Locale.ROOT));
        } catch (IllegalArgumentException e) {
            return null;
        }
    }
}
