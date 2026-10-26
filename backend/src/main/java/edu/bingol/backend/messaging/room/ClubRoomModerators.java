package edu.bingol.backend.messaging.room;

import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.community.permissions.ClubPermission;
import org.springframework.context.annotation.Lazy;
import org.springframework.stereotype.Component;

/** Kulup odasi: gonderi yonetme yetkisi olan yonetici/moderator (CommunityService genel yetki sorgusu). */
@Component
class ClubRoomModerators implements RoomModerationAuthorizer {

    private final CommunityService communities;

    // @Lazy: community <-> messaging modulleri arasinda baslangic donguleri olusmasin
    ClubRoomModerators(@Lazy CommunityService communities) {
        this.communities = communities;
    }

    @Override
    public RoomKind kind() {
        return RoomKind.COMMUNITY;
    }

    @Override
    public boolean canModerate(Long refId, Long userId) {
        // admin=false: sistem yoneticisi sohbet moderasyonu icin ayrica yetkilendirilmez
        return communities.can(new Actor(userId, false), refId, ClubPermission.MANAGE_POSTS);
    }
}
