package edu.bingol.backend.dbmaint;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;

/**
 * FIX-P09 (A09#4): hangi gunlerin yeniden toplulastirildigi (eksik gunler + istege bagli son N gun). Gunluk GROUP BY
 * sorgusunun kendisi PostgreSQL'e ozeldir (ON CONFLICT, AT TIME ZONE): duman betigiyle dogrulanir; burada gun secimi.
 */
class AnalyticsRollupTest {

    private static final Instant NOW = Instant.parse("2026-11-01T09:00:00Z"); // Istanbul 12:00, bugun 2026-11-01

    private JdbcTemplate plain;
    private final List<LocalDate> rolled = new ArrayList<>();
    private AnalyticsRollup rollup;

    @BeforeEach
    void setUp() {
        DriverManagerDataSource ds = new DriverManagerDataSource(
                "jdbc:h2:mem:rollup" + System.nanoTime() + ";MODE=PostgreSQL;NON_KEYWORDS=DAY;DB_CLOSE_DELAY=-1", "sa", "");
        plain = new JdbcTemplate(ds);
        plain.execute("CREATE TABLE analytics_event_daily (day DATE NOT NULL, name VARCHAR(40) NOT NULL, "
                + "screen VARCHAR(40) NOT NULL DEFAULT '', events BIGINT NOT NULL, users BIGINT NOT NULL)");
        rollup = new AnalyticsRollup(new NamedParameterJdbcTemplate(plain), Clock.fixed(NOW, ZoneOffset.UTC)) {
            @Override
            void rollUp(LocalDate day) {
                rolled.add(day);
            }
        };
    }

    private void daily(String day) {
        plain.update("INSERT INTO analytics_event_daily (day, name, events, users) VALUES (DATE '" + day + "', 'app_open', 1, 1)");
    }

    @Test
    void onlyMissingDaysAreRolledByDefault() {
        daily("2026-10-28");
        assertEquals(3, rollup.rollUpMissingDays());
        assertEquals(List.of(LocalDate.parse("2026-10-29"), LocalDate.parse("2026-10-30"), LocalDate.parse("2026-10-31")), rolled);
    }

    @Test
    void lastNDaysAreRecomputedWhenEnabledSoLateEventsAreCounted() {
        daily("2026-10-30");
        rollup.setRecomputeDays(8);
        assertEquals(8, rollup.rollUpMissingDays());
        assertEquals(LocalDate.parse("2026-10-24"), rolled.get(0));
        assertEquals(LocalDate.parse("2026-10-31"), rolled.get(7));
    }

    @Test
    void recomputeDoesNotShortenTheCatchupOfALongGap() {
        daily("2026-10-01");
        rollup.setRecomputeDays(8);
        assertEquals(30, rollup.rollUpMissingDays());
        assertEquals(LocalDate.parse("2026-10-02"), rolled.get(0));
    }

    @Test
    void failureOnADayStopsTheRunAndPropagates() {
        daily("2026-10-28");
        AnalyticsRollup failing = new AnalyticsRollup(new NamedParameterJdbcTemplate(plain), Clock.fixed(NOW, ZoneOffset.UTC)) {
            @Override
            void rollUp(LocalDate day) {
                if (day.equals(LocalDate.parse("2026-10-30"))) {
                    throw new IllegalStateException("statement timeout");
                }
                rolled.add(day);
            }
        };
        org.junit.jupiter.api.Assertions.assertThrows(IllegalStateException.class, failing::rollUpMissingDays);
        assertEquals(List.of(LocalDate.parse("2026-10-29")), rolled);
    }
}
