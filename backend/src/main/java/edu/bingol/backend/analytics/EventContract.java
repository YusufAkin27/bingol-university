package edu.bingol.backend.analytics;

import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;

/**
 * Davranis analizi olay sozlesmesi (mobil -> sunucu; docs/MOBILE_API_GUIDE.md "Kullanim analizi"): `props.sid` oturum
 * kimligi, `session_end/screen_exit` sureleri ve `action.kind` beyaz listesi. Saf fonksiyon; sozlesmeyi bozan olay
 * istegi dusurmez, TEK TEK elenir (sayac artmaz, hata donmez). Eski olaylar (app_open, search...) etkilenmez.
 */
public final class EventContract {

    static final long MAX_DURATION_MS = 86_400_000L;
    static final int MAX_SCREENS = 100_000;

    /** Oturum kimligi: rastgele, kisisel veri degil. */
    private static final Pattern SID = Pattern.compile("[a-z0-9]{8,32}");
    private static final Pattern TARGET = Pattern.compile("[a-z0-9_]{1,40}");

    /** Izinli eylem turleri (sunucu beyaz listesi; yonetici eylem raporu da bunu kullanir). */
    public static final Set<String> ACTION_KINDS = Set.of("like", "unlike", "follow", "unfollow", "share", "bookmark",
            "join_club", "leave_club", "rsvp", "checkin", "vote", "rate_menu", "search_submit", "send_message",
            "post_create", "ticket_create", "ticket_reply", "profile_edit", "notif_open", "push_open", "pull_refresh",
            "tab_switch");
    static final Set<String> END_REASONS = Set.of("background", "exit", "timeout");

    private EventContract() {}

    /** Olay sozlesmeye uyuyor mu (uymazsa atilir). `props` bos olabilir. */
    static boolean accepts(String name, String screen, Map<String, Object> props) {
        Map<String, Object> p = props == null ? Map.of() : props;
        Object sid = p.get("sid");
        if (sid != null && !(sid instanceof String s && SID.matcher(s).matches())) {
            return false;
        }
        switch (name) {
            case "session_end":
                return duration(p.get("durationMs"), true)
                        && (p.get("screens") == null || integer(p.get("screens"), 0, MAX_SCREENS))
                        && (p.get("reason") == null
                                || (p.get("reason") instanceof String r && END_REASONS.contains(r)));
            case "screen_exit":
                return screen != null && duration(p.get("dwellMs"), true);
            case "action":
                return p.get("kind") instanceof String k && ACTION_KINDS.contains(k)
                        && (p.get("target") == null
                                || (p.get("target") instanceof String t && TARGET.matcher(t).matches()));
            default:
                return true;
        }
    }

    private static boolean duration(Object v, boolean required) {
        if (v == null) {
            return !required;
        }
        return integer(v, 0, MAX_DURATION_MS);
    }

    /** Sayi, tam sayi degerli (1200.0 olur, 12.5 olmaz) ve aralikta. */
    private static boolean integer(Object v, long min, long max) {
        if (!(v instanceof Number n)) {
            return false;
        }
        double d = n.doubleValue();
        return !Double.isNaN(d) && !Double.isInfinite(d) && d == Math.rint(d) && d >= min && d <= max;
    }
}
