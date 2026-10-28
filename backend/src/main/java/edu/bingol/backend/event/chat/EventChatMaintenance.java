package edu.bingol.backend.event.chat;

import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.messaging.room.RoomKind;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Etkinlik odalari icin periyodik tutarlilik (T15 ClubExtrasMaintenance yalniz COMMUNITY'yi kapatir):
 * (1) iptal/gizlenen etkinligin ya da bitisinden {@code event-room-close-days} gun gecmis etkinligin odasini kapatir,
 * (2) GOING olmayan/organizator olmayan uyeleri cikarir (ban, hesap, vazgecme kacaklarina karsi guvence),
 * (3) hic uye satiri olmayan organizator ve ortak organizatorleri ekler. Sozlesme: exception sizdirmaz.
 */
@Component
public class EventChatMaintenance {

    private static final Logger log = LoggerFactory.getLogger(EventChatMaintenance.class);

    private final RoomConversations rooms;
    private final JdbcTemplate jdbc;
    private final int closeDays;

    public EventChatMaintenance(RoomConversations rooms, JdbcTemplate jdbc,
                                @Value("${app.chat.event-room-close-days:7}") int closeDays) {
        this.rooms = rooms;
        this.jdbc = jdbc;
        this.closeDays = Math.max(0, closeDays);
    }

    @Scheduled(fixedDelayString = "${app.chat.room-purge-ms:300000}", initialDelayString = "${app.chat.room-purge-ms:300000}")
    public void run() {
        try {
            Timestamp cutoff = Timestamp.from(Instant.now().minus(Duration.ofDays(closeDays)));
            List<Long> toClose = jdbc.queryForList("""
                    SELECT l.ref_id FROM chat_room_link l JOIN user_event e ON e.id = l.ref_id
                    WHERE l.kind = 'EVENT' AND l.closed = FALSE
                      AND (e.status IN ('CANCELLED', 'HIDDEN', 'REJECTED') OR e.ends_at < ?)
                    """, Long.class, cutoff);
            for (Long id : toClose) {
                rooms.closeRoom(RoomKind.EVENT, id);
            }
            int removed = jdbc.update("""
                    UPDATE conversation_member m SET left_at = now()
                    WHERE m.left_at IS NULL AND EXISTS (
                      SELECT 1 FROM chat_room_link l JOIN user_event e ON e.id = l.ref_id
                      WHERE l.kind = 'EVENT' AND l.closed = FALSE AND l.conversation_id = m.conversation_id
                        AND e.created_by <> m.user_id
                        AND NOT EXISTS (SELECT 1 FROM event_rsvp r WHERE r.event_id = e.id AND r.user_id = m.user_id
                                        AND r.status = 'GOING')
                        AND NOT EXISTS (SELECT 1 FROM event_co_organizer c WHERE c.event_id = e.id AND c.user_id = m.user_id)
                        AND NOT EXISTS (SELECT 1 FROM community_member cm WHERE cm.community_id = e.community_id
                                        AND cm.user_id = m.user_id AND cm.status = 'ACTIVE' AND cm.role <> 'MEMBER'))
                    """);
            List<Map<String, Object>> missing = jdbc.queryForList("""
                    SELECT l.ref_id AS ref, o.uid AS uid FROM chat_room_link l
                    JOIN (SELECT id AS eid, created_by AS uid FROM user_event
                          UNION SELECT event_id, user_id FROM event_co_organizer) o ON o.eid = l.ref_id
                    WHERE l.kind = 'EVENT' AND l.closed = FALSE
                      AND NOT EXISTS (SELECT 1 FROM conversation_member m
                                      WHERE m.conversation_id = l.conversation_id AND m.user_id = o.uid)
                    """);
            for (Map<String, Object> row : missing) {
                try {
                    rooms.addMember(RoomKind.EVENT, ((Number) row.get("ref")).longValue(), ((Number) row.get("uid")).longValue());
                } catch (RuntimeException e) {
                    log.debug("Organizator odaya eklenemedi: {}", e.toString());
                }
            }
            if (!toClose.isEmpty() || removed > 0) {
                log.info("Etkinlik odalari: {} kapatildi, {} uyelik kaldirildi", toClose.size(), removed);
            }
        } catch (RuntimeException e) {
            log.warn("Etkinlik oda bakim gorevi basarisiz: {}", e.toString());
        }
    }
}
