package edu.bingol.backend.profile;

import edu.bingol.backend.messaging.MessageRepository;
import edu.bingol.backend.profile.dto.ProfileDtos.MeSummary;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Mobil ana sayfa rozetleri ve profil istatistikleri: tek SQL ile ucuz sayimlar + mesaj okunmamis toplami. */
@Service
public class MeSummaryService {

    /** Her alt sorgu mevcut bir kullanici indeksini kullanir (idx_member_user, idx_rsvp_user, idx_bookmark_user_type). */
    static final String COUNTS_SQL = """
            SELECT
              (SELECT COUNT(*) FROM community_member WHERE user_id = ? AND status = 'ACTIVE'),
              (SELECT COUNT(*) FROM event_rsvp r JOIN user_event e ON e.id = r.event_id
                 WHERE r.user_id = ? AND r.status = 'GOING' AND e.status = 'ACTIVE'
                   AND e.ends_at > CURRENT_TIMESTAMP),
              (SELECT COUNT(*) FROM bookmark WHERE user_id = ?),
              (SELECT COUNT(*) FROM notification WHERE user_id = ? AND read_at IS NULL)
            """;

    private final JdbcTemplate jdbc;
    private final MessageRepository messages;

    public MeSummaryService(JdbcTemplate jdbc, MessageRepository messages) {
        this.jdbc = jdbc;
        this.messages = messages;
    }

    @Transactional(readOnly = true)
    public MeSummary summary(Long userId) {
        long[] c = jdbc.queryForObject(COUNTS_SQL,
                (rs, i) -> new long[] {rs.getLong(1), rs.getLong(2), rs.getLong(3), rs.getLong(4)},
                userId, userId, userId, userId);
        return new MeSummary(c[0], c[1], c[2], c[3], unreadMessages(userId));
    }

    private long unreadMessages(Long userId) {
        List<Object[]> rows = messages.unreadAll(userId);
        return rows.stream().mapToLong(r -> ((Number) r[1]).longValue()).sum();
    }
}
