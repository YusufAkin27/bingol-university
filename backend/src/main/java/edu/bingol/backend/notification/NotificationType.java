package edu.bingol.backend.notification;

/** Bildirim turu; kullanici tercihleri (NotificationPref) bu turlere gore filtreler. SYSTEM her zaman gider. */
public enum NotificationType {
    NEWS("news"), ANNOUNCEMENT("announcements"), EVENT("events"),
    MESSAGE("messages"), COMMUNITY("communities"), SYSTEM("system"),
    // Gonderi etkilesimleri: tercih sutunu yeni migration gerektirmesin diye "communities" bayragina baglidir;
    // tek tek kapatmak icin alt tur (NotificationSubtype POST_LIKE...) kullanilir.
    POST_LIKE("communities"), POST_COMMENT("communities"), COMMENT_REPLY("communities"),
    // Sosyal (etiket, takip): yine "communities" bayragi; alt tur ile ayri kapatilir
    POST_MENTION("communities"), USER_FOLLOW("communities");

    private final String prefColumn;

    NotificationType(String prefColumn) {
        this.prefColumn = prefColumn;
    }

    /** notification_pref tablosundaki sutun adi (SYSTEM icin "system": tercih yok, hep true). */
    public String prefColumn() {
        return prefColumn;
    }
}
