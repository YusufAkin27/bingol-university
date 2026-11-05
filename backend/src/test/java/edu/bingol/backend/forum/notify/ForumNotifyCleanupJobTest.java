package edu.bingol.backend.forum.notify;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;

import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.dbmaint.ChunkedDeleter;
import edu.bingol.backend.forum.ForumTestDb;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;

/** Bildirim defteri saklamasi: eski satirlar parcali silinir, yenisi kalir, saklama kapaliysa dokunulmaz. */
class ForumNotifyCleanupJobTest {

    private static ChunkedDeleter deleter(JdbcTemplate j) {
        return new ChunkedDeleter(new NamedParameterJdbcTemplate(j), new SimpleMeterRegistry(), 100, 0, 5);
    }

    @Test
    void deletesOnlyRowsOlderThanRetention() {
        JdbcTemplate j = ForumTestDb.create();
        j.update("INSERT INTO forum_notify_seen (kind, target_id, actor_id, recipient_user_id, created_at) VALUES "
                + "('TL', 1, 2, 3, TIMESTAMP '2026-01-01 00:00:00'), ('CL', 1, 2, 3, TIMESTAMP '2026-01-02 00:00:00'),"
                + "('TL', 9, 2, 3, TIMESTAMP '2026-11-01 00:00:00')");
        ForumNotifyCleanupJob job = new ForumNotifyCleanupJob(deleter(j), mock(SchedulerLock.class), 90);
        assertEquals(2, job.run(Instant.parse("2026-11-05T00:00:00Z")));
        assertEquals(1, j.queryForObject("SELECT COUNT(*) FROM forum_notify_seen", Integer.class));
        assertEquals(9L, j.queryForObject("SELECT target_id FROM forum_notify_seen", Long.class));
    }

    @Test
    void retentionZeroDisablesTheJobAndErrorsAreSwallowed() {
        JdbcTemplate j = ForumTestDb.create();
        j.update("INSERT INTO forum_notify_seen (kind, target_id, actor_id, recipient_user_id, created_at) VALUES "
                + "('TL', 1, 2, 3, TIMESTAMP '2026-01-01 00:00:00')");
        assertEquals(0, new ForumNotifyCleanupJob(deleter(j), mock(SchedulerLock.class), 0)
                .run(Instant.parse("2026-11-05T00:00:00Z")));
        assertEquals(1, j.queryForObject("SELECT COUNT(*) FROM forum_notify_seen", Integer.class));
        j.execute("DROP TABLE forum_notify_seen");
        assertEquals(0, new ForumNotifyCleanupJob(deleter(j), mock(SchedulerLock.class), 90)
                .run(Instant.parse("2026-11-05T00:00:00Z")));
    }
}
