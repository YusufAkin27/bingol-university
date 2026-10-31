package edu.bingol.backend.event;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.messaging.ConversationService;
import edu.bingol.backend.messaging.dto.MessagingDtos.ConversationView;
import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.messaging.room.RoomConversations.RoomInfo;
import edu.bingol.backend.messaging.room.RoomKind;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Etkinlik sohbeti: odayi getir-ya-da-olustur, yetkiliyi (RSVP GOING ya da organizator) ekle.
 * Etkinlik gorunmuyorsa 404 EVENT_NOT_FOUND; gorunen ama yetkisiz kisiye 403 FORBIDDEN.
 */
@Service
public class EventChatService {

    private final EventService events;
    private final EventRsvpRepository rsvps;
    private final RoomConversations rooms;
    private final ConversationService conversations;

    public EventChatService(EventService events, EventRsvpRepository rsvps, RoomConversations rooms,
                            ConversationService conversations) {
        this.events = events;
        this.rsvps = rsvps;
        this.rooms = rooms;
        this.conversations = conversations;
    }

    @Transactional
    public ConversationView open(Actor a, Long eventId) {
        UserEvent e = events.loadVisible(a, eventId);
        if (e.getStatus() != UserEvent.Status.ACTIVE) {
            throw notFound(); // yayinda olmayan/iptal edilen etkinlikte sohbet yok
        }
        // T-045: yalniz GOING (kabul edilmis) katilimci ya da organizator; INTERESTED / bekleyen basvuru APPROVAL
        // modunu atlayip odaya giremez (yeni oda ucu event.chat.EventChatService ile ayni kural)
        boolean allowed = rsvps.findByEventIdAndUserId(eventId, a.id())
                .map(r -> r.getStatus() == EventRsvp.Status.GOING).orElse(false) || events.canManage(a, e);
        if (!allowed) {
            throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "Bu işlem için yetkiniz yok.");
        }
        rooms.ensureRoom(RoomKind.EVENT, eventId, e.getTitle(), e.getCreatedBy());
        RoomInfo info = rooms.find(RoomKind.EVENT, eventId).orElseThrow(EventChatService::notFound);
        if (info.closed()) {
            throw new ApiException(HttpStatus.CONFLICT, "CHAT_ROOM_CLOSED", "Sohbet odası kapalı.");
        }
        if (!rooms.addMember(RoomKind.EVENT, eventId, a.id())) {
            throw notFound(); // hesap uygun degil (askida/dogrulanmamis)
        }
        return conversations.view(a.id(), info.conversationId());
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "EVENT_NOT_FOUND", "Etkinlik bulunamadı.");
    }
}
