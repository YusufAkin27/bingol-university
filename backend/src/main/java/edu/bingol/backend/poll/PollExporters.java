package edu.bingol.backend.poll;

import edu.bingol.backend.export.DataExporter;
import java.util.List;
import java.util.Map;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * KVKK disa aktarim: kullanicinin KENDI oylari ve olusturdugu anketler. Gizli ankette hangi secenege oy verildigi
 * yalniz burada (kullanicinin kendi dosyasinda) gorunur; baska hicbir uc bunu gostermez.
 */
@Configuration
public class PollExporters {

    static final int MAX_ROWS = 5000;

    @Bean
    DataExporter pollsExporter(JdbcTemplate jdbc) {
        return DataExporter.of("polls", uid -> {
            List<Map<String, Object>> voted = jdbc.queryForList("SELECT v.poll_id AS \"pollId\", p.title AS \"pollTitle\", "
                    + "p.anonymous AS anonymous, o.text AS \"optionText\", v.choice_rank AS \"rank\", "
                    + "CAST(v.created_at AS varchar) AS \"votedAt\" FROM poll_vote v JOIN poll p ON p.id = v.poll_id "
                    + "JOIN poll_option o ON o.id = v.option_id WHERE v.user_id = ? ORDER BY v.id DESC LIMIT " + MAX_ROWS, uid);
            List<Map<String, Object>> created = jdbc.queryForList("SELECT id, title, scope, type, status, "
                    + "CAST(created_at AS varchar) AS \"createdAt\" FROM poll WHERE created_by = ? ORDER BY id DESC LIMIT "
                    + MAX_ROWS, uid);
            return Map.of("votes", voted, "created", created);
        });
    }
}
