package edu.bingol.backend.forum;

import edu.bingol.backend.config.SchedulerLock;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.Duration;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Gece onarimi: forum ve forum anketi sayaclarini gercek satirlarla esler (PostCounterRepairJob kalibi).
 *
 * <p>Varsayilan KAPALI ({@code app.forum.counter-repair-enabled=false}): zamanlayici acilmadikca hicbir sey yapmaz.
 * Kimlik araligina gore {@code chunk} (5000) satirlik parcalar, her biri kendi kisa islemi; yalnizca GERCEKTEN
 * sapmis satir guncellenir. Onarilanlar: forum_topic.comment_count/like_count/bookmark_count,
 * forum_comment.like_count/reply_count, forum_poll_option.vote_count.
 *
 * <p>Dokunulmayanlar: {@code like_boost} sutunlari (gorunen sayi like_count + like_boost; yalniz gercek like_count
 * onarilir) ve poll.voter_count (hesap silmede bilerek sapar).
 *
 * <p>reply_count anlami "listelenen dogrudan cocuk" (canli, ya da altinda listelenen yaniti olan yer tutucu) ve
 * ozyinelemelidir; SQL'de yalniz sinirlari denetlenir: canli cocuk sayisi alt sinir, canli + tum yer tutucu cocuklar
 * ust sinirdir. Sayac bu bandin DISINDAysa onarilir (hedef: canli + altinda canli dogrudan cocugu olan yer tutucular);
 * bandin icindeki belirsiz degerlere dokunulmaz. Yarista o an gelen +1 bir geceligine kaybolabilir; ertesi gece duzelir.
 */
@Component
public class ForumCounterRepairJob {

    private static final Logger log = LoggerFactory.getLogger(ForumCounterRepairJob.class);
    private static final long CHUNK_TIMEOUT_MS = 60_000;

    private static final String LIVE = "c.deleted_at IS NULL AND c.status = 'ACTIVE'";

    /** Onarim kalemi: tablo (kimlik araligi icin), ad (log) ve (id > ? AND id <= ?) alan UPDATE. */
    private record Spec(String table, String name, String sql) {}

    private static Spec simple(String table, String col, String countSql) {
        String sub = "(" + countSql + ")";
        return new Spec(table, table + "." + col,
                "UPDATE " + table + " SET " + col + " = " + sub
                        + " WHERE id > ? AND id <= ? AND " + col + " <> " + sub);
    }

    private static final String REPLY_LIVE = "SELECT COUNT(*) FROM forum_comment c "
            + "WHERE c.parent_comment_id = forum_comment.id AND " + LIVE;
    private static final String REPLY_DEAD = "SELECT COUNT(*) FROM forum_comment c "
            + "WHERE c.parent_comment_id = forum_comment.id AND NOT (" + LIVE + ")";
    private static final String REPLY_EST = "(" + REPLY_LIVE + ") + (SELECT COUNT(*) FROM forum_comment c WHERE "
            + "c.parent_comment_id = forum_comment.id AND NOT (" + LIVE + ") AND EXISTS (SELECT 1 FROM forum_comment g "
            + "WHERE g.parent_comment_id = c.id AND g.deleted_at IS NULL AND g.status = 'ACTIVE'))";

    private static final List<Spec> SPECS = List.of(
            simple("forum_topic", "comment_count",
                    "SELECT COUNT(*) FROM forum_comment c WHERE c.topic_id = forum_topic.id AND " + LIVE),
            simple("forum_topic", "like_count",
                    "SELECT COUNT(*) FROM forum_topic_like l WHERE l.topic_id = forum_topic.id"),
            simple("forum_topic", "bookmark_count",
                    "SELECT COUNT(*) FROM forum_bookmark b WHERE b.target_type = 'TOPIC' AND b.target_id = forum_topic.id"),
            simple("forum_comment", "like_count",
                    "SELECT COUNT(*) FROM forum_comment_like l WHERE l.comment_id = forum_comment.id"),
            new Spec("forum_comment", "forum_comment.reply_count",
                    "UPDATE forum_comment SET reply_count = " + REPLY_EST + " WHERE id > ? AND id <= ? AND "
                            + "(reply_count < (" + REPLY_LIVE + ") OR reply_count > (" + REPLY_LIVE + ") + (" + REPLY_DEAD + "))"),
            simple("forum_poll_option", "vote_count",
                    "SELECT COUNT(*) FROM forum_poll_vote v WHERE v.option_id = forum_poll_option.id"));

    private final JdbcTemplate jdbc;
    private final SchedulerLock lock;
    private final int chunk;
    private final boolean enabled;

    @Autowired
    public ForumCounterRepairJob(JdbcTemplate jdbc, SchedulerLock lock,
                                 @Value("${app.forum.counter-repair-chunk:5000}") int chunk,
                                 @Value("${app.forum.counter-repair-enabled:false}") boolean enabled) {
        this.jdbc = jdbc;
        this.lock = lock;
        this.chunk = Math.max(1, chunk);
        this.enabled = enabled;
    }

    @Scheduled(cron = "${app.forum.counter-repair-cron:0 50 3 * * *}", zone = "Europe/Istanbul")
    public void scheduled() {
        if (!enabled) {
            return;
        }
        // Hata yutulmaz: JobMonitor hatayi sayar, sonraki gece kaldigi yerden
        lock.tryRunOrLocal("forum-counter-repair", Duration.ofMinutes(60), this::repair);
    }

    /** Kilitsiz, bayraktan bagimsiz cekirdek (test / elle tetikleme). Parca basarisizsa sonunda IllegalStateException. */
    public void repair() {
        int failed = 0;
        for (Spec s : SPECS) {
            Long max = jdbc.queryForObject("SELECT COALESCE(MAX(id), 0) FROM " + s.table(), Long.class);
            long maxId = max == null ? 0 : max;
            long fixed = 0;
            for (long from = 0; from < maxId; from += chunk) {
                try {
                    fixed += runChunk(s.sql(), from, from + chunk);
                } catch (RuntimeException e) {
                    failed++;
                    log.warn("Forum sayac onarimi parcasi basarisiz ({}, id>{}): {}", s.name(), from, e.toString());
                }
            }
            if (fixed > 0) {
                log.info("Forum sayaci onarildi: {} satir={}", s.name(), fixed);
            }
        }
        if (failed > 0) {
            throw new IllegalStateException("Forum sayac onarimi: " + failed + " parca basarisiz");
        }
    }

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
                    st.execute("SET LOCAL statement_timeout = " + CHUNK_TIMEOUT_MS); // sabit sayi
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
                // asil hata yayilir
            }
            throw e;
        } finally {
            con.setAutoCommit(auto);
        }
    }
}
