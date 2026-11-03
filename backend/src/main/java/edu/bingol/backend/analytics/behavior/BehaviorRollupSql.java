package edu.bingol.backend.analytics.behavior;

import edu.bingol.backend.analytics.DateRange;
import java.time.LocalDate;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;

/**
 * Bir Istanbul gununun oturum/ekran ozetini analytics_session_daily ve analytics_screen_daily tablolarina yazar
 * (idempotent upsert). Ayni oturum SQL'i ({@link BehaviorSql#SESSIONS}) kullanilir; oturum BASLADIGI gune sayilir.
 * Tablolarda kullanici kimligi yoktur (yalniz toplu). PostgreSQL'e ozeldir, H2'de calismaz (duman: smoke-behavior.sh).
 */
public final class BehaviorRollupSql {

    private BehaviorRollupSql() {}

    public static void rollUpDay(NamedParameterJdbcTemplate jdbc, LocalDate day) {
        MapSqlParameterSource p = BehaviorSql.params(DateRange.dayStart(day), DateRange.dayStart(day.plusDays(1)))
                .addValue("day", day);
        jdbc.update(BehaviorSql.SESSIONS + BehaviorSql.ROLLUP_SESSIONS, p);
        jdbc.update(BehaviorSql.SESSIONS + BehaviorSql.ROLLUP_SCREENS, p);
    }
}
