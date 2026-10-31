package edu.bingol.backend.messaging;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Mesaj istegi karari (T-026, K-08 secenek b). Ilk birebir mesaj YALNIZ ortak baglam varsa dogrudan acilir; yoksa
 * alici icin istek (PENDING) olur. Grup daveti ise daveti alan ekleyeni takip ediyor ya da onunla kabul edilmis bir
 * birebir konusmasi varsa dogrudan; aksi halde kabul gerektirir. Duz SQL (yalniz okuma; H2 ve PostgreSQL ortak).
 */
@Component
public class MessageRequestPolicy {

    private final JdbcTemplate jdbc;

    public MessageRequestPolicy(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Ilk birebir mesaj dogrudan acilabilir mi: ortak aktif kulup, ortak etkinlikte GOING (INTERESTED sayilmaz) ya da
     * ALICI gonderenı takip ediyor (alicinin kendi tercihi; gonderenin takibi baglam sayilmaz: herkes herkesi takip edebilir).
     */
    public boolean directAllowed(Long sender, Long recipient) {
        return sharedClub(sender, recipient) || sharedEvent(sender, recipient) || follows(recipient, sender);
    }

    /** Gruba davet edilen, ekleyen kisiyle zaten gorusmeyi kabul etmis mi (takip ya da kabul edilmis birebir). */
    public boolean groupInviteAllowed(Long adder, Long invitee) {
        return follows(invitee, adder) || acceptedDirect(adder, invitee);
    }

    private boolean sharedClub(Long a, Long b) {
        return count("SELECT COUNT(*) FROM community_member x JOIN community_member y ON x.community_id = y.community_id "
                + "WHERE x.user_id = ? AND y.user_id = ? AND x.status = 'ACTIVE' AND y.status = 'ACTIVE'", a, b) > 0;
    }

    private boolean sharedEvent(Long a, Long b) {
        return count("SELECT COUNT(*) FROM event_rsvp x JOIN event_rsvp y ON x.event_id = y.event_id "
                + "WHERE x.user_id = ? AND y.user_id = ? AND x.status = 'GOING' AND y.status = 'GOING'", a, b) > 0;
    }

    private boolean follows(Long follower, Long followee) {
        return count("SELECT COUNT(*) FROM user_follow WHERE follower_id = ? AND followee_id = ?", follower, followee) > 0;
    }

    private boolean acceptedDirect(Long a, Long b) {
        return count("SELECT COUNT(*) FROM conversation c JOIN conversation_member m ON m.conversation_id = c.id "
                + "WHERE c.direct_key = ? AND m.user_id = ? AND m.left_at IS NULL AND m.request_state = 'ACCEPTED'",
                Conversation.directKey(a, b), a) > 0
                && count("SELECT COUNT(*) FROM conversation c JOIN conversation_member m ON m.conversation_id = c.id "
                + "WHERE c.direct_key = ? AND m.user_id = ? AND m.left_at IS NULL AND m.request_state = 'ACCEPTED'",
                Conversation.directKey(a, b), b) > 0;
    }

    private long count(String sql, Object... args) {
        Long n = jdbc.queryForObject(sql, Long.class, args);
        return n == null ? 0 : n;
    }
}
