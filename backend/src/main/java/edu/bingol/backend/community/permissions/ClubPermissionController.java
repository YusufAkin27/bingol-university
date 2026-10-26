package edu.bingol.backend.community.permissions;

import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.permissions.ClubDtos.AccessRequest;
import edu.bingol.backend.community.permissions.ClubDtos.AccessView;
import edu.bingol.backend.community.permissions.ClubDtos.AuditView;
import edu.bingol.backend.community.permissions.ClubDtos.InviteCreated;
import edu.bingol.backend.community.permissions.ClubDtos.InviteRequest;
import edu.bingol.backend.community.permissions.ClubDtos.InviteView;
import edu.bingol.backend.community.permissions.ClubDtos.JoinByCodeRequest;
import edu.bingol.backend.community.permissions.ClubDtos.JoinByCodeResult;
import edu.bingol.backend.community.permissions.ClubDtos.MyAccessView;
import edu.bingol.backend.community.permissions.ClubDtos.TemplateView;
import edu.bingol.backend.community.permissions.ClubDtos.TransferDecision;
import edu.bingol.backend.community.permissions.ClubDtos.TransferRequest;
import edu.bingol.backend.community.permissions.ClubDtos.TransferView;
import jakarta.validation.Valid;
import java.time.Duration;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Kulup yetki, sahiplik devri, davet ve denetim uclari. Yalnizca HTTP eslemesi + rate limit. */
@RestController
@RequestMapping("/api")
public class ClubPermissionController {

    private final ClubRoleService roles;
    private final ClubOwnershipService ownership;
    private final ClubInviteService invites;
    private final ClubAuditService audit;
    private final RateLimiter limiter;

    public ClubPermissionController(ClubRoleService roles, ClubOwnershipService ownership, ClubInviteService invites,
                                    ClubAuditService audit, RateLimiter limiter) {
        this.roles = roles;
        this.ownership = ownership;
        this.invites = invites;
        this.audit = audit;
        this.limiter = limiter;
    }

    // ---- yetkiler ----

    @GetMapping("/communities/{id}/permissions/me")
    public MyAccessView mine(@PathVariable Long id) {
        return roles.mine(Actor.current(), id);
    }

    @GetMapping("/communities/permission-templates")
    public List<TemplateView> templates() {
        return roles.templates();
    }

    @GetMapping("/communities/{id}/members/{userId}/permissions")
    public AccessView view(@PathVariable Long id, @PathVariable Long userId) {
        return roles.view(Actor.current(), id, userId);
    }

    @PutMapping("/communities/{id}/members/{userId}/permissions")
    public AccessView set(@PathVariable Long id, @PathVariable Long userId, @RequestBody AccessRequest r) {
        Actor a = Actor.current();
        limiter.check("club-perm:user:" + a.id(), 60, Duration.ofHours(1));
        return roles.setAccess(a, id, userId, r);
    }

    @DeleteMapping("/communities/{id}/members/{userId}/permissions")
    public AccessView reset(@PathVariable Long id, @PathVariable Long userId) {
        Actor a = Actor.current();
        limiter.check("club-perm:user:" + a.id(), 60, Duration.ofHours(1));
        return roles.reset(a, id, userId);
    }

    // ---- sahiplik devri ----

    @PostMapping("/communities/{id}/ownership-transfer")
    @ResponseStatus(HttpStatus.CREATED)
    public TransferView transfer(@PathVariable Long id, @Valid @RequestBody TransferRequest r) {
        Actor a = Actor.current();
        limiter.check("club-transfer:user:" + a.id(), 5, Duration.ofHours(1));
        return ownership.request(a, id, r);
    }

    @GetMapping("/communities/{id}/ownership-transfer")
    public TransferView pendingTransfer(@PathVariable Long id) {
        return ownership.pending(Actor.current(), id);
    }

    @PostMapping("/communities/{id}/ownership-transfer/accept")
    public TransferView acceptTransfer(@PathVariable Long id, @RequestBody TransferDecision d) {
        Actor a = Actor.current();
        limiter.check("club-transfer:user:" + a.id(), 5, Duration.ofHours(1));
        return ownership.accept(a, id, d.confirmIrreversible());
    }

    @PostMapping("/communities/{id}/ownership-transfer/decline")
    public TransferView declineTransfer(@PathVariable Long id) {
        Actor a = Actor.current();
        limiter.check("club-transfer:user:" + a.id(), 5, Duration.ofHours(1));
        return ownership.decline(a, id);
    }

    @DeleteMapping("/communities/{id}/ownership-transfer")
    public TransferView cancelTransfer(@PathVariable Long id) {
        Actor a = Actor.current();
        limiter.check("club-transfer:user:" + a.id(), 5, Duration.ofHours(1));
        return ownership.cancel(a, id);
    }

    // ---- davet ----

    @PostMapping("/communities/{id}/invites")
    @ResponseStatus(HttpStatus.CREATED)
    public InviteCreated createInvite(@PathVariable Long id, @Valid @RequestBody InviteRequest r) {
        Actor a = Actor.current();
        limiter.check("club-invite:user:" + a.id(), 20, Duration.ofHours(1));
        return invites.create(a, id, r);
    }

    @GetMapping("/communities/{id}/invites")
    public List<InviteView> listInvites(@PathVariable Long id) {
        return invites.list(Actor.current(), id);
    }

    @DeleteMapping("/communities/{id}/invites/{inviteId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void revokeInvite(@PathVariable Long id, @PathVariable Long inviteId) {
        Actor a = Actor.current();
        limiter.check("club-invite:user:" + a.id(), 20, Duration.ofHours(1));
        invites.revoke(a, id, inviteId);
    }

    /** Kod tahminine karsi sik limit; gecersiz kod her zaman ayni 404. */
    @PostMapping("/communities/join-by-code")
    public JoinByCodeResult joinByCode(@Valid @RequestBody JoinByCodeRequest r) {
        Actor a = Actor.current();
        limiter.check("club-invite-join:user:" + a.id(), 10, Duration.ofHours(1));
        return invites.join(a, r.code());
    }

    // ---- denetim ----

    @GetMapping("/communities/{id}/audit")
    public CursorPage<AuditView> audit(@PathVariable Long id, @RequestParam(required = false) Long cursor,
                                       @RequestParam(defaultValue = "20") int size) {
        return audit.page(Actor.current(), id, cursor, size);
    }
}
