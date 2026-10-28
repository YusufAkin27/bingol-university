package edu.bingol.backend.admin.rbac;

import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.admin.rbac.RbacDtos.AdminRow;
import edu.bingol.backend.admin.rbac.RbacDtos.ChangeView;
import edu.bingol.backend.admin.rbac.RbacDtos.DecisionRequest;
import edu.bingol.backend.admin.rbac.RbacDtos.Matrix;
import edu.bingol.backend.admin.rbac.RbacDtos.Me;
import edu.bingol.backend.admin.rbac.RbacDtos.ProfileRequest;
import edu.bingol.backend.admin.rbac.RbacDtos.ProposeRequest;
import edu.bingol.backend.common.CurrentUser;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Yonetici rol/izin matrisi uclari (P16). `me` ve `matrix` her yonetici icin; digerleri yalniz `rbac.manage` (FULL).
 * Profil yazmalari kimlik gerektirir (Basic auth 401): iki kisi onayi gercek hesaplar arasindadir.
 */
@RestController
@RequestMapping("/api/admin/rbac")
public class RbacController {

    private final RbacService service;

    public RbacController(RbacService service) {
        this.service = service;
    }

    @GetMapping("/me")
    public Me me() {
        return service.me();
    }

    @GetMapping("/matrix")
    public Matrix matrix() {
        return service.matrix();
    }

    @GetMapping("/admins")
    public List<AdminRow> admins() {
        return service.admins();
    }

    @GetMapping("/changes")
    public List<ChangeView> changes(@RequestParam(required = false) AdminProfileChange.Status status) {
        return service.changes(status);
    }

    /** FULL'i ilgilendirmeyen profil atamasi (dogrudan). */
    @PutMapping("/users/{id}/profile")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void setProfile(@PathVariable Long id, @Valid @RequestBody ProfileRequest r) {
        AuditContext.target("USER", id).reason(r.reason());
        AdminProfile before = service.setProfile(CurrentUser.id(), id, r.profile());
        AuditContext.target("USER", id).summary("yonetici profili: " + before + " -> " + r.profile());
    }

    /** FULL'i dusurme / FULL yapma onerisi (ikinci FULL yonetici onaylar). */
    @PostMapping("/changes")
    @ResponseStatus(HttpStatus.CREATED)
    public ChangeView propose(@Valid @RequestBody ProposeRequest r) {
        AuditContext.target("USER", r.userId()).reason(r.reason());
        ChangeView v = service.propose(CurrentUser.id(), r.userId(), r.profile(), r.reason());
        AuditContext.target("USER", r.userId())
                .summary("profil degisikligi onerildi: " + v.fromProfile() + " -> " + v.toProfile() + " (#" + v.id() + ")");
        return v;
    }

    @PostMapping("/changes/{id}/approve")
    public ChangeView approve(@PathVariable Long id, @RequestBody(required = false) DecisionRequest r) {
        AuditContext.target("RBAC_CHANGE", id);
        ChangeView v = service.approve(CurrentUser.id(), id, r == null ? null : r.note());
        AuditContext.target("USER", v.targetUserId())
                .summary("profil degisikligi onaylandi: " + v.fromProfile() + " -> " + v.toProfile() + " (#" + v.id() + ")");
        return v;
    }

    @PostMapping("/changes/{id}/reject")
    public ChangeView reject(@PathVariable Long id, @RequestBody(required = false) DecisionRequest r) {
        AuditContext.target("RBAC_CHANGE", id);
        ChangeView v = service.reject(CurrentUser.id(), id, r == null ? null : r.note());
        AuditContext.target("USER", v.targetUserId()).summary("profil degisikligi reddedildi (#" + v.id() + ")");
        return v;
    }
}
