package edu.bingol.backend.messaging.room;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Askiya alinan/silinen kullanicilarin odalardan otomatik cikarilmasi (HTTP/WS erisimi zaten aninda kesilir). */
@Component
public class RoomMaintenance {

    /** Coklu ornek kilidi (DATABASE.md sorgu kurali 9.4); yoksa (testler/elle kurulum) eski davranis: kilitsiz calisir. */
    private edu.bingol.backend.config.SchedulerLock lock;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setLock(edu.bingol.backend.config.SchedulerLock lock) {
        this.lock = lock;
    }

    private void locked(String name, int minutes, Runnable job) {
        if (lock == null) {
            job.run();
        } else {
            lock.tryRunOrLocal(name, java.time.Duration.ofMinutes(minutes), job);
        }
    }

    private static final Logger log = LoggerFactory.getLogger(RoomMaintenance.class);

    private final RoomConversations rooms;

    public RoomMaintenance(RoomConversations rooms) {
        this.rooms = rooms;
    }

    @Scheduled(fixedDelayString = "${app.chat.room-purge-ms:300000}", initialDelayString = "${app.chat.room-purge-ms:300000}")
    public void scheduledPurge() {
        locked("room-maintenance", 10, this::purge);
    }

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
