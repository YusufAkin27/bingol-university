package edu.bingol.backend.analytics;

import edu.bingol.backend.common.ApiException;
import java.time.Clock;
import java.time.DateTimeException;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import org.springframework.http.HttpStatus;

/**
 * Raporlama icin Istanbul takvim gunleri cinsinden kapali aralik [from, to]. Veritabani sorgularinda gun sinirlari
 * UTC an'larina cevrilir: [startUtc, endUtc) yari acik aralik, boylece created_at indeksi kullanilir ve
 * gece yarisi (Istanbul 00:00 = onceki gun 21:00 UTC) kayitlari dogru gune duser.
 */
public record DateRange(LocalDate from, LocalDate to) {

    public static final ZoneId ISTANBUL = ZoneId.of("Europe/Istanbul");
    public static final int MAX_DAYS = 366;
    private static final int DEFAULT_DAYS = 30;

    /** Istanbul'a gore bugun. */
    public static LocalDate today(Clock clock) {
        return LocalDate.now(clock.withZone(ISTANBUL));
    }

    /**
     * yyyy-MM-dd metinlerinden aralik uretir. Ikisi de bos ise son 30 gun; yalniz `to` verilirse onceki 30 gun;
     * yalniz `from` verilirse bugune kadar. Gecersiz bicim, from &gt; to veya 366 gunden uzun aralik: 400 INVALID_RANGE.
     */
    public static DateRange parse(String from, String to, Clock clock) {
        LocalDate t = to == null || to.isBlank() ? null : date(to);
        LocalDate f = from == null || from.isBlank() ? null : date(from);
        if (t == null) {
            t = today(clock);
        }
        if (f == null) {
            f = t.minusDays(DEFAULT_DAYS - 1L);
        }
        if (f.isAfter(t) || ChronoUnit.DAYS.between(f, t) + 1 > MAX_DAYS) {
            throw invalid();
        }
        return new DateRange(f, t);
    }

    /** Aralikta kac takvim gunu var. */
    public int days() {
        return (int) ChronoUnit.DAYS.between(from, to) + 1;
    }

    /** Aralik baslangici (dahil): from gunu Istanbul 00:00, UTC olarak. */
    public OffsetDateTime startUtc() {
        return dayStart(from);
    }

    /** Aralik sonu (haric): to'dan sonraki gunun Istanbul 00:00'i, UTC olarak. */
    public OffsetDateTime endUtc() {
        return dayStart(to.plusDays(1));
    }

    /** Verilen Istanbul gununun baslangici (UTC). */
    public static OffsetDateTime dayStart(LocalDate day) {
        return day.atStartOfDay(ISTANBUL).toInstant().atOffset(ZoneOffset.UTC);
    }

    private static LocalDate date(String s) {
        try {
            return LocalDate.parse(s.trim());
        } catch (DateTimeException e) {
            throw invalid();
        }
    }

    private static ApiException invalid() {
        return new ApiException(HttpStatus.BAD_REQUEST, "INVALID_RANGE",
                "Geçersiz tarih aralığı (yyyy-MM-dd, en çok 366 gün).", String.valueOf(MAX_DAYS));
    }
}
