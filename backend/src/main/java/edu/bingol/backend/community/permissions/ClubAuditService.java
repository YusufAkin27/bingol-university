package edu.bingol.backend.community.permissions;

import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Paging;
import edu.bingol.backend.community.permissions.ClubDtos.AuditView;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Kulup denetim kaydi: yazma (cagiranin islemiyle ayni transaction) ve yetkililere okuma. */
@Service
public class ClubAuditService {

    public static final String PERMISSIONS_SET = "PERMISSIONS_SET";
    public static final String PERMISSIONS_RESET = "PERMISSIONS_RESET";
    public static final String MEMBER_APPROVED = "MEMBER_APPROVED";
    public static final String MEMBER_REJECTED = "MEMBER_REJECTED";
    public static final String MEMBER_REMOVED = "MEMBER_REMOVED";
    public static final String MEMBER_BANNED = "MEMBER_BANNED";
    public static final String TRANSFER_REQUESTED = "TRANSFER_REQUESTED";
    public static final String TRANSFER_ACCEPTED = "TRANSFER_ACCEPTED";
    public static final String TRANSFER_DECLINED = "TRANSFER_DECLINED";
    public static final String TRANSFER_CANCELLED = "TRANSFER_CANCELLED";
    public static final String INVITE_CREATED = "INVITE_CREATED";
    public static final String INVITE_REVOKED = "INVITE_REVOKED";
    public static final String INVITE_USED = "INVITE_USED";
    public static final String ANNOUNCEMENT_POSTED = "ANNOUNCEMENT_POSTED";
    public static final String COMMUNITY_DELETED = "COMMUNITY_DELETED";
    public static final String CHAT_ROOM_CLOSED = "CHAT_ROOM_CLOSED";
    public static final String CHAT_ROOM_OPENED = "CHAT_ROOM_OPENED";
    public static final String JOIN_QUESTIONS_SET = "JOIN_QUESTIONS_SET";

    private final ClubAuditRepository audits;
    private final ClubPermissions permissions;
    private final UserRepository users;

    public ClubAuditService(ClubAuditRepository audits, ClubPermissions permissions, UserRepository users) {
        this.audits = audits;
        this.permissions = permissions;
        this.users = users;
    }

    /** Cagiranin transaction'inda yazilir: islem geri alinirsa kayit da geri alinir (olmayan olay loglanmaz). */
    public void record(Long communityId, Long actorId, Long targetUserId, String action, String detail) {
        ClubAudit a = new ClubAudit();
        a.setCommunityId(communityId);
        a.setActorId(actorId);
        a.setTargetUserId(targetUserId);
        a.setAction(action);
        a.setDetail(detail == null || detail.length() <= 500 ? detail : detail.substring(0, 500));
        audits.save(a);
    }

    /** Yalnizca yetkililer (en az bir yetkisi olan uye / sistem ADMIN'i) gorur. */
    @Transactional(readOnly = true)
    public CursorPage<AuditView> page(Actor actor, Long communityId, Long cursor, int size) {
        permissions.requireAnyPermission(actor, communityId);
        int s = CursorPage.clampSize(size);
        var rows = audits.page(communityId, Paging.descStart(cursor), PageRequest.of(0, s + 1));
        return Paging.map(rows, s, ClubAudit::getId, items -> {
            Set<Long> ids = new HashSet<>();
            items.forEach(i -> {
                if (i.getActorId() != null) {
                    ids.add(i.getActorId());
                }
                if (i.getTargetUserId() != null) {
                    ids.add(i.getTargetUserId());
                }
            });
            Map<Long, String> names = new HashMap<>();
            users.findAllById(ids).forEach((User u) -> names.put(u.getId(), u.getDisplayName()));
            return items.stream().map(i -> new AuditView(i.getId(), i.getAction(), i.getActorId(),
                    names.get(i.getActorId()), i.getTargetUserId(), names.get(i.getTargetUserId()), i.getDetail(),
                    i.getCreatedAt())).toList();
        });
    }
}
