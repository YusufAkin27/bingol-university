package edu.bingol.backend.event;

import edu.bingol.backend.community.ClubMemberLeftEvent;
import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.messaging.room.RoomKind;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Kulupten ayrilan/cikarilan/yasaklanan kisiyi o kulube bagli etkinliklerin sohbet odalarindan cikarir
 * (yalnizca uyelik satirlari; erisimde canli yetki kontrolu zaten vardir). Uyelik islemi commit olduktan sonra,
 * ayri transaction'da calisir; hata uyelik islemini etkilemez. Etkinligi kendisi olusturduysa odada kalir.
 */
@Component
public class EventRoomClubListener {

    private static final Logger log = LoggerFactory.getLogger(EventRoomClubListener.class);

    private final UserEventRepository events;
    private final RoomConversations rooms;

    public EventRoomClubListener(UserEventRepository events, RoomConversations rooms) {
        this.events = events;
        this.rooms = rooms;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onMemberLeft(ClubMemberLeftEvent e) {
        try {
            for (Long eventId : events.idsByCommunityExcludingCreator(e.communityId(), e.userId())) {
                rooms.removeMember(RoomKind.EVENT, eventId, e.userId());
            }
        } catch (RuntimeException ex) {
            log.warn("Etkinlik odalarindan cikarilamadi (kulup {}, kullanici {}): {}", e.communityId(), e.userId(),
                    ex.toString());
        }
    }
}
