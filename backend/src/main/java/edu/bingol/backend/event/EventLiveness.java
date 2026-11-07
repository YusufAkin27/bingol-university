package edu.bingol.backend.event;

import java.time.Instant;

/**
 * Etkinligin "guncel" olup olmadigi tek yerde: yayinda (ACTIVE) ve bitis ani gelmemis. Bitis kurali
 * (docs/changes/event.md "Biten etkinlikler"): endsAt zorunlu alan oldugundan etkinlik tam endsAt aninda biter;
 * karsilastirma UTC anlariyla yapilir (saat dilimi etkisi yok). Bildirim gonderiminden hemen once kullanilir.
 */
public final class EventLiveness {

    private EventLiveness() {
    }

    /** ACTIVE ve endsAt > now (suren etkinlik dahil). */
    public static boolean isLive(UserEvent e, Instant now) {
        return e != null && e.getStatus() == UserEvent.Status.ACTIVE
                && e.getEndsAt() != null && e.getEndsAt().isAfter(now);
    }

    /** Bildirim projeksiyonu icin durum: LIVE | ENDED | CANCELLED | UNAVAILABLE (gizli/reddedilen/bekleyen). */
    public static String state(UserEvent e, Instant now) {
        if (e == null) {
            return "UNAVAILABLE";
        }
        return switch (e.getStatus()) {
            case CANCELLED -> "CANCELLED";
            case ACTIVE -> e.getEndsAt() != null && !e.getEndsAt().isAfter(now) ? "ENDED" : "LIVE";
            default -> "UNAVAILABLE";
        };
    }
}
