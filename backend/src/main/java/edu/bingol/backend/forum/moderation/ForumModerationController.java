package edu.bingol.backend.forum.moderation;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.SystemAdminAudit;
import edu.bingol.backend.admin.rbac.PermissionMatrix;
import edu.bingol.backend.forum.moderation.ForumModerationService.Action;
import edu.bingol.backend.forum.moderation.ForumModerationService.Result;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Duration;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Moderator eylemleri, KULLANICI API'si (mobil/web uygulamasindaki moderator menusu). Yetki: ROLE_ADMIN + izin
 * {@code forum.moderate} (MODERATOR/FULL profilleri); VIEWER/EDITOR/SUPPORT ve normal kullanici 403. Sahiplik bu uclarda
 * yetki SAYILMAZ (kendi konusunu moderator gibi kaldiramaz; sahibin silmesi A/B'nin DELETE uclaridir). Her eylem
 * forum_moderation_action + admin_audit kaydi uretir.
 */
@RestController
@RequestMapping("/api/forum")
public class ForumModerationController {

    public record ModerateRequest(@NotNull Action action, @Size(max = 300) String reason) {}

    private final ForumModerationService moderation;
    private final RateLimiter limiter;
    private SystemAdminAudit adminAudit;

    public ForumModerationController(ForumModerationService moderation, RateLimiter limiter) {
        this.moderation = moderation;
        this.limiter = limiter;
    }

    @Autowired(required = false)
    void setAdminAudit(SystemAdminAudit adminAudit) {
        this.adminAudit = adminAudit;
    }

    @PostMapping("/topics/{id}/moderate")
    public Result moderateTopic(@PathVariable Long id, @Valid @RequestBody ModerateRequest r) {
        Actor actor = requireModerator();
        limiter.check("fmod:" + actor.id(), 120, Duration.ofMinutes(1));
        Result res = moderation.moderateTopic(actor.id(), id, r.action(), r.reason());
        SystemAdminAudit.used(adminAudit, actor, "FORUM_TOPIC", id, "forum " + r.action() + auditReason(r.reason()));
        return res;
    }

    @PostMapping("/comments/{id}/moderate")
    public Result moderateComment(@PathVariable Long id, @Valid @RequestBody ModerateRequest r) {
        Actor actor = requireModerator();
        limiter.check("fmod:" + actor.id(), 120, Duration.ofMinutes(1));
        Result res = moderation.moderateComment(actor.id(), id, r.action(), r.reason());
        SystemAdminAudit.used(adminAudit, actor, "FORUM_COMMENT", id, "forum " + r.action() + auditReason(r.reason()));
        return res;
    }

    private static Actor requireModerator() {
        Actor a = Actor.current();
        if (!a.systemAdmin(PermissionMatrix.FORUM_MODERATE)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "FORUM_MOD_FORBIDDEN", "Bu işlem için moderatör yetkisi gerekir.");
        }
        return a;
    }

    private static String auditReason(String reason) {
        return reason == null || reason.isBlank() ? "" : " (" + reason.strip() + ")";
    }

    /** Test/diger moduller icin: gecerli istek moderator mi (rozet/menu gosterimi). */
    public static boolean canModerate() {
        return CurrentUser.hasAdminPermission(PermissionMatrix.FORUM_MODERATE);
    }
}
