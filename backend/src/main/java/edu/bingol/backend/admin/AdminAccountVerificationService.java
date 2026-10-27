package edu.bingol.backend.admin;

import edu.bingol.backend.auth.AccountCreator;
import edu.bingol.backend.auth.LoginIdentifier;
import edu.bingol.backend.auth.token.PendingRegistrationStore;
import edu.bingol.backend.auth.token.PendingRegistrationStore.Pending;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.auth.token.VerificationService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * Yonetici hesap islemleri: bekleyen (dogrulanmamis) kaydi kodsuz dogrulama, kod yeniden gonderme,
 * veritabanindaki dogrulanmamis satiri elle dogrulama, sifirlama e-postasi ve oturum kapatma.
 * Denetim kaydini AuditInterceptor yazar (tum yonetici yazma istekleri); burada ayrica log tutulur.
 */
@Service
public class AdminAccountVerificationService {

    private static final Logger log = LoggerFactory.getLogger(AdminAccountVerificationService.class);

    private final PendingRegistrationStore pending;
    private final AccountCreator accounts;
    private final VerificationService verification;
    private final UserRepository users;
    private final SessionService sessions;

    public AdminAccountVerificationService(PendingRegistrationStore pending, AccountCreator accounts,
                                           VerificationService verification, UserRepository users,
                                           SessionService sessions) {
        this.pending = pending;
        this.accounts = accounts;
        this.verification = verification;
        this.users = users;
        this.sessions = sessions;
    }

    /**
     * Bekleyen kaydi kod istemeden hesaba cevirir (AccountCreator: emailVerified=true + sozlesme onayi).
     * Zaten dogrulanmis hesap varsa ya da benzersizlik ihlali olursa bekleyen kayit silinir, 409 doner.
     */
    public User verifyPending(String rawEmail, Long actorId) {
        String email = LoginIdentifier.normalize(rawEmail);
        Pending p = pending.find(email);
        if (p == null) {
            throw notFoundPending();
        }
        User existing = users.findByEmail(email).orElse(null);
        if (existing != null && existing.isEmailVerified()) {
            pending.delete(email);
            throw alreadyRegistered();
        }
        User user;
        try {
            user = accounts.create(email, p);
        } catch (DataIntegrityViolationException e) {
            pending.delete(email);
            throw alreadyRegistered();
        }
        pending.delete(email);
        verification.clearVerify(email);
        log.info("ADMIN_VERIFY pending admin={} email={} userId={}", actorId, email, user.getId());
        return user;
    }

    /** Bekleyen kayda yeni kod gonderir; 60 sn bekleme kurali aynen gecerlidir (429 RESEND_COOLDOWN). */
    public void resendPending(String rawEmail) {
        String email = LoginIdentifier.normalize(rawEmail);
        Pending p = pending.find(email);
        if (p == null) {
            throw notFoundPending();
        }
        verification.issue(email, Lang.of(p.language()));
        pending.markResend(email);
    }

    /** DB'deki dogrulanmamis satiri dogrular; idempotent (zaten dogrulanmissa degisiklik yok). */
    public User verifyUser(Long id, Long actorId) {
        User u = find(id);
        if (!u.isEmailVerified()) {
            u.setEmailVerified(true);
            u = users.save(u);
            verification.clearVerify(u.getEmail());
            log.info("ADMIN_VERIFY user admin={} userId={}", actorId, id);
        }
        return u;
    }

    /** Kullaniciya sifre sifirlama kodu e-postasi gonderir (dogrulanmamis hesap icin once verify-email gerekir). */
    public void sendReset(Long id) {
        User u = find(id);
        if (!u.isEmailVerified()) {
            throw new ApiException(HttpStatus.CONFLICT, "USER_NOT_VERIFIED",
                    "Kullanıcı e-postası doğrulanmamış; önce doğrulayın.");
        }
        verification.issueReset(u.getEmail(), Lang.of(u.getLanguage()));
    }

    /** Kullanicinin tum oturumlarini (refresh + eski access token'lar) kapatir. */
    public void revokeSessions(Long id) {
        sessions.revokeAll(find(id).getId());
    }

    private User find(Long id) {
        return users.findById(id).filter(u -> u.getStatus() != UserStatus.DELETED)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı."));
    }

    private static ApiException notFoundPending() {
        return new ApiException(HttpStatus.NOT_FOUND, "PENDING_REGISTRATION_NOT_FOUND",
                "Bekleyen kayıt bulunamadı.");
    }

    private static ApiException alreadyRegistered() {
        return new ApiException(HttpStatus.CONFLICT, "EMAIL_ALREADY_REGISTERED", "Bu e-posta ile zaten kayıt olunmuş.");
    }
}
