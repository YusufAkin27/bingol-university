package edu.bingol.backend.academic;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.academic.TimetableLogic.Entry;
import edu.bingol.backend.common.ApiException;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import org.junit.jupiter.api.Test;

/** Saf kurallar: cakisma, ISO gun, renk, saat ayristirma, kapsam eslemesi, ics uretimi. */
class AcademicLogicTest {

    private static Entry e(int day, String s, String en) {
        return new Entry(1L, "Ders", day, LocalTime.parse(s), LocalTime.parse(en));
    }

    @Test
    void overlapRules() {
        assertTrue(TimetableLogic.overlaps(e(1, "09:00", "10:50"), e(1, "10:00", "11:00")));
        assertFalse(TimetableLogic.overlaps(e(1, "09:00", "10:00"), e(1, "10:00", "11:00")), "bitisik dersler cakismaz");
        assertFalse(TimetableLogic.overlaps(e(1, "09:00", "10:00"), e(2, "09:00", "10:00")), "farkli gun");
        assertTrue(TimetableLogic.overlaps(e(3, "09:00", "12:00"), e(3, "10:00", "11:00")), "icinde");
    }

    @Test
    void firstConflictChecksExistingAndSelf() {
        assertNull(TimetableLogic.firstConflict(List.of(e(1, "09:00", "10:00")), List.of(e(1, "10:00", "11:00"))));
        assertNotNull(TimetableLogic.firstConflict(List.of(e(1, "09:00", "10:00")), List.of(e(1, "09:30", "11:00"))));
        assertNotNull(TimetableLogic.firstConflict(List.of(), List.of(e(2, "09:00", "10:00"), e(2, "09:30", "10:30"))));
    }

    @Test
    void isoDayAndColor() {
        assertTrue(TimetableLogic.validDay(1));
        assertTrue(TimetableLogic.validDay(7));
        assertFalse(TimetableLogic.validDay(0));
        assertFalse(TimetableLogic.validDay(8));
        assertFalse(TimetableLogic.validDay(null));
        assertEquals("blue", TimetableLogic.resolveColor(" Blue ", "x"));
        assertNull(TimetableLogic.resolveColor("neon", "x"));
        assertEquals(TimetableLogic.resolveColor(null, "Fizik"), TimetableLogic.resolveColor("", "fizik"));
        assertTrue(TimetableLogic.COLORS.contains(TimetableLogic.resolveColor(null, "Fizik")));
    }

    @Test
    void timeParsing() {
        assertEquals(LocalTime.of(9, 30), AcademicTime.parseTime("09:30"));
        assertEquals(LocalTime.of(9, 5), AcademicTime.parseTime("9:05"));
        assertThrows(ApiException.class, () -> AcademicTime.parseTime("25:00"));
        assertThrows(ApiException.class, () -> AcademicTime.parseTime("0930"));
        assertThrows(ApiException.class, () -> AcademicTime.parseTime(null));
        assertEquals(AcademicTime.parseInstant("2026-11-02T10:00:00+03:00"), AcademicTime.parseInstant("2026-11-02T10:00"));
        assertEquals("2026-11-02T10:00:00+03:00", AcademicTime.fmt(AcademicTime.parseInstant("2026-11-02T07:00:00Z")));
        assertThrows(ApiException.class, () -> AcademicTime.parseInstant("yarin"));
    }

    @Test
    void audienceMatching() {
        assertTrue(AudienceMatch.matches(null, null, null, "Bilgisayar Mühendisliği", "Mühendislik", "2"));
        assertTrue(AudienceMatch.matches("Bilgisayar Mühendisliği", null, "2", "Bilgisayar Mühendisliği", null, "2"));
        assertFalse(AudienceMatch.matches("Bilgisayar Mühendisliği", null, null, "Hukuk", null, "2"));
        assertFalse(AudienceMatch.matches(null, null, "3", "Hukuk", null, "2"));
        assertFalse(AudienceMatch.matches("Hukuk", null, null, null, null, null), "profil bos: kapsamli duyuru gelmez");
        assertTrue(AudienceMatch.matches(null, null, null, null, null, null), "kapsamsiz herkese");
    }

