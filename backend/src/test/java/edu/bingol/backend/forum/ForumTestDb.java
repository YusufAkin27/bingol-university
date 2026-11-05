package edu.bingol.backend.forum;

import java.util.UUID;
import javax.sql.DataSource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;

/**
 * E alani birim testleri icin hafif H2 (PostgreSQL kipi) semasi: yalniz E'nin sorgularinin kullandigi sutunlar,
 * sozlesmedeki (FORUM_API.md) tablo/sutun adlariyla. Spring baglami ya da A/B/C/D entity'leri gerekmez; sorgu
 * mantigi (anonimlik, silinmis, imlec, sayim) bu sekilde hizli ve bagimsiz dogrulanir.
 */
public final class ForumTestDb {

    private ForumTestDb() {}

    public static JdbcTemplate create() {
        DataSource ds = new DriverManagerDataSource("jdbc:h2:mem:" + UUID.randomUUID() + ";MODE=PostgreSQL;DB_CLOSE_DELAY=-1",
                "sa", "");
        JdbcTemplate jdbc = new JdbcTemplate(ds);
        for (String ddl : new String[] {
                "CREATE TABLE app_user (id BIGINT PRIMARY KEY, display_name VARCHAR(80), status VARCHAR(16) DEFAULT 'ACTIVE')",
                "CREATE TABLE forum_category (id BIGINT PRIMARY KEY, name_tr VARCHAR(80), name_en VARCHAR(80), name_ar VARCHAR(80))",
                "CREATE TABLE forum_topic (id BIGINT PRIMARY KEY, user_id BIGINT NOT NULL, category_id BIGINT, title VARCHAR(150),"
                        + " body TEXT, anonymous BOOLEAN DEFAULT FALSE, status VARCHAR(10) DEFAULT 'ACTIVE',"
                        + " created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, deleted_at TIMESTAMP, edited_at TIMESTAMP)",
                "CREATE TABLE forum_comment (id BIGINT PRIMARY KEY, topic_id BIGINT NOT NULL, user_id BIGINT NOT NULL,"
                        + " parent_comment_id BIGINT, body TEXT, anonymous BOOLEAN DEFAULT FALSE, status VARCHAR(10) DEFAULT 'ACTIVE',"
                        + " created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, deleted_at TIMESTAMP, edited_at TIMESTAMP)",
                "CREATE TABLE forum_media (id BIGINT PRIMARY KEY, owner_id BIGINT, thumb_key VARCHAR(300), hidden_at TIMESTAMP)",
                "CREATE TABLE forum_topic_image (id BIGINT PRIMARY KEY, topic_id BIGINT, media_id BIGINT, position INT DEFAULT 0)",
                "CREATE TABLE forum_topic_like (topic_id BIGINT, user_id BIGINT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)",
                "CREATE TABLE forum_comment_like (comment_id BIGINT, user_id BIGINT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)",
                "CREATE TABLE forum_bookmark (user_id BIGINT, target_type VARCHAR(10), target_id BIGINT,"
                        + " created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)",
                "CREATE TABLE forum_topic_follow (topic_id BIGINT, user_id BIGINT, notify BOOLEAN DEFAULT TRUE,"
                        + " follow BOOLEAN DEFAULT TRUE, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)",
                "CREATE TABLE forum_poll_vote (poll_id BIGINT, user_id BIGINT, option_id BIGINT,"
                        + " created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)",
                "CREATE TABLE forum_user_mute (user_id BIGINT, muted_user_id BIGINT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)",
                "CREATE TABLE forum_anon_alias (topic_id BIGINT, user_id BIGINT, n INT)",
                "CREATE TABLE forum_notification_pref (user_id BIGINT PRIMARY KEY, all_enabled BOOLEAN DEFAULT TRUE,"
                        + " topic_comments BOOLEAN DEFAULT TRUE, comment_replies BOOLEAN DEFAULT TRUE, likes BOOLEAN DEFAULT TRUE,"
                        + " followed_topics BOOLEAN DEFAULT TRUE, moderation BOOLEAN DEFAULT TRUE,"
                        + " updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)",
                "CREATE TABLE forum_notify_seen (kind VARCHAR(24) NOT NULL, target_id BIGINT NOT NULL, actor_id BIGINT NOT NULL,"
                        + " recipient_user_id BIGINT NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,"
                        + " PRIMARY KEY (kind, target_id, actor_id, recipient_user_id))"}) {
            jdbc.execute(ddl);
        }
        return jdbc;
    }

    public static void user(JdbcTemplate j, long id, String name, String status) {
        j.update("INSERT INTO app_user (id, display_name, status) VALUES (?, ?, ?)", id, name, status);
    }

    public static void topic(JdbcTemplate j, long id, long user, boolean anon, String title, String body, String status,
                             boolean deleted, String createdAt) {
        j.update("INSERT INTO forum_topic (id, user_id, category_id, title, body, anonymous, status, created_at, deleted_at)"
                        + " VALUES (?, ?, 1, ?, ?, ?, ?, TIMESTAMP '" + createdAt + "', "
                        + (deleted ? "TIMESTAMP '2026-01-01 00:00:00'" : "NULL") + ")",
                id, user, title, body, anon, status);
    }

    public static void comment(JdbcTemplate j, long id, long topic, long user, boolean anon, String body, String status,
                               boolean deleted, String createdAt) {
        j.update("INSERT INTO forum_comment (id, topic_id, user_id, body, anonymous, status, created_at, deleted_at)"
                        + " VALUES (?, ?, ?, ?, ?, ?, TIMESTAMP '" + createdAt + "', "
                        + (deleted ? "TIMESTAMP '2026-01-01 00:00:00'" : "NULL") + ")",
                id, topic, user, body, anon, status);
    }
}
