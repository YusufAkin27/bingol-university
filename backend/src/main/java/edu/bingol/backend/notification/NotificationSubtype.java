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
    COMMUNITY_JOIN(NotificationType.COMMUNITY);

    private final NotificationType parent;

    NotificationSubtype(NotificationType parent) {
        this.parent = parent;
    }

    public NotificationType parent() {
        return parent;
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
