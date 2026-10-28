package edu.bingol.backend.post.social;

import edu.bingol.backend.export.DataExporter;
import java.util.List;
import java.util.Map;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * KVKK disa aktarim: takip iliskileri (yalniz kimlikler).
 */
@Configuration
public class SocialExporters {

    static final int MAX_ROWS = 5000;

    @Bean
    DataExporter followsExporter(JdbcTemplate jdbc) {
        return DataExporter.of("follows", uid -> {
            List<Map<String, Object>> following = jdbc.queryForList("SELECT followee_id AS \"userId\", "
                    + "CAST(created_at AS varchar) AS \"since\" FROM user_follow WHERE follower_id = ? "
                    + "ORDER BY created_at DESC LIMIT " + MAX_ROWS, uid);
            List<Map<String, Object>> followers = jdbc.queryForList("SELECT follower_id AS \"userId\", "
                    + "CAST(created_at AS varchar) AS \"since\" FROM user_follow WHERE followee_id = ? "
                    + "ORDER BY created_at DESC LIMIT " + MAX_ROWS, uid);
            return Map.of("following", following, "followers", followers);
        });
    }
}
