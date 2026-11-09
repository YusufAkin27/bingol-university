package edu.bingol.backend.menu;

import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/** {@link DailyMenuLog} JDBC uygulamasi (tasinabilir SQL: PostgreSQL + H2). */
@Component
public class JdbcDailyMenuLog implements DailyMenuLog {

    private final JdbcTemplate jdbc;

    public JdbcDailyMenuLog(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public boolean exists(LocalDate day) {
        Integer n = jdbc.queryForObject("SELECT count(*) FROM daily_menu_push_log WHERE push_date = ?", Integer.class,
                java.sql.Date.valueOf(day));
        return n != null && n > 0;
    }

    @Override
    public boolean claim(LocalDate day, String outcome) {
        try {
            return jdbc.update("INSERT INTO daily_menu_push_log (push_date, outcome, enqueued_count, created_at) VALUES (?, ?, 0, ?)",
                    java.sql.Date.valueOf(day), outcome, Timestamp.from(Instant.now())) == 1;
        } catch (DuplicateKeyException e) {
            return false;
        }
    }

    @Override
    public void finish(LocalDate day, String outcome, int enqueued) {
        jdbc.update("UPDATE daily_menu_push_log SET outcome = ?, enqueued_count = ? WHERE push_date = ?", outcome, enqueued,
                java.sql.Date.valueOf(day));
    }
}
