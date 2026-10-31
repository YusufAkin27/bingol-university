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
    // Kendi bayragi olanlar (notification_pref.polls / academic_announcements, V880): ana tur bayragindan bagimsizdir
    POLL(NotificationType.ANNOUNCEMENT), ACADEMIC_ANNOUNCEMENT(NotificationType.ANNOUNCEMENT),
    // Sinav hatirlatmasi (sinavdan 2 sa once): "Akademik duyurular" bayragini (academic_announcements) paylasir;
    // ayri sutun yok, kullanici tek akademik anahtarla ikisini birden yonetir.
    EXAM_REMINDER(NotificationType.ANNOUNCEMENT);

    private final NotificationType parent;

    NotificationSubtype(NotificationType parent) {
        this.parent = parent;
    }

    public NotificationType parent() {
        return parent;
    }

    /** Alt tur bayragi notification_pref'te ayri sutunda tutuluyor mu (alt tur satiri degil). */
    public boolean flagBacked() {
        return this == POLL || this == ACADEMIC_ANNOUNCEMENT || this == EXAM_REMINDER;
    }

    /** flagBacked alt turler icin kullanicinin bayragi; digerleri icin true. */
    public boolean flag(NotificationPref p) {
        return switch (this) {
            case POLL -> p.isPolls();
            case ACADEMIC_ANNOUNCEMENT, EXAM_REMINDER -> p.isAcademicAnnouncements();
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
