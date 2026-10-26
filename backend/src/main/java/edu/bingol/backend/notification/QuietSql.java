package edu.bingol.backend.notification;

/**
 * Native sorgularda "kullanici su an sessiz saatte degil" kosulu (p = notification_pref takma adi, :col = tur sutunu).
 * SYSTEM turu ('system') sessiz saati asar; tercih satiri olmayanlar sessiz degildir. Saat dilimi QuietHours ile dogrulanir.
 */
final class QuietSql {

    private static final String MINUTE =
            "(EXTRACT(HOUR FROM (now() AT TIME ZONE p.timezone)) * 60 + EXTRACT(MINUTE FROM (now() AT TIME ZONE p.timezone)))";

    static final String NOT_QUIET = "(:col = 'system' OR p.user_id IS NULL OR p.quiet_enabled = FALSE"
            + " OR p.quiet_start = p.quiet_end OR NOT (CASE WHEN p.quiet_start < p.quiet_end"
            + " THEN " + MINUTE + " >= p.quiet_start AND " + MINUTE + " < p.quiet_end"
            + " ELSE " + MINUTE + " >= p.quiet_start OR " + MINUTE + " < p.quiet_end END))";

    private QuietSql() {}
}
