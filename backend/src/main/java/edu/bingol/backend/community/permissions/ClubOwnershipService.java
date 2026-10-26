package edu.bingol.backend.community.permissions;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.CommunityMemberRepository;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.community.permissions.ClubDtos.TransferRequest;
import edu.bingol.backend.community.permissions.ClubDtos.TransferView;
import edu.bingol.backend.community.permissions.ClubOwnershipTransfer.Status;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Iki asamali, geri alinamaz sahiplik devri: sahip hedef uyeye teklif eder (acik onayla), hedef de acik onayla
 * kabul ederse devir olur. Eski sahip ADMIN olarak kalir ya da kulupten ayrilir. Ayni anda tek bekleyen teklif.
 */
@Service
public class ClubOwnershipService {

    static final Duration TTL = Duration.ofDays(3);
    static final int MAX_OWNED = 3;
    private static final List<Community.Status> LIVE = List.of(Community.Status.PENDING_REVIEW, Community.Status.ACTIVE);

    private final CommunityRepository communities;
    private final CommunityMemberRepository members;
    private final ClubMemberGrantRepository grants;
    private final ClubOwnershipTransferRepository transfers;
    private final ClubAuditService audit;
    private final NotificationService notifications;
    private final UserRepository users;

    public ClubOwnershipService(CommunityRepository communities, CommunityMemberRepository members,
                                ClubMemberGrantRepository grants, ClubOwnershipTransferRepository transfers,
                                ClubAuditService audit, NotificationService notifications, UserRepository users) {
        this.communities = communities;
        this.members = members;
        this.grants = grants;
        this.transfers = transfers;
        this.audit = audit;
        this.notifications = notifications;
        this.users = users;
    }

