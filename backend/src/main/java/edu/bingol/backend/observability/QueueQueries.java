package edu.bingol.backend.observability;

import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Kuyruk gostergeleri icin salt-okunur sayim sorgulari (mail/push paketlerine dokunmamak icin burada). Sabit tablo
 * adlari kullanilir (disaridan girdi yok). Standart SQL: PostgreSQL ve H2'de calisir.
 */
@Component
public class QueueQueries {

    /** Duruma gore sayilar ve "gecikmis" (zamani gelmis ama gonderilmemis) en eski kaydin yasi (sn). */
    public record QueueStats(Map<String, Long> byStatus, Long oldestOverdueSeconds) {
        public long count(String status) {
            return byStatus.getOrDefault(status, 0L);
        }

        /** Gonderilmeyi bekleyen: PENDING + FAILED (+ SENDING varsa). */
        public long pending() {
            return count("PENDING") + count("FAILED") + count("SENDING");
        }
    }

    private final JdbcTemplate jdbc;

    public QueueQueries(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Mail kuyrugu: yalniz islemsel kayitlar (priority = 0) gecikme yasina girer; duyurular bilerek hiz sinirlidir.
     * Gerisi geri cekilme beklemesindeki (next_attempt_at gelecekte) kayitlar da "gecikmis" sayilmaz.
     */
    public QueueStats mail(Instant now) {
        return stats("mail_outbox", "priority = 0", now);
    }

    public QueueStats push(Instant now) {
        return stats("push_outbox", "1 = 1", now);
    }

    private QueueStats stats(String table, String overdueExtra, Instant now) {
        Map<String, Long> counts = new LinkedHashMap<>();
        List<Object[]> rows = jdbc.query("SELECT status, COUNT(*) FROM " + table + " GROUP BY status",
                (rs, i) -> new Object[] {rs.getString(1), rs.getLong(2)});
        for (Object[] r : rows) {
            counts.put((String) r[0], (Long) r[1]);
        }
        List<Timestamp> oldest = jdbc.query("SELECT MIN(next_attempt_at) FROM " + table
                        + " WHERE status IN ('PENDING', 'FAILED') AND next_attempt_at < ? AND " + overdueExtra,
                (rs, i) -> rs.getTimestamp(1), Timestamp.from(now));
        Timestamp t = oldest.isEmpty() ? null : oldest.get(0);
        Long age = t == null ? null : Math.max(0, Duration.between(t.toInstant(), now).toSeconds());
        return new QueueStats(counts, age);
    }

    /** Push kampanyalari: duruma gore sayi ve zamani 2 dk once gelmis ama hala SCHEDULED olanin gecikmesi (sn). */
    public QueueStats campaigns(Instant now) {
        Map<String, Long> counts = new LinkedHashMap<>();
        List<Object[]> rows = jdbc.query("SELECT status, COUNT(*) FROM push_campaign GROUP BY status",
                (rs, i) -> new Object[] {rs.getString(1), rs.getLong(2)});
        for (Object[] r : rows) {
            counts.put((String) r[0], (Long) r[1]);
        }
        Instant cutoff = now.minusSeconds(120);
        List<Timestamp> oldest = jdbc.query(
                "SELECT MIN(scheduled_at) FROM push_campaign WHERE status = 'SCHEDULED' AND scheduled_at < ?",
                (rs, i) -> rs.getTimestamp(1), Timestamp.from(cutoff));
        Timestamp t = oldest.isEmpty() ? null : oldest.get(0);
        Long age = t == null ? null : Math.max(0, Duration.between(t.toInstant(), now).toSeconds());
        return new QueueStats(counts, age);
    }
}
