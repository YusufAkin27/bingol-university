package edu.bingol.backend.community.extras;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.community.permissions.ClubPermissions;
import edu.bingol.backend.messaging.ConversationService;
import edu.bingol.backend.messaging.dto.MessagingDtos.ConversationView;
import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.messaging.room.RoomConversations.RoomInfo;
import edu.bingol.backend.messaging.room.RoomKind;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Mobil sohbet sekmesi icin "getir-ya-da-olustur" ucu: kulup odasini kurar, aktif uyeyi odaya ekler ve
 * konusma gorunumunu doner. Yetkisiz kisiye 404 (odanin varligi sizmaz); kapali odada 409.
 */
@Service
public class ClubChatService {

    private final CommunityService communities;
    private final RoomConversations rooms;
    private final ClubExtrasHooks hooks;
    private final ClubPermissions permissions;
    private final ConversationService conversations;

    public ClubChatService(CommunityService communities, RoomConversations rooms, ClubExtrasHooks hooks,
                           ClubPermissions permissions, ConversationService conversations) {
        this.communities = communities;
        this.rooms = rooms;
        this.hooks = hooks;
        this.permissions = permissions;
        this.conversations = conversations;
    }

    @Transactional
    public ConversationView open(Actor a, Long cid) {
        Community c = communities.load(cid);
        // Canli yetki: yalnizca ACTIVE kulubun aktif uyesi (ya da yetkisi olan) girebilir.
        if (c.getStatus() != Community.Status.ACTIVE || permissions.standing(a, cid).isEmpty()) {
            throw notFound();
        }
        if (rooms.find(RoomKind.COMMUNITY, cid).isEmpty()) {
            hooks.onCommunityActivated(c);
        }
        RoomInfo info = rooms.find(RoomKind.COMMUNITY, cid).orElseThrow(ClubChatService::notFound);
        if (info.closed()) {
            throw new ApiException(HttpStatus.CONFLICT, "CHAT_ROOM_CLOSED", "Sohbet odası kapalı.");
        }
        if (!rooms.addMember(RoomKind.COMMUNITY, cid, a.id())) {
            throw notFound(); // hesap uygun degil (askida/dogrulanmamis)
        }
        return conversations.view(a.id(), info.conversationId());
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "CHAT_ROOM_NOT_FOUND", "Sohbet odası bulunamadı.");
    }
}
