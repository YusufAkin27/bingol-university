package edu.bingol.backend.community.permissions;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.CommunityMemberRepository;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.community.permissions.ClubDtos.InviteCreated;
import edu.bingol.backend.community.permissions.ClubDtos.InviteRequest;
import edu.bingol.backend.community.permissions.ClubDtos.InviteView;
import edu.bingol.backend.community.permissions.ClubDtos.JoinByCodeResult;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Davet kodlari: suresi ve kullanim sayisi sinirli, iptal edilebilir; kod yalnizca olusturulurken gosterilir. */
@Service
public class ClubInviteService {

    static final int MAX_ACTIVE = 20;
    static final int DEFAULT_HOURS = 168;
    private static final String ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    private static final int CODE_LENGTH = 10;
    private static final SecureRandom RANDOM = new SecureRandom();

    private final ClubInviteRepository invites;
    private final CommunityRepository communities;
    private final CommunityMemberRepository members;
    private final ClubPermissions permissions;
    private final ClubMemberGrantRepository grants;
    private final ClubAuditService audit;

    public ClubInviteService(ClubInviteRepository invites, CommunityRepository communities,
                             CommunityMemberRepository members, ClubPermissions permissions,
                             ClubMemberGrantRepository grants, ClubAuditService audit) {
        this.invites = invites;
        this.communities = communities;
        this.members = members;
        this.permissions = permissions;
        this.grants = grants;
        this.audit = audit;
    }

    @Transactional
    public InviteCreated create(Actor a, Long communityId, InviteRequest r) {
        Community c = community(communityId);
        permissions.require(a, communityId, ClubPermission.INVITE);
        if (c.getStatus() != Community.Status.ACTIVE) {
            throw new ApiException(HttpStatus.CONFLICT, "COMMUNITY_NOT_ACTIVE", "Topluluk henüz yayında değil.");
        }
        Instant now = Instant.now();
        if (invites.countActive(communityId, now) >= MAX_ACTIVE) {
            throw new ApiException(HttpStatus.CONFLICT, "INVITE_LIMIT",
                    "En fazla " + MAX_ACTIVE + " etkin davet kodu olabilir.", String.valueOf(MAX_ACTIVE));
        }
        String code = newCode();
        ClubInvite i = new ClubInvite();
        i.setCommunityId(communityId);
        i.setCodeHash(Hashing.sha256(code));
        i.setCodeHint(code.substring(code.length() - 3));
        i.setCreatedBy(a.id());
        i.setMaxUses(r.maxUses());
        i.setExpiresAt(now.plus(Duration.ofHours(r.validHours() == null ? DEFAULT_HOURS : r.validHours())));
        invites.save(i);
        audit.record(communityId, a.id(), null, ClubAuditService.INVITE_CREATED,
                "invite=" + i.getId() + " maxUses=" + r.maxUses() + " expires=" + i.getExpiresAt());
        return new InviteCreated(i.getId(), code, i.getMaxUses(), i.getExpiresAt());
    }

    @Transactional(readOnly = true)
    public List<InviteView> list(Actor a, Long communityId) {
        community(communityId);
        permissions.require(a, communityId, ClubPermission.INVITE);
        Instant now = Instant.now();
        return invites.findByCommunityIdOrderByIdDesc(communityId).stream()
                .map(i -> new InviteView(i.getId(), "..." + i.getCodeHint(), i.getCreatedBy(), i.getMaxUses(),
                        i.getUsedCount(), i.getExpiresAt(), i.isRevoked(), state(i, now)))
                .toList();
    }

    @Transactional
    public void revoke(Actor a, Long communityId, Long inviteId) {
        community(communityId);
        permissions.require(a, communityId, ClubPermission.INVITE);
        ClubInvite i = invites.findByIdAndCommunityId(inviteId, communityId).orElseThrow(
                () -> new ApiException(HttpStatus.NOT_FOUND, "INVITE_NOT_FOUND", "Davet bulunamadı."));
        if (!i.isRevoked()) {
            i.setRevoked(true);
            invites.save(i);
            audit.record(communityId, a.id(), null, ClubAuditService.INVITE_REVOKED, "invite=" + i.getId());
        }
    }

    /** Kodla katilim: onay politikasini atlar (davet = onay), yasakliyi atlamaz. Gecersiz kod her durumda ayni 404. */
    @Transactional
    public JoinByCodeResult join(Actor a, String rawCode) {
        String code = rawCode.trim().replace("-", "").toUpperCase(Locale.ROOT);
        ClubInvite i = invites.findByCodeHash(Hashing.sha256(code)).orElseThrow(ClubInviteService::invalid);
        Community c = communities.findById(i.getCommunityId()).orElseThrow(ClubInviteService::invalid);
        if (c.getStatus() != Community.Status.ACTIVE) {
            throw invalid();
        }
        CommunityMember existing = members.findByCommunityIdAndUserId(c.getId(), a.id()).orElse(null);
        if (existing != null) {
            switch (existing.getStatus()) {
                case ACTIVE -> throw new ApiException(HttpStatus.CONFLICT, "ALREADY_MEMBER", "Zaten üyesiniz.");
                case BANNED -> throw new ApiException(HttpStatus.FORBIDDEN, "BANNED", "Bu topluluktan uzaklaştırıldınız.");
                case PENDING -> { }
            }
        }
        // Atomik tuketim: es zamanli kullanimlarda sinir asilmaz.
        if (invites.consume(i.getId(), Instant.now()) == 0) {
            throw invalid();
        }
        if (existing != null) {
            existing.setStatus(CommunityMember.Status.ACTIVE);
            existing.setJoinedAt(Instant.now());
            members.save(existing);
        } else {
            members.save(new CommunityMember(c.getId(), a.id(), Role.MEMBER, CommunityMember.Status.ACTIVE));
        }
        grants.deleteMember(c.getId(), a.id());
        audit.record(c.getId(), a.id(), a.id(), ClubAuditService.INVITE_USED, "invite=" + i.getId());
        return new JoinByCodeResult(c.getId(), CommunityMember.Status.ACTIVE.name());
    }

    // ---- ic yardimcilar ----

    static String state(ClubInvite i, Instant now) {
        if (i.isRevoked()) {
            return "REVOKED";
        }
        if (!i.getExpiresAt().isAfter(now)) {
            return "EXPIRED";
        }
        if (i.getMaxUses() != null && i.getUsedCount() >= i.getMaxUses()) {
            return "USED_UP";
        }
        return "ACTIVE";
    }

    static String newCode() {
        StringBuilder sb = new StringBuilder(CODE_LENGTH);
        for (int n = 0; n < CODE_LENGTH; n++) {
            sb.append(ALPHABET.charAt(RANDOM.nextInt(ALPHABET.length())));
        }
        return sb.toString();
    }

    private Community community(Long id) {
        return communities.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "COMMUNITY_NOT_FOUND", "Topluluk bulunamadı."));
    }

    private static ApiException invalid() {
        return new ApiException(HttpStatus.NOT_FOUND, "INVITE_INVALID", "Davet kodu geçersiz, süresi dolmuş veya kullanım sınırına ulaşmış.");
    }
}
