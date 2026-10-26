package edu.bingol.backend.notification;

import java.time.DateTimeException;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.regex.Pattern;

/** Sessiz saat hesabi (saf fonksiyonlar; gece yarisini asan araliklari destekler). */
public final class QuietHours {

    /** Postgres'e dogrudan gittigi icin (AT TIME ZONE) dar bir bicim zorunlu. */
    private static final Pattern ZONE = Pattern.compile("[A-Za-z]+(/[A-Za-z_+\\-0-9]+){1,2}|UTC");

    private QuietHours() {}

    public static boolean validMinute(int m) {
        return m >= 0 && m < 1440;
    }

    public static boolean validZone(String zone) {
        if (zone == null || zone.length() > 48 || !ZONE.matcher(zone).matches()) {
            return false;
        }
        try {
            ZoneId.of(zone);
            return true;
        } catch (DateTimeException e) {
            return false;
        }
    }

    /** start == end gecersiz sayilir (bos aralik mi tum gun mu belirsiz); servis katmani reddeder. */
    public static boolean isQuiet(boolean enabled, int start, int end, String zone, Instant now) {
        if (!enabled || start == end || !validZone(zone)) {
            return false;
        }
        ZonedDateTime t = now.atZone(ZoneId.of(zone));
        int minute = t.getHour() * 60 + t.getMinute();
        return start < end ? minute >= start && minute < end : minute >= start || minute < end;
    }

    public static boolean isQuiet(NotificationPref p, Instant now) {
        return p != null && isQuiet(p.isQuietEnabled(), p.getQuietStart(), p.getQuietEnd(), p.getTimezone(), now);
    }
}
