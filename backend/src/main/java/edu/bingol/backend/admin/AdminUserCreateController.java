package edu.bingol.backend.admin;

import edu.bingol.backend.auth.AccountCreator;
import edu.bingol.backend.auth.AuthService;
import edu.bingol.backend.auth.LoginIdentifier;
import edu.bingol.backend.auth.PasswordPolicy;
import edu.bingol.backend.auth.token.PendingRegistrationStore.Pending;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.profile.naming.DisplayNamePolicy;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Duration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Yonetici panelinden kullanici ekleme: e-posta sahipligi KODLA kanitlanmadan dogrulanmis (USER) hesap acar.
 * Bu yuzden izin `users.verify` (yalniz FULL) ister; ADMIN_EMAILS adresleri ve +etiketli adresler reddedilir,
 * rol her zaman USER (yonetici yapmak icin mevcut rol ucu + iki kisi onayi kullanilir). Denetim kaydi otomatiktir.
 */
@RestController
@RequestMapping("/api/admin")
public class AdminUserCreateController {

    private static final Logger log = LoggerFactory.getLogger(AdminUserCreateController.class);
    static final int PER_HOUR = 60;

    public record CreateUserRequest(@NotBlank @Size(max = 254) String email,
                                    @NotBlank @Size(max = 64) String password,
                                    @Size(max = 100) String displayName,
                                    @Size(max = 5) String language) {}

    public record CreatedUser(Long id, String email, String displayName) {}

    private final AccountCreator accounts;
    private final UserRepository users;
    private final PasswordEncoder encoder;
    private final AdminProperties adminProperties;
    private final RateLimiter limiter;
    private final edu.bingol.backend.moderation.profanity.ContentGuard guard;

    public AdminUserCreateController(AccountCreator accounts, UserRepository users, PasswordEncoder encoder,
                                     AdminProperties adminProperties, RateLimiter limiter,
                                     edu.bingol.backend.moderation.profanity.ContentGuard guard) {
        this.accounts = accounts;
        this.users = users;
        this.encoder = encoder;
        this.adminProperties = adminProperties;
        this.limiter = limiter;
        this.guard = guard;
    }

    @PostMapping("/users")
    @ResponseStatus(HttpStatus.CREATED)
    public CreatedUser create(@Valid @RequestBody CreateUserRequest req) {
        limiter.check("admcreateuser:" + CurrentUser.id(), PER_HOUR, Duration.ofHours(1));
        if (req.email().indexOf('@') < 0) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "EMAIL_FULL_REQUIRED",
                    "E-posta adresinin tamamını yazın, örn. ad.soyad@ornek.com");
        }
        String email = LoginIdentifier.normalize(req.email());
        if (!AuthService.isValidEmailFormat(email)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz istek.");
        }
        if (LoginIdentifier.hasPlusAlias(email)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "EMAIL_ALIAS_NOT_ALLOWED",
                    "E-posta adresinde + etiketi kullanılamaz.");
        }
        if (adminProperties.isAdminEmail(email)) {
            throw new ApiException(HttpStatus.CONFLICT, "VERIFY_ADMIN_EMAIL_FORBIDDEN",
                    "Bu e-posta ADMIN_EMAILS listesinde; yönetici hesapları yalnızca e-posta kodu ile doğrulanır.");
        }
        PasswordPolicy.requireForUser(req.password(), PasswordPolicy.DEFAULT_MIN);
        String name = req.displayName() == null || req.displayName().isBlank()
                ? DisplayNamePolicy.temporaryFor(email)
                : DisplayNamePolicy.normalize(req.displayName(), false);
        if (req.displayName() != null && !req.displayName().isBlank()) {
            guard.assertClean(edu.bingol.backend.moderation.profanity.ContentGuard.Entity.PROFILE, "displayName",
                    null, name);
        }
        if (users.findByEmail(email).isPresent()) {
            throw new ApiException(HttpStatus.CONFLICT, "EMAIL_ALREADY_REGISTERED",
                    "Bu e-posta ile zaten kayıt olunmuş.");
        }
        String lang = Lang.of(req.language()).code();
        User u;
        try {
            u = accounts.create(email, new Pending(encoder.encode(req.password()), name, lang, null, null, null),
                    false);
        } catch (DataIntegrityViolationException e) {
            throw new ApiException(HttpStatus.CONFLICT, "EMAIL_ALREADY_REGISTERED",
                    "Bu e-posta ile zaten kayıt olunmuş.");
        }
        AuditContext.target("USER", u.getId()).summary("yönetici kullanıcı ekledi (e-posta kodu atlandı)");
        log.info("ADMIN_CREATE_USER admin={} userId={}", CurrentUser.id(), u.getId());
        return new CreatedUser(u.getId(), u.getEmail(), u.getDisplayName());
    }
}
