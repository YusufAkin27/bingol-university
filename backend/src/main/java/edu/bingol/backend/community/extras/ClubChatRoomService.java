package edu.bingol.backend.community.extras;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.community.extras.ClubExtrasDtos.ChatRoomView;
import edu.bingol.backend.community.permissions.ClubAuditService;
import edu.bingol.backend.community.permissions.ClubPermission;
import edu.bingol.backend.community.permissions.ClubPermissions;
import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.messaging.room.RoomConversations.RoomInfo;
import edu.bingol.backend.messaging.room.RoomKind;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Kulup sohbet odasi uclari. Oda ACTIVE kulupte vardir; erisim yalnizca aktif uyelere (ve sistem ADMIN'ine) aciktir,
 * digerlerine 404 (odanin varligi sizmaz). Kapat/ac yetkisi MANAGE_MEMBERS'a baglidir (yeni bayrak eklenmedi).
 */
@Service
public class ClubChatRoomService {

    private final CommunityService communities;
    private final RoomConversations rooms;
    private final ClubExtrasHooks hooks;
    private final ClubPermissions permissions;
    private final ClubAuditService audit;

    public ClubChatRoomService(CommunityService communities, RoomConversations rooms, ClubExtrasHooks hooks,
                               ClubPermissions permissions, ClubAuditService audit) {
        this.communities = communities;
        this.rooms = rooms;
        this.hooks = hooks;
        this.permissions = permissions;
        this.audit = audit;
    }

    /** Odanin durumu; yoksa (eski kulup / ilk talep) burada kurulur. */
    @Transactional
    public ChatRoomView get(Actor a, Long cid) {
        Community c = requireActiveMemberView(a, cid);
        return view(a, c);
    }

    /** Odadan ayrilmis (veya sonradan eklenemeyen) aktif uyenin odaya yeniden girmesi. */
    @Transactional
    public ChatRoomView join(Actor a, Long cid) {
        Community c = requireActiveMemberView(a, cid);
        RoomInfo info = rooms.find(RoomKind.COMMUNITY, cid).orElseThrow(ClubChatRoomService::notFound);
        if (info.closed()) {
            throw new ApiException(HttpStatus.CONFLICT, "CHAT_ROOM_CLOSED", "Sohbet odası kapalı.");
        }
        if (!rooms.addMember(RoomKind.COMMUNITY, cid, a.id())) {
            throw notFound(); // hesap uygun degil (askida/dogrulanmamis) ya da oda kapandi
        }
        return view(a, c);
    }

    /** MANAGE_MEMBERS: odayi kapatir (herkes cikar, gecmis saklanir) ya da yeniden acar (aktif uyeler geri eklenir). */
    @Transactional
    public ChatRoomView setClosed(Actor a, Long cid, boolean closed) {
        Community c = communities.load(cid);
        permissions.require(a, cid, ClubPermission.MANAGE_MEMBERS);
        if (c.getStatus() != Community.Status.ACTIVE) {
            throw new ApiException(HttpStatus.CONFLICT, "COMMUNITY_NOT_ACTIVE", "Topluluk henüz yayında değil.");
        }
        if (rooms.find(RoomKind.COMMUNITY, cid).isEmpty()) {
            hooks.onCommunityActivated(c);
        }
        if (closed) {
            rooms.closeRoom(RoomKind.COMMUNITY, cid);
        } else {
            rooms.openRoom(RoomKind.COMMUNITY, cid, hooks.activeUserIds(cid));
        }
        audit.record(cid, a.id(), null, closed ? ClubAuditService.CHAT_ROOM_CLOSED : ClubAuditService.CHAT_ROOM_OPENED, null);
        return view(a, c);
    }

    // ---- ic yardimcilar ----

    private Community requireActiveMemberView(Actor a, Long cid) {
        Community c = communities.load(cid);
        boolean member = permissions.standing(a, cid).isPresent();
        if (c.getStatus() != Community.Status.ACTIVE || !member) {
            throw notFound();
        }
        if (rooms.find(RoomKind.COMMUNITY, cid).isEmpty()) {
            hooks.onCommunityActivated(c);
        }
        return c;
    }

    private ChatRoomView view(Actor a, Community c) {
        RoomInfo info = rooms.find(RoomKind.COMMUNITY, c.getId()).orElse(null);
        if (info == null) {
            throw notFound();
        }
        boolean joined = rooms.isMember(RoomKind.COMMUNITY, c.getId(), a.id());
        return new ChatRoomView(info.closed() ? null : info.conversationId(), info.closed(), joined,
                info.closed() ? 0 : rooms.memberCount(RoomKind.COMMUNITY, c.getId()));
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "CHAT_ROOM_NOT_FOUND", "Sohbet odası bulunamadı.");
    }
}
