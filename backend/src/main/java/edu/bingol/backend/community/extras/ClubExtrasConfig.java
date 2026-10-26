package edu.bingol.backend.community.extras;

import edu.bingol.backend.export.DataExporter;
import edu.bingol.backend.media.MediaReferenceSource;
import java.util.HashMap;
import java.util.Map;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;

/** KVKK disa aktarim + yetim temizleyiciye logo sutununu bildirme (docs/MEDIA_PIPELINE.md). */
@Configuration
public class ClubExtrasConfig {

    /** Kullanicinin verdigi basvuru yanitlari ve yazdigi duyurular (baskalarinin verisi icermez). */
    @Bean
    DataExporter clubExtrasExporter(JdbcTemplate jdbc, ClubAnnouncementRepository announcements) {
        return DataExporter.of("clubExtras", uid -> {
            Map<String, Object> out = new HashMap<>();
            out.put("joinAnswers", jdbc.query("""
                    SELECT a.community_id, q.question, a.answer, a.created_at
                    FROM club_join_answer a JOIN club_join_question q ON q.id = a.question_id
                    WHERE a.user_id = ? ORDER BY a.id
                    """, (rs, i) -> Map.of("communityId", rs.getLong(1), "question", rs.getString(2),
                    "answer", rs.getString(3), "answeredAt", rs.getTimestamp(4).toInstant().toString()), uid));
            out.put("announcements", announcements.findByAuthorIdAndAnnouncementTrueAndDeletedFalse(uid).stream()
                    .map(p -> Map.of("communityId", p.getCommunityId(), "text", p.getContent(),
                            "createdAt", p.getCreatedAt().toString())).toList());
            return out;
        });
    }

    /** community.logo_url herkese acik bir dosyaya isaret eder; referanssiz sanilip 24 saat sonra silinmesin. */
    @Bean
    MediaReferenceSource clubLogoMediaReferenceSource(JdbcTemplate jdbc) {
        return url -> {
            try {
                Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM community WHERE logo_url = ?", Integer.class, url);
                return n == null || n > 0;
            } catch (RuntimeException e) {
                return true; // emin degilsek silmeyiz
            }
        };
    }

}
