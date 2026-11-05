package edu.bingol.backend.forum.share;

import java.sql.ResultSet;
import java.sql.SQLException;

/** {@link JdbcForumShareResolver} sorgu satirlarinin esleyicisi (konu ve yorum sorgulari ayni sutun adlarini uretir). */
final class ForumShareRows {

    private ForumShareRows() {}

    static JdbcForumShareResolver.Row map(ResultSet rs, int i) throws SQLException {
        long media = rs.getLong("media_id");
        Long mediaId = rs.wasNull() ? null : media;
        return new JdbcForumShareResolver.Row(rs.getLong("id"), rs.getLong("topic_id"), rs.getLong("user_id"),
                rs.getBoolean("anonymous"), rs.getBoolean("topic_anon"), rs.getLong("topic_user"), rs.getString("text"),
                rs.getString("title"), rs.getString("display_name"), rs.getLong("category_id"),
                rs.getTimestamp("created_at").toInstant(), mediaId, rs.getString("name_tr"), rs.getString("name_en"),
                rs.getString("name_ar"));
    }
}
