package edu.bingol.backend.admin.twofactor;

import edu.bingol.backend.admin.AdminReasonRequired;
import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.admin.twofactor.AdminTwoFactorDtos.DisableRequest;
import edu.bingol.backend.admin.twofactor.AdminTwoFactorDtos.Summary;
import edu.bingol.backend.admin.twofactor.AdminTwoFactorDtos.UserPage;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Yonetici 2FA uclari (/api/admin/** => ROLE_ADMIN + RBAC: okuma `users.read`, kapatma `users.write`). Yazma hiz
 * siniri, gerekce zorunlulugu ve yikici islem sayaci AdminGuardInterceptor/AdminGuardPolicy'dedir (bu yol
 * `accountOps` kapsamindadir); denetim kaydini AuditInterceptor yazar.
 */
@RestController
@RequestMapping("/api/admin")
public class AdminTwoFactorController {

    private final AdminTwoFactorService service;

    public AdminTwoFactorController(AdminTwoFactorService service) {
        this.service = service;
    }

    @GetMapping("/two-factor/summary")
    public Summary summary() {
        return service.summary();
    }

    @GetMapping("/two-factor/users")
    public UserPage users(@RequestParam(required = false) String q,
                          @RequestParam(defaultValue = "0") int page,
                          @RequestParam(defaultValue = "20") int size) {
        return service.users(q, page, size);
    }

    /** Hesap kurtarma: 2FA kapatilir, guvenilen cihazlar silinir, kullaniciya bildirim gider. Gerekce zorunlu. */
    @AdminReasonRequired
    @PostMapping("/users/{id}/two-factor/disable")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void disable(@PathVariable Long id, @RequestBody(required = false) DisableRequest body,
                        Authentication auth) {
        AuditContext.target("USER", id);
        service.disable(auth != null && auth.getPrincipal() instanceof Long l ? l : null, id);
        AuditContext.summary("iki faktorlu dogrulama yonetici tarafindan kapatildi (hesap kurtarma)");
    }
}