    @Test
    void icsHasTimezoneRruleAndFolds() {
        var s = new IcsBuilder.SessionEvent(21, "Veri Yapilari; Lab, A", "BIL201", "Dr. Ayse", "B-204", 1,
                LocalTime.of(9, 0), LocalTime.of(10, 50));
        var ex = new IcsBuilder.ExamEvent(5, "Vize", "Veri Yapilari", "B-204", Instant.parse("2026-11-10T07:00:00Z"), null);
        // 2026-11-04 Carsamba: Pazartesi dersinin ilk gunu 2026-11-09
        String ics = IcsBuilder.build(List.of(s), List.of(ex), LocalDate.of(2026, 11, 4), LocalDate.of(2027, 1, 15),
                LocalDate.of(2026, 10, 27), Instant.parse("2026-10-27T10:00:00Z"));
        assertTrue(ics.startsWith("BEGIN:VCALENDAR\r\n"));
        assertTrue(ics.contains("TZID:Europe/Istanbul") && ics.contains("BEGIN:VTIMEZONE") && ics.contains("TZOFFSETTO:+0300"));
        assertTrue(ics.contains("DTSTART;TZID=Europe/Istanbul:20261109T090000"), ics);
        assertTrue(ics.contains("DTEND;TZID=Europe/Istanbul:20261109T105000"));
        assertTrue(ics.contains("RRULE:FREQ=WEEKLY;BYDAY=MO;UNTIL=20270115T205959Z"), ics);
        assertTrue(ics.contains("SUMMARY:Veri Yapilari\\; Lab\\, A"));
        assertTrue(ics.contains("LOCATION:B-204"));
        assertTrue(ics.contains("DTSTART;TZID=Europe/Istanbul:20261110T100000"), "sinav 10:00 Istanbul");
        assertTrue(ics.endsWith("END:VCALENDAR\r\n"));
        for (String line : ics.split("\r\n")) {
            assertTrue(line.getBytes(StandardCharsets.UTF_8).length <= 75, "satir 75 oktet: " + line);
        }
    }

    @Test
    void icsWithoutSemesterUsesSixteenWeeks() {
        var s = new IcsBuilder.SessionEvent(1, "Fizik", null, null, null, 5, LocalTime.of(13, 0), LocalTime.of(14, 0));
        String ics = IcsBuilder.build(List.of(s), List.of(), null, null, LocalDate.of(2026, 10, 27), Instant.parse("2026-10-27T10:00:00Z"));
        // bugun Sali: ilk Cuma 2026-10-30; bitis bugun + 16 hafta = 2027-02-16 (gun sonu Istanbul = 20:59:59Z)
        assertTrue(ics.contains("DTSTART;TZID=Europe/Istanbul:20261030T130000"), ics);
        assertTrue(ics.contains("BYDAY=FR;UNTIL=20270216T205959Z"), ics);
    }

    @Test
    void icsFoldsLongTurkishLines() {
        String longName = "Çok Uzun Bir Ders Adı Şöyle Böyle ".repeat(6).strip();
        var s = new IcsBuilder.SessionEvent(1, longName, null, null, null, 1, LocalTime.of(9, 0), LocalTime.of(10, 0));
        String ics = IcsBuilder.build(List.of(s), List.of(), LocalDate.of(2026, 9, 14), LocalDate.of(2027, 1, 15),
                LocalDate.of(2026, 9, 1), Instant.parse("2026-09-01T00:00:00Z"));
        assertTrue(ics.contains("\r\n "), "katlama var");
        String unfolded = ics.replace("\r\n ", "");
        assertTrue(unfolded.contains("SUMMARY:" + longName));
    }
}
