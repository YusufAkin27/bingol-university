package edu.bingol.backend.forum.notify;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * {@link ForumNotifyLedger}: {@code INSERT .. ON CONFLICT DO NOTHING} (PostgreSQL; H2 PostgreSQL kipinde de calisir).
 * Hata firlatmaz, bu yuzden bir islem icinde cagrilsa bile islemi bozmaz; etkilenen satir 1 ise ilk kez gorulmustur.
 */
@Component
public class JdbcForumNotifyLedger implements ForumNotifyLedger {

    private final JdbcTemplate jdbc;

    public JdbcForumNotifyLedger(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public boolean firstTime(String kind, long targetId, long actorId, long recipientId) {
        return jdbc.update("INSERT INTO forum_notify_seen (kind, target_id, actor_id, recipient_user_id) VALUES (?, ?, ?, ?) "
                + "ON CONFLICT DO NOTHING", kind, targetId, actorId, recipientId) == 1;
    }
}
