package edu.bingol.backend.community.extras;

import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.messaging.room.RoomKind;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Periyodik tutarlilik: (1) yayindan dusen (gizlenen/reddedilen) kulubun sohbet odasini kapatir, (2) hesabi silinen
 * kullanicilarin basvuru yanitlarini temizler (KVKK). Sozlesme: exception sizdirmaz.
 */
@Component
public class ClubExtrasMaintenance {

    private static final Logger log = LoggerFactory.getLogger(ClubExtrasMaintenance.class);

    private final RoomConversations rooms;
    private final JdbcTemplate jdbc;

    public ClubExtrasMaintenance(RoomConversations rooms, JdbcTemplate jdbc) {
        this.rooms = rooms;
        this.jdbc = jdbc;
    }

    @Scheduled(fixedDelayString = "${app.chat.room-purge-ms:300000}", initialDelayString = "${app.chat.room-purge-ms:300000}")
    public void run() {
        try {
            List<Long> ids = jdbc.queryForList("""
                    SELECT l.ref_id FROM chat_room_link l JOIN community c ON c.id = l.ref_id
                    WHERE l.kind = 'COMMUNITY' AND l.closed = FALSE AND c.status <> 'ACTIVE'
                    """, Long.class);
            for (Long id : ids) {
                rooms.closeRoom(RoomKind.COMMUNITY, id);
            }
            jdbc.update("DELETE FROM club_join_answer WHERE user_id IN (SELECT id FROM app_user WHERE status = 'DELETED')");
        } catch (RuntimeException e) {
            log.warn("Kulup bakim gorevi basarisiz: {}", e.toString());
        }
    }

}
