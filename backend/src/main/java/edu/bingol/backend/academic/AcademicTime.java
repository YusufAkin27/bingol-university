package edu.bingol.backend.academic;

import edu.bingol.backend.common.ApiException;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import org.springframework.http.HttpStatus;

/** Europe/Istanbul saat dilimi ve metin bicimi yardimcilari (istek ayristirma + yanit bicimi). */
public final class AcademicTime {

    public static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");
    private static final DateTimeFormatter HHMM = DateTimeFormatter.ofPattern("HH:mm");

    private AcademicTime() {}

    /** "HH:mm" (veya "H:mm"); gecersizse 422 COURSE_INVALID_TIME. */
    public static LocalTime parseTime(String s) {
        if (s == null) {
            throw invalidTime();
        }
        try {
            String t = s.strip();
            if (t.length() == 4 && t.charAt(1) == ':') {
                t = "0" + t;
            }
            if (t.length() != 5) {
                throw invalidTime();
            }
            return LocalTime.parse(t, HHMM);
        } catch (DateTimeParseException e) {
            throw invalidTime();
        }
    }

    private static ApiException invalidTime() {
        return new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "COURSE_INVALID_TIME",
                "Saat HH:mm biçiminde olmalı.");
    }

    public static String fmtTime(LocalTime t) {
        return t.format(HHMM);
    }

    public static LocalDate parseDate(String s) {
        try {
            return LocalDate.parse(s == null ? "" : s.strip());
        } catch (DateTimeParseException e) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "DATE_INVALID", "Tarih YYYY-AA-GG biçiminde olmalı.");
        }
    }

    /** Ofsetli ISO ya da ofsetsiz yerel (Istanbul) anlik; gecersizse 422 DATE_INVALID. */
    public static Instant parseInstant(String s) {
        if (s == null || s.isBlank()) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "DATE_INVALID", "Tarih geçersiz.");
        }
        String t = s.strip();
        if (t.length() == 10) {
            // yalnizca tarih: o gunun baslangici (Istanbul)
            return startOfDay(parseDate(t));
        }
        try {
            return OffsetDateTime.parse(t).toInstant();
        } catch (DateTimeParseException ignore) {
            // yerel biciim denenir
        }
        try {
            return LocalDateTime.parse(t).atZone(ZONE).toInstant();
        } catch (DateTimeParseException e) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "DATE_INVALID", "Tarih geçersiz.");
        }
    }

    public static String fmt(Instant i) {
        return i == null ? null : DateTimeFormatter.ISO_OFFSET_DATE_TIME.format(i.atZone(ZONE).toOffsetDateTime());
    }

    public static String fmt(Timestamp t) {
        return t == null ? null : fmt(t.toInstant());
    }

    public static Instant startOfDay(LocalDate d) {
        return d.atStartOfDay(ZONE).toInstant();
    }
}
