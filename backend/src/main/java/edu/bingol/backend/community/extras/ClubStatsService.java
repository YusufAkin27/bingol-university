package edu.bingol.backend.community.extras;

import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.community.extras.ClubExtrasDtos.ClubStats;
import edu.bingol.backend.community.permissions.ClubPermissions;
import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.messaging.room.RoomConversations.RoomInfo;
import edu.bingol.backend.messaging.room.RoomKind;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Kulup istatistikleri (yalnizca yetkililer). Toplulastirilmis sayilardir; kisisel veri icermez. Sorgu tek
 * parametreli SQL'dir (PostgreSQL); H2 birim testlerinde calistirilmaz, duman betigiyle dogrulanir.
 */
@Service
public class ClubStatsService {

    static final String SQL = """
            SELECT
              (SELECT COUNT(*) FROM community_member m JOIN app_user u ON u.id = m.user_id
                WHERE m.community_id = ? AND m.status = 'ACTIVE' AND u.status <> 'DELETED'),
              (SELECT COUNT(*) FROM community_member m JOIN app_user u ON u.id = m.user_id
                WHERE m.community_id = ? AND m.status = 'PENDING' AND u.status <> 'DELETED'),
              (SELECT COUNT(*) FROM community_member m JOIN app_user u ON u.id = m.user_id
                WHERE m.community_id = ? AND m.status = 'ACTIVE' AND u.status <> 'DELETED' AND m.joined_at >= ?),
              (SELECT COUNT(*) FROM community_post WHERE community_id = ? AND deleted = FALSE),
              (SELECT COUNT(*) FROM community_post WHERE community_id = ? AND deleted = FALSE AND created_at >= ?),
              (SELECT COUNT(*) FROM community_post WHERE community_id = ? AND deleted = FALSE AND announcement = TRUE)
            """;

    static final String CHAT_SQL = "SELECT COUNT(*) FROM message WHERE conversation_id = ? AND created_at >= ?";

    private final CommunityService communities;
    private final ClubPermissions permissions;
    private final RoomConversations rooms;
    private final JdbcTemplate jdbc;

    public ClubStatsService(CommunityService communities, ClubPermissions permissions, RoomConversations rooms,
                            JdbcTemplate jdbc) {
        this.communities = communities;
        this.permissions = permissions;
        this.rooms = rooms;
        this.jdbc = jdbc;
    }

    @Transactional(readOnly = true)
    public ClubStats stats(Actor a, Long cid) {
        communities.loadVisible(a, cid);
        permissions.requireAnyPermission(a, cid);
        Timestamp week = Timestamp.from(Instant.now().minus(Duration.ofDays(7)));
        long[] v = jdbc.queryForObject(SQL, (rs, i) -> new long[] {rs.getLong(1), rs.getLong(2), rs.getLong(3),
                rs.getLong(4), rs.getLong(5), rs.getLong(6)}, cid, cid, cid, week, cid, cid, week, cid);
        RoomInfo room = rooms.find(RoomKind.COMMUNITY, cid).orElse(null);
        boolean chatActive = room != null && !room.closed();
        long chatMembers = chatActive ? rooms.memberCount(RoomKind.COMMUNITY, cid) : 0;
        Long msgs = chatActive ? jdbc.queryForObject(CHAT_SQL, Long.class, room.conversationId(), week) : Long.valueOf(0);
        return new ClubStats(v[0], v[1], v[2], v[3], v[4], v[5], chatActive, chatMembers, msgs == null ? 0 : msgs);
    }
}
