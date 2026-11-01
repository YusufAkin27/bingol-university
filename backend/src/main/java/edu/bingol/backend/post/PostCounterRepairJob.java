package edu.bingol.backend.post;

import edu.bingol.backend.config.SchedulerLock;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.Duration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Gece 03:30: beğeni sayacını (post.like_count) ve takip sayaçlarını (user_follow_stats) gerçek sayımla onarır.
 *
 * <p>A06#2: önceden tüm {@code post} tablosu TEK UPDATE idi; havuz bağlantılarındaki 8 sn {@code statement_timeout}
 * (hikari) gerçek hacimde onu iptal eder ve sayaç hiç onarılmazdı. Artık kimlik aralığına göre {@code chunk} (5000)
 * satırlık parçalar, her biri kendi kısa işleminde ve (yalnız PostgreSQL) {@code SET LOCAL statement_timeout=60000}
 * ile çalışır. Aynı korelasyonlu UPDATE "beğenisi olmayan ama sayacı &gt; 0" satırları da düzeltir. Parça hatası
 * yutulmaz: kalan parçalar sürer, sonunda istisna fırlar (JobMonitor hata sayar, bir sonraki gece kaldığı yerden).
 * Yarışta o anda gelen +1 bir geceliğine kaybolabilir; ertesi gece düzelir.
 */
@Component
public class PostCounterRepairJob {

    private static final Logger log = LoggerFactory.getLogger(PostCounterRepairJob.class);
    private static final long CHUNK_TIMEOUT_MS = 60_000;

    private static final String LIKES_SQL = "UPDATE post SET like_count = (SELECT COUNT(*) FROM post_like l WHERE l.post_id = post.id) "
            + "WHERE id > ? AND id <= ? AND like_count <> (SELECT COUNT(*) FROM post_like l WHERE l.post_id = post.id)";

    private static final String FOLLOW_SQL = "UPDATE user_follow_stats SET "
            + "follower_count = (SELECT COUNT(*) FROM user_follow f WHERE f.followee_id = user_follow_stats.user_id), "
            + "following_count = (SELECT COUNT(*) FROM user_follow f WHERE f.follower_id = user_follow_stats.user_id) "
            + "WHERE user_id > ? AND user_id <= ? AND (follower_count <> (SELECT COUNT(*) FROM user_follow f "
            + "WHERE f.followee_id = user_follow_stats.user_id) OR following_count <> (SELECT COUNT(*) FROM user_follow f "
            + "WHERE f.follower_id = user_follow_stats.user_id))";

    private final JdbcTemplate jdbc;
    private final SchedulerLock lock;
    private final int chunk;

    @Autowired
    public PostCounterRepairJob(JdbcTemplate jdbc, SchedulerLock lock,
                                @Value("${app.post.counter-repair-chunk:5000}") int chunk) {
        this.jdbc = jdbc;
        this.lock = lock;
        this.chunk = Math.max(1, chunk);
    }

    @Scheduled(cron = "${app.post.counter-repair-cron:0 30 3 * * *}", zone = "Europe/Istanbul")
    public void scheduled() {
        // Hata yutulmaz: @Scheduled gözlemi (JobMonitor) hatayı sayar ve sağlık göstergesine yansır
        lock.tryRun("post-counter-repair", Duration.ofMinutes(60), this::repair);
    }

    /** Kilitsiz çekirdek (test / elle tetikleme). Parça başarısızsa tamamı bitince IllegalStateException. */
    public void repair() {
        int failed = 0;
        long likes = 0;
        long follows = 0;
        long maxPost = maxId("SELECT COALESCE(MAX(id), 0) FROM post");
        for (long from = 0; from < maxPost; from += chunk) {
            try {
                likes += runChunk(LIKES_SQL, from, from + chunk);
            } catch (RuntimeException e) {
                failed++;
                log.warn("Gonderi sayac onarimi parcasi basarisiz (id>{}): {}", from, e.toString());
            }
        }
        long maxUser = maxId("SELECT COALESCE(MAX(user_id), 0) FROM user_follow_stats");
        for (long from = 0; from < maxUser; from += chunk) {
            try {
                follows += runChunk(FOLLOW_SQL, from, from + chunk);
            } catch (RuntimeException e) {
                failed++;
                log.warn("Takip sayaci onarimi parcasi basarisiz (user>{}): {}", from, e.toString());
            }
        }
        if (likes > 0 || follows > 0) {
            log.info("Gonderi sayaclari onarildi: begeni={}, takip={}", likes, follows);
        }
        if (failed > 0) {
            throw new IllegalStateException("Sayac onarimi: " + failed + " parca basarisiz");
        }
    }

    private long maxId(String sql) {
        Long v = jdbc.queryForObject(sql, Long.class);
        return v == null ? 0 : v;
    }

    /** Parçayı kendi kısa işleminde çalıştırır; PostgreSQL'de bakım için gevşetilmiş statement_timeout ile. */
    private int runChunk(String sql, long from, long to) {
        Integer n = jdbc.execute((ConnectionCallback<Integer>) con -> chunkOnConnection(con, sql, from, to));
        return n == null ? 0 : n;
    }

    private static int chunkOnConnection(Connection con, String sql, long from, long to) throws SQLException {
        boolean postgres = "PostgreSQL".equalsIgnoreCase(con.getMetaData().getDatabaseProductName());
        boolean auto = con.getAutoCommit();
        con.setAutoCommit(false);
        try {
            if (postgres) {
                try (Statement st = con.createStatement()) {
                    st.execute("SET LOCAL statement_timeout = " + CHUNK_TIMEOUT_MS); // sabit sayı
                }
            }
            int n;
            try (PreparedStatement ps = con.prepareStatement(sql)) {
                ps.setLong(1, from);
                ps.setLong(2, to);
                n = ps.executeUpdate();
            }
            con.commit();
            return n;
        } catch (SQLException | RuntimeException e) {
            try {
                con.rollback();
            } catch (SQLException ignored) {
                // asıl hata yayılır
            }
            throw e;
        } finally {
            con.setAutoCommit(auto);
        }
    }
}
