package edu.bingol.backend.messaging.room;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Askiya alinan/silinen kullanicilarin odalardan otomatik cikarilmasi (HTTP/WS erisimi zaten aninda kesilir). */
@Component
public class RoomMaintenance {

    private static final Logger log = LoggerFactory.getLogger(RoomMaintenance.class);

    private final RoomConversations rooms;

    public RoomMaintenance(RoomConversations rooms) {
        this.rooms = rooms;
    }

    @Scheduled(fixedDelayString = "${app.chat.room-purge-ms:300000}", initialDelayString = "${app.chat.room-purge-ms:300000}")
    public void purge() {
        try {
            int n = rooms.purgeInactiveUsers();
            if (n > 0) {
                log.info("Odalardan {} pasif kullanici uyeligi kaldirildi", n);
            }
        } catch (RuntimeException e) {
            log.warn("Oda temizligi basarisiz: {}", e.toString()); // sozlesme: exception sizdirma
        }
    }
}
