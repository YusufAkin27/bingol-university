package edu.bingol.backend.admin;

import edu.bingol.backend.auth.LoginIdentifier;
import edu.bingol.backend.auth.token.PendingRegistrationStore;
import edu.bingol.backend.auth.token.PendingRegistrationStore.EntryPage;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.user.User;
import java.time.Instant;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Dogrulanmamis (bekleyen) kayitlar: yalnizca Redis'te durur, DB'de kullanici satiri yoktur.
 * Yonetici tam e-postayi gorur; sifre ozeti hicbir zaman donmez.
 */
@RestController
@RequestMapping("/api/admin/pending-registrations")
public class AdminPendingRegistrationController {

    /** Dogrulama yaniti: olusan hesabin ozeti. */
    public record VerifiedUser(Long id, String email, String displayName, Instant createdAt) {}

    private final PendingRegistrationStore store;
    private final AdminAccountVerificationService verification;

    public AdminPendingRegistrationController(PendingRegistrationStore store,
                                              AdminAccountVerificationService verification) {
        this.store = store;
        this.verification = verification;
    }

    /** E-postaya gore sirali, imlec tabanli (`cursor` = onceki cevabin nextCursor'u). */
    @GetMapping
    public EntryPage list(@RequestParam(required = false) String cursor,
                          @RequestParam(defaultValue = "20") int size,
                          @RequestParam(required = false) String q) {
        return store.list(cursor, Math.min(Math.max(size, 1), 100), q);
    }

    /** Kod gerektirmeden hesabi olusturur (e-posta dogrulanmis sayilir). */
    @PostMapping("/{email}/verify")
    @ResponseStatus(HttpStatus.CREATED)
    public VerifiedUser verify(@PathVariable String email, Authentication auth) {
        User u = verification.verifyPending(email, auth.getPrincipal() instanceof Long l ? l : null);
        return new VerifiedUser(u.getId(), u.getEmail(), u.getDisplayName(), u.getCreatedAt());
    }

    /** Yeni dogrulama kodu gonderir (60 sn bekleme kurali gecerli). */
    @PostMapping("/{email}/resend-code")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void resend(@PathVariable String email) {
        verification.resendPending(email);
    }

    /** Bekleyen kaydi iptal eder (e-posta ya da okul numarasi). */
    @DeleteMapping("/{email}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void cancel(@PathVariable String email) {
        if (!store.remove(LoginIdentifier.normalize(email))) {
            throw new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Kayıt bulunamadı.");
        }
    }
}
