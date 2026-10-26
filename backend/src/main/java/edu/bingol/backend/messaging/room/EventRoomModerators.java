package edu.bingol.backend.messaging.room;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.event.EventService;
import org.springframework.context.annotation.Lazy;
import org.springframework.stereotype.Component;

/** Etkinlik odasi: organizator (olusturan, yardimci organizator ya da bagli kulubun etkinlik yoneticisi). */
@Component
class EventRoomModerators implements RoomModerationAuthorizer {

    private final EventService events;

    // @Lazy: event <-> messaging modulleri arasinda baslangic donguleri olusmasin
    EventRoomModerators(@Lazy EventService events) {
        this.events = events;
    }

    @Override
    public RoomKind kind() {
        return RoomKind.EVENT;
    }

    @Override
    public boolean canModerate(Long refId, Long userId) {
        try {
            return events.canManage(new Actor(userId, false), events.load(refId));
        } catch (ApiException e) {
            return false; // etkinlik silinmis
        }
    }
}
