package edu.bingol.backend.moderation;

/**
 * Raporlanabilir icerik turleri (en fazla 16 karakter: report.target_type sutunu). Her tur icin bir
 * {@link ReportTargetHandler} bean'i kayitli olmalidir; kayitsiz tur raporlandiginda TARGET_TYPE_UNSUPPORTED doner.
 * Medya turleri (MESSAGE_IMAGE, USER_AVATAR, COMMUNITY_COVER, EVENT_COVER) ilgili modulce eklenen handler'larla etkinlesir.
 */
public enum ReportTargetType {
    USER, MESSAGE, POST, COMMUNITY, EVENT,
    MESSAGE_IMAGE, USER_AVATAR, COMMUNITY_COVER, EVENT_COVER,
    /** Kesfet akisi gonderisi (post paketi, bkz. docs/POSTS_DESIGN.md). */
    FEED_POST
}
