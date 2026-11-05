package edu.bingol.backend.forum.poll;

import edu.bingol.backend.export.DataExporter;
import java.util.List;
import java.util.Map;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * KVKK disa aktarim: kullanicinin KENDI forum anketi oylari (hangi konuda hangi secenek). Baska kisilerin verisi
 * icermez; oy veren kimligi baska hicbir uc tarafindan gosterilmez.
 */
@Configuration
public class ForumPollExporters {

    static final int MAX_ROWS = 5000;

    @Bean
    DataExporter forumPollVotesExporter(JdbcTemplate jdbc) {
        return DataExporter.of("forumPollVotes", uid -> {
            List<Map<String, Object>> rows = jdbc.queryForList("SELECT p.topic_id AS \"topicId\", p.question AS question, "
                    + "o.text AS \"optionText\", CAST(v.created_at AS varchar(40)) AS \"votedAt\" "
                    + "FROM forum_poll_vote v JOIN forum_poll p ON p.id = v.poll_id "
                    + "JOIN forum_poll_option o ON o.id = v.option_id WHERE v.user_id = ? "
                    + "ORDER BY v.created_at DESC LIMIT " + MAX_ROWS, uid);
            return Map.of("votes", rows);
        });
    }
}
