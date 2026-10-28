package edu.bingol.backend.community;

import edu.bingol.backend.community.permissions.ClubAuditService;
import edu.bingol.backend.community.permissions.ClubMemberGrantRepository;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.profile.UserAccountDeletedEvent;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Hesap silme sonrasi kulup tarafi (KVKK + sahipsiz kulup onleme) ve kulup silinince gonderi gorselleri.
 *
 * <p>Politika (en kucuk guvenli): hesabini silen kullanici bir kulubun SAHIBIYSE, kulubun aktif ADMIN rolundeki, yoksa
 * MODERATOR rolundeki en eski aktif uyesine sahiplik devredilir (uye 3 kulup sinirini asmiyorsa); aday yoksa kulup
 * kapatilir (yumusak silme; uyelere haber gider, bagli gelecek etkinlikler iptal edilir). Sahibin uyelik satiri
 * silinir. Hata silme islemini etkilemez; commit sonrasi ayri transaction'da calisir.
 */
@Component
public class CommunityAccountListener {

    private static final Logger log = LoggerFactory.getLogger(CommunityAccountListener.class);

    /** ClubOwnershipService.MAX_OWNED ile ayni sinir (3 kulup). */
    static final int MAX_OWNED = 3;
    static final List<Community.Status> LIVE = List.of(Community.Status.PENDING_REVIEW, Community.Status.ACTIVE);
    private static final List<Community.Status> OWNED = List.of(
            Community.Status.PENDING_REVIEW, Community.Status.ACTIVE, Community.Status.HIDDEN);
    static final String OWNER_AUTO_TRANSFERRED = "OWNER_AUTO_TRANSFERRED";

    private final CommunityRepository communities;
    private final CommunityMemberRepository members;
    private final ClubMemberGrantRepository grants;
    private final ClubAuditService audit;
    private final CommunityService service;
    private final NotificationService notifications;
    private final UserRepository users;
    private final CommunityPostMedia postMedia;

    public CommunityAccountListener(CommunityRepository communities, CommunityMemberRepository members,
                                    ClubMemberGrantRepository grants, ClubAuditService audit, CommunityService service,
                                    NotificationService notifications, UserRepository users, CommunityPostMedia postMedia) {
        this.communities = communities;
        this.members = members;
        this.grants = grants;
        this.audit = audit;
        this.service = service;
        this.notifications = notifications;
        this.users = users;
        this.postMedia = postMedia;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onAccountDeleted(UserAccountDeletedEvent ev) {
        try {
            postMedia.releaseByAuthor(ev.userId());
        } catch (RuntimeException e) {
            log.warn("Silinen hesabin gonderi gorselleri temizlenemedi (kullanici {}): {}", ev.userId(), e.toString());
        }
        try {
            handleOwnedClubs(ev.userId());
        } catch (RuntimeException e) {
            log.warn("Silinen hesabin kulup sahipligi islenemedi (kullanici {}): {}", ev.userId(), e.toString());
        }
    }

    /** Kulup silindi: yazi gorselleri diskten kalkar (bagli etkinlikleri ayri dinleyici iptal eder). */
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onClubDeleted(ClubDeletedEvent ev) {
        try {
            postMedia.releaseByCommunity(ev.communityId());
        } catch (RuntimeException e) {
            log.warn("Kulup gonderi gorselleri temizlenemedi (kulup {}): {}", ev.communityId(), e.toString());
        }
    }

    /** @return devredilen kulup sayisi (testler icin) */
    int handleOwnedClubs(Long userId) {
        int transferred = 0;
        for (Community c : communities.findByOwnerIdAndStatusIn(userId, OWNED)) {
            Long successor = findSuccessor(c.getId(), userId);
            if (successor == null) {
                // Devralacak yonetici yok: kulup kapatilir (uyelere haber gider, etkinlikleri iptal edilir)
                service.delete(new Actor(userId, true), c.getId());
                continue;
            }
            transfer(c, userId, successor);
            transferred++;
        }
        return transferred;
    }

    private Long findSuccessor(Long communityId, Long oldOwner) {
        for (CommunityMember.Role role : List.of(CommunityMember.Role.ADMIN, CommunityMember.Role.MODERATOR)) {
            for (CommunityMember m : members.findByCommunityIdAndStatusAndRoleInOrderByJoinedAtAscIdAsc(
                    communityId, CommunityMember.Status.ACTIVE, List.of(role))) {
                if (!m.getUserId().equals(oldOwner) && usable(m.getUserId())
                        && communities.countByOwnerIdAndStatusIn(m.getUserId(), LIVE) < MAX_OWNED) {
                    return m.getUserId();
                }
            }
        }
        return null;
    }

    private boolean usable(Long userId) {
        return users.findById(userId).map(u -> u.getStatus() == UserStatus.ACTIVE).orElse(false);
    }

    private void transfer(Community c, Long oldOwner, Long newOwner) {
        CommunityMember nm = members.findByCommunityIdAndUserId(c.getId(), newOwner).orElseThrow();
        nm.setRole(CommunityMember.Role.OWNER);
        members.save(nm);
        grants.deleteMember(c.getId(), newOwner);
        members.findByCommunityIdAndUserId(c.getId(), oldOwner).ifPresent(members::delete);
        grants.deleteMember(c.getId(), oldOwner);
        c.setOwnerId(newOwner);
        c.setUpdatedAt(Instant.now());
        communities.save(c);
        audit.record(c.getId(), null, newOwner, OWNER_AUTO_TRANSFERRED, "reason=account_deleted oldOwner=" + oldOwner);
        notifications.sendTemplated(newOwner, NotificationType.COMMUNITY, "notif.community.ownerAutoTransferred",
                Map.of("communityId", c.getId().toString()), c.getName());
    }
}
