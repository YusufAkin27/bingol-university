package edu.bingol.backend.academic;

import java.nio.charset.StandardCharsets;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.time.temporal.TemporalAdjusters;
import java.util.List;

/** Ders programi icin RFC 5545 takvim dosyasi: VTIMEZONE Europe/Istanbul, haftalik RRULE (donem bitisine kadar). */
public final class IcsBuilder {

    private static final DateTimeFormatter LOCAL = DateTimeFormatter.ofPattern("yyyyMMdd'T'HHmmss");
    private static final DateTimeFormatter UTC = DateTimeFormatter.ofPattern("yyyyMMdd'T'HHmmss'Z'");
    private static final String[] BYDAY = {"MO", "TU", "WE", "TH", "FR", "SA", "SU"};
    private static final int FALLBACK_WEEKS = 16;

    private IcsBuilder() {}

    public record SessionEvent(long sessionId, String name, String code, String instructor, String room,
                               int day, LocalTime start, LocalTime end) {}

    public record ExamEvent(long id, String title, String course, String room, Instant startsAt, Instant endsAt) {}

    /**
     * @param semStart donem baslangici (null ise {@code today} kullanilir)
     * @param semEnd   donem bitisi (null ise baslangictan 16 hafta)
     */
    public static String build(List<SessionEvent> sessions, List<ExamEvent> exams, LocalDate semStart,
                               LocalDate semEnd, LocalDate today, Instant now) {
        LocalDate from = semStart != null ? semStart : today;
        LocalDate until = semEnd != null ? semEnd : from.plusWeeks(FALLBACK_WEEKS);
        String stamp = UTC.format(now.atOffset(ZoneOffset.UTC));
        StringBuilder sb = new StringBuilder();
        line(sb, "BEGIN:VCALENDAR");
        line(sb, "VERSION:2.0");
        line(sb, "PRODID:-//Bingol Universitesi//BU Kampus//TR");
        line(sb, "CALSCALE:GREGORIAN");
        line(sb, "X-WR-CALNAME:Ders Programı");
        line(sb, "X-WR-TIMEZONE:Europe/Istanbul");
        line(sb, "BEGIN:VTIMEZONE");
        line(sb, "TZID:Europe/Istanbul");
        line(sb, "BEGIN:STANDARD");
        line(sb, "DTSTART:19700101T000000");
        line(sb, "TZOFFSETFROM:+0300");
        line(sb, "TZOFFSETTO:+0300");
        line(sb, "TZNAME:+03");
        line(sb, "END:STANDARD");
        line(sb, "END:VTIMEZONE");
        // UNTIL: son gunun sonu (Istanbul) -> UTC
        String untilUtc = UTC.format(until.plusDays(1).atStartOfDay(AcademicTime.ZONE).minusSeconds(1)
                .withZoneSameInstant(ZoneOffset.UTC));
        for (SessionEvent s : sessions) {
            LocalDate first = from.with(TemporalAdjusters.nextOrSame(DayOfWeek.of(s.day())));
            if (first.isAfter(until)) {
                continue;
            }
            line(sb, "BEGIN:VEVENT");
            line(sb, "UID:bu-session-" + s.sessionId() + "@bingol.edu.tr");
            line(sb, "DTSTAMP:" + stamp);
            line(sb, "DTSTART;TZID=Europe/Istanbul:" + LOCAL.format(first.atTime(s.start())));
            line(sb, "DTEND;TZID=Europe/Istanbul:" + LOCAL.format(first.atTime(s.end())));
            line(sb, "RRULE:FREQ=WEEKLY;BYDAY=" + BYDAY[s.day() - 1] + ";UNTIL=" + untilUtc);
            line(sb, "SUMMARY:" + esc(s.name()));
            if (s.room() != null && !s.room().isBlank()) {
                line(sb, "LOCATION:" + esc(s.room()));
            }
            String desc = describe(s.code(), s.instructor());
            if (!desc.isEmpty()) {
                line(sb, "DESCRIPTION:" + esc(desc));
            }
            line(sb, "END:VEVENT");
        }
        for (ExamEvent e : exams) {
            Instant end = e.endsAt() != null ? e.endsAt() : e.startsAt().plusSeconds(3600);
            line(sb, "BEGIN:VEVENT");
            line(sb, "UID:bu-exam-" + e.id() + "@bingol.edu.tr");
            line(sb, "DTSTAMP:" + stamp);
            line(sb, "DTSTART;TZID=Europe/Istanbul:" + LOCAL.format(e.startsAt().atZone(AcademicTime.ZONE)));
            line(sb, "DTEND;TZID=Europe/Istanbul:" + LOCAL.format(end.atZone(AcademicTime.ZONE)));
            line(sb, "SUMMARY:" + esc((e.course() != null ? e.course() + " - " : "") + e.title()));
            if (e.room() != null && !e.room().isBlank()) {
                line(sb, "LOCATION:" + esc(e.room()));
            }
            line(sb, "END:VEVENT");
        }
        line(sb, "END:VCALENDAR");
        return sb.toString();
    }

    private static String describe(String code, String instructor) {
        StringBuilder d = new StringBuilder();
        if (code != null && !code.isBlank()) {
            d.append(code);
        }
        if (instructor != null && !instructor.isBlank()) {
            if (d.length() > 0) {
                d.append(" - ");
            }
            d.append(instructor);
        }
        return d.toString();
    }

    static String esc(String s) {
        return s.replace("\\", "\\\\").replace(";", "\\;").replace(",", "\\,")
                .replace("\r\n", "\\n").replace("\n", "\\n").replace("\r", "\\n");
    }

    /** 75 oktet sinirinda katlama (UTF-8 karakterleri bolunmez), CRLF ile bitirir. */
    private static void line(StringBuilder out, String text) {
        int count = 0;
        int limit = 75;
        StringBuilder cur = new StringBuilder();
        for (int i = 0; i < text.length(); ) {
            int cp = text.codePointAt(i);
            String ch = new String(Character.toChars(cp));
            int bytes = ch.getBytes(StandardCharsets.UTF_8).length;
            if (count + bytes > limit) {
                out.append(cur).append("\r\n");
                cur.setLength(0);
                cur.append(' ');
                count = 1;
                limit = 75;
            }
            cur.append(ch);
            count += bytes;
            i += Character.charCount(cp);
        }
        out.append(cur).append("\r\n");
    }
}
