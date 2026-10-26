package edu.bingol.backend.event.extras;

import edu.bingol.backend.event.UserEvent;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.List;

/** RFC 5545 takvim dosyasi uretici (saf fonksiyon). Satir sonu CRLF, 75 oktette katlama, metin kacislari. */
public final class IcsWriter {

    static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");
    private static final DateTimeFormatter LOCAL = DateTimeFormatter.ofPattern("yyyyMMdd'T'HHmmss");
    private static final DateTimeFormatter UTC = DateTimeFormatter.ofPattern("yyyyMMdd'T'HHmmss'Z'").withZone(ZoneOffset.UTC);
    private static final String CRLF = "\r\n";

    private IcsWriter() {}

    public static String calendar(String name, List<UserEvent> events, Instant now) {
        StringBuilder sb = new StringBuilder();
        line(sb, "BEGIN:VCALENDAR");
        line(sb, "VERSION:2.0");
        line(sb, "PRODID:-//BU Kampus//Events//TR");
        line(sb, "CALSCALE:GREGORIAN");
        line(sb, "METHOD:PUBLISH");
        line(sb, "X-WR-CALNAME:" + escape(name));
        line(sb, "X-WR-TIMEZONE:Europe/Istanbul");
        // Turkiye 2016'dan beri kalici UTC+3 (yaz saati yok).
        line(sb, "BEGIN:VTIMEZONE");
        line(sb, "TZID:Europe/Istanbul");
        line(sb, "BEGIN:STANDARD");
        line(sb, "DTSTART:19700101T000000");
        line(sb, "TZOFFSETFROM:+0300");
        line(sb, "TZOFFSETTO:+0300");
        line(sb, "TZNAME:+03");
        line(sb, "END:STANDARD");
        line(sb, "END:VTIMEZONE");
        for (UserEvent e : events) {
            event(sb, e, now);
        }
        line(sb, "END:VCALENDAR");
        return sb.toString();
    }

    private static void event(StringBuilder sb, UserEvent e, Instant now) {
        line(sb, "BEGIN:VEVENT");
        line(sb, "UID:event-" + e.getId() + "@bingol.edu.tr");
        line(sb, "DTSTAMP:" + UTC.format(now));
        line(sb, "LAST-MODIFIED:" + UTC.format(e.getUpdatedAt()));
        line(sb, "DTSTART;TZID=Europe/Istanbul:" + LOCAL.format(e.getStartsAt().atZone(ZONE)));
        line(sb, "DTEND;TZID=Europe/Istanbul:" + LOCAL.format(e.getEndsAt().atZone(ZONE)));
        line(sb, "SUMMARY:" + escape(e.getTitle()));
        if (e.getDescription() != null) {
            line(sb, "DESCRIPTION:" + escape(e.getDescription()));
        }
        if (e.getLocation() != null) {
            line(sb, "LOCATION:" + escape(e.getLocation()));
        }
        line(sb, "STATUS:" + (e.getStatus() == UserEvent.Status.CANCELLED ? "CANCELLED" : "CONFIRMED"));
        line(sb, "END:VEVENT");
    }

    /** TEXT degeri kacisi: \ ; , ve satir sonlari; diger kontrol karakterleri atilir (satir enjeksiyonu olmaz). */
    static String escape(String s) {
        if (s == null) {
            return "";
        }
        StringBuilder o = new StringBuilder(s.length() + 8);
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '\\' -> o.append("\\\\");
                case ';' -> o.append("\\;");
                case ',' -> o.append("\\,");
                case '\n' -> o.append("\\n");
                case '\r' -> {
                    if (i + 1 >= s.length() || s.charAt(i + 1) != '\n') {
                        o.append("\\n");
                    }
                }
                default -> {
                    if (c >= 0x20 && c != 0x7f) {
                        o.append(c);
                    }
                }
            }
        }
        return o.toString();
    }

    /** Icerik satirini 75 oktetten uzunsa CRLF + bosluk ile katlar (UTF-8 karakter ortasindan bolmeden). */
    static void line(StringBuilder out, String content) {
        int limit = 75;
        int used = 0;
        StringBuilder cur = new StringBuilder();
        for (int i = 0; i < content.length(); ) {
            int cp = content.codePointAt(i);
            String ch = new String(Character.toChars(cp));
            int len = ch.getBytes(StandardCharsets.UTF_8).length;
            if (used + len > limit) {
                out.append(cur).append(CRLF);
                cur.setLength(0);
                cur.append(' ');
                used = 1;
                limit = 75;
            }
            cur.append(ch);
            used += len;
            i += Character.charCount(cp);
        }
        out.append(cur).append(CRLF);
    }
}