    @Transactional
    public TransferView request(Actor a, Long communityId, TransferRequest r) {
        Community c = community(communityId);
        requireOwner(a, c);
        if (!r.confirmIrreversible()) {
            throw confirmRequired();
        }
        if (c.getStatus() != Community.Status.ACTIVE) {
            throw new ApiException(HttpStatus.CONFLICT, "COMMUNITY_NOT_ACTIVE", "Topluluk henüz yayında değil.");
        }
        Long to = r.targetUserId();
        CommunityMember target = members.findByCommunityIdAndUserId(communityId, to).filter(CommunityMember::isActive)
                .orElse(null);
        if (target == null || to.equals(a.id()) || target.getRole() == Role.OWNER) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "TRANSFER_TARGET_INVALID",
                    "Devir için topluluğun başka bir aktif üyesini seçin.");
        }
        expireStale(communityId);
        if (live(communityId).isPresent()) {
            throw new ApiException(HttpStatus.CONFLICT, "TRANSFER_PENDING", "Bekleyen bir devir teklifi zaten var.");
        }
        ClubOwnershipTransfer t = new ClubOwnershipTransfer();
        t.setCommunityId(communityId);
        t.setFromUserId(a.id());
        t.setToUserId(to);
        t.setKeepAsAdmin(r.keepAsAdmin());
        t.setExpiresAt(Instant.now().plus(TTL));
        transfers.save(t);
        audit.record(communityId, a.id(), to, ClubAuditService.TRANSFER_REQUESTED, "keepAsAdmin=" + r.keepAsAdmin());
        notifications.sendTemplated(to, NotificationType.COMMUNITY, "notif.community.transferRequest",
                Map.of("communityId", communityId.toString()), name(a.id()), c.getName());
        return view(t);
    }

    /** Hedef uye kabul eder: sahiplik gecer. Geri alinamaz. */
    @Transactional
    public TransferView accept(Actor a, Long communityId, boolean confirm) {
        Community c = community(communityId);
        ClubOwnershipTransfer t = pendingFor(communityId, a.id(), true);
        if (!confirm) {
            throw confirmRequired();
        }
        CommunityMember newOwner = members.findByCommunityIdAndUserId(communityId, a.id())
                .filter(CommunityMember::isActive).orElse(null);
        CommunityMember oldOwner = members.findByCommunityIdAndUserId(communityId, t.getFromUserId()).orElse(null);
        // Teklif sonradan gecersizlestiyse (sahip degisti, hedef ayrildi) kabul edilmez.
        if (newOwner == null || oldOwner == null || oldOwner.getRole() != Role.OWNER
                || !t.getFromUserId().equals(c.getOwnerId())) {
            throw noTransfer();
        }
        if (communities.countByOwnerIdAndStatusIn(a.id(), LIVE) >= MAX_OWNED) {
            throw new ApiException(HttpStatus.CONFLICT, "COMMUNITY_LIMIT",
                    "En fazla " + MAX_OWNED + " topluluğun sahibi olabilirsiniz.", String.valueOf(MAX_OWNED));
        }
        newOwner.setRole(Role.OWNER);
        members.save(newOwner);
        grants.deleteMember(communityId, a.id());
        if (t.isKeepAsAdmin()) {
            oldOwner.setRole(Role.ADMIN);
            members.save(oldOwner);
        } else {
            members.delete(oldOwner);
        }
        grants.deleteMember(communityId, t.getFromUserId());
        c.setOwnerId(a.id());
        c.setUpdatedAt(Instant.now());
        communities.save(c);
        t.setStatus(Status.ACCEPTED);
        t.setDecidedAt(Instant.now());
        transfers.save(t);
        audit.record(communityId, a.id(), t.getFromUserId(), ClubAuditService.TRANSFER_ACCEPTED,
                "newOwner=" + a.id() + " oldOwner=" + t.getFromUserId() + " keepAsAdmin=" + t.isKeepAsAdmin());
        notifications.sendTemplated(t.getFromUserId(), NotificationType.COMMUNITY, "notif.community.transferAccepted",
                Map.of("communityId", communityId.toString()), name(a.id()), c.getName());
        return view(t);
    }

    @Transactional
    public TransferView decline(Actor a, Long communityId) {
        Community c = community(communityId);
        ClubOwnershipTransfer t = pendingFor(communityId, a.id(), true);
        close(t, Status.DECLINED);
        audit.record(communityId, a.id(), t.getFromUserId(), ClubAuditService.TRANSFER_DECLINED, null);
        notifications.sendTemplated(t.getFromUserId(), NotificationType.COMMUNITY, "notif.community.transferDeclined",
                Map.of("communityId", communityId.toString()), name(a.id()), c.getName());
        return view(t);
    }

    /** Sahip teklifi geri ceker. */
    @Transactional
    public TransferView cancel(Actor a, Long communityId) {
        community(communityId);
        ClubOwnershipTransfer t = pendingFor(communityId, a.id(), false);
        close(t, Status.CANCELLED);
        audit.record(communityId, a.id(), t.getToUserId(), ClubAuditService.TRANSFER_CANCELLED, null);
        return view(t);
    }

    /** Bekleyen teklifi yalnizca iki taraf gorur. */
    @Transactional
    public TransferView pending(Actor a, Long communityId) {
        community(communityId);
        expireStale(communityId);
        ClubOwnershipTransfer t = live(communityId)
                .filter(x -> x.getFromUserId().equals(a.id()) || x.getToUserId().equals(a.id()))
                .orElseThrow(ClubOwnershipService::noTransfer);
        return view(t);
    }

    // ---- ic yardimcilar ----

    private ClubOwnershipTransfer pendingFor(Long communityId, Long userId, boolean asTarget) {
        expireStale(communityId);
        return live(communityId)
                .filter(x -> (asTarget ? x.getToUserId() : x.getFromUserId()).equals(userId))
                .orElseThrow(ClubOwnershipService::noTransfer);
    }

    /** Hala bekleyen teklif (expireStale sonrasi); satir kilitli. */
    private java.util.Optional<ClubOwnershipTransfer> live(Long communityId) {
        return transfers.lockByStatus(communityId, Status.PENDING).filter(x -> x.getStatus() == Status.PENDING);
    }

    private void expireStale(Long communityId) {
        transfers.lockByStatus(communityId, Status.PENDING).filter(x -> x.getExpiresAt().isBefore(Instant.now()))
                .ifPresent(x -> close(x, Status.EXPIRED));
    }

    private void close(ClubOwnershipTransfer t, Status s) {
        t.setStatus(s);
        t.setDecidedAt(Instant.now());
        transfers.save(t);
    }

    /** Yalnizca gercek sahip (sistem ADMIN'i dahil degil) devir baslatir. */
    private void requireOwner(Actor a, Community c) {
        boolean owner = a.id().equals(c.getOwnerId()) && members.findByCommunityIdAndUserId(c.getId(), a.id())
                .filter(CommunityMember::isActive).map(m -> m.getRole() == Role.OWNER).orElse(false);
        if (!owner) {
            throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "Bu işlem için topluluk sahibi olmalısınız.");
        }
    }

    private TransferView view(ClubOwnershipTransfer t) {
        return new TransferView(t.getId(), t.getCommunityId(), t.getFromUserId(), name(t.getFromUserId()),
                t.getToUserId(), name(t.getToUserId()), t.isKeepAsAdmin(), t.getStatus().name(), t.getCreatedAt(),
                t.getExpiresAt());
    }

    private String name(Long userId) {
        return users.findById(userId).map(User::getDisplayName).orElse("Kullanıcı");
    }

    private Community community(Long id) {
        return communities.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "COMMUNITY_NOT_FOUND", "Topluluk bulunamadı."));
    }

    private static ApiException noTransfer() {
        return new ApiException(HttpStatus.NOT_FOUND, "TRANSFER_NOT_FOUND", "Bekleyen devir teklifi bulunamadı.");
    }

    private static ApiException confirmRequired() {
        return new ApiException(HttpStatus.BAD_REQUEST, "TRANSFER_CONFIRM_REQUIRED",
                "Sahiplik devri geri alınamaz; devam etmek için açıkça onaylamalısınız.");
    }
}
