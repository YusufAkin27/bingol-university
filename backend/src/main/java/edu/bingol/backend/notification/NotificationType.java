package edu.bingol.backend.notification;

/** Bildirim turu; kullanici tercihleri (NotificationPref) bu turlere gore filtreler. SYSTEM her zaman gider. */
public enum NotificationType {
    NEWS("news"), ANNOUNCEMENT("announcements"), EVENT("events"),
    MESSAGE("messages"), COMMUNITY("communities"), SYSTEM("system");

    private final String prefColumn;

    NotificationType(String prefColumn) {
        this.prefColumn = prefColumn;
    }

    /** notification_pref tablosundaki sutun adi (SYSTEM icin "system": tercih yok, hep true). */
    public String prefColumn() {
        return prefColumn;
    }
}
