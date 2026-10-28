package edu.bingol.backend.moderation.admin;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;

/** Yonetici suzgec tarihleri: gun sinirlari Europe/Istanbul (projenin her yerinde ayni). */
final class AdminDates {

    static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");

    private AdminDates() {}

    /** Gunun baslangici (dahil); null -> null. */
    static Instant from(LocalDate d) {
        return d == null ? null : d.atStartOfDay(ZONE).toInstant();
    }

    /** Gunun sonu (haric: ertesi gun 00:00); null -> null. */
    static Instant toExclusive(LocalDate d) {
        return d == null ? null : d.plusDays(1).atStartOfDay(ZONE).toInstant();
    }
}
