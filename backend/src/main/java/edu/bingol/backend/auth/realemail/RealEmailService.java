package edu.bingol.backend.auth.realemail;

import edu.bingol.backend.auth.AuthService;
import edu.bingol.backend.auth.LoginIdentifier;
import edu.bingol.backend.auth.oauth.AuthIdentity;
import edu.bingol.backend.auth.oauth.AuthIdentityRepository;
import edu.bingol.backend.auth.oauth.OAuthProvider;
import edu.bingol.backend.auth.oauth.OAuthService;
import edu.bingol.backend.auth.realemail.RealEmailDtos.StartResponse;
import edu.bingol.backend.auth.realemail.RealEmailDtos.VerifyResponse;
import edu.bingol.backend.auth.token.PendingRegistrationStore;
import edu.bingol.backend.auth.token.VerificationService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.ShortTx;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.observability.LogMasking;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.Locale;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;

/**
 * Gercek (aktif) e-posta dogrulamasi. Apple "E-postami gizle" ile acilan hesabin e-postasi
 * {@code xxxx@privaterelay.appleid.com} role adresidir; sifre sifirlama, 2FA ve bildirim postalari ulasmaz. Kullanici
 * gercek adresini yazar, adrese 6 haneli kod gider, kod girilince hesabin TEK e-postasi o adres olur
 * ({@code emailVerified=true}, role bayragi ve kapi kapanir). Role adresine HICBIR ZAMAN posta gonderilmez.
 *
 * <p>Ayni akis role olmayan hesapta "e-posta degistir" olarak da kullanilabilir ama zorunlu degildir; orada hesap
 * ele gecirme riskine karsi yeniden dogrulama istenir (parola ya da bagli saglayici token'i). Yonetici hesaplari
 * (ADMIN rolu / ADMIN_EMAILS) bu uctan adres DEGISTIREMEZ: yonetici ayricaligi e-posta adresine baglidir.
 *
 * <p>Kod, YENI adrese baglidir (anahtar {@code ce:<kullanici>:<adres>}); bekleyen adres Redis'te {@code rem:<kullanici>}
 * (10 dk). Adres baska hesapta kayitliysa kod yine gonderilir (enumerasyon sizmaz; posta kutusu sahibi kodu ancak o
 * zaman gorur) ve cakisma YALNIZ kod dogru girildikten sonra 409 {@code EMAIL_UNAVAILABLE} olarak bildirilir.
 */
@Service
public class RealEmailService {

    private static final Logger log = LoggerFactory.getLogger(RealEmailService.class);
    static final Duration PENDING_TTL = Duration.ofMinutes(10);
    private static final String PENDING_PREFIX = "rem:";

    private final UserRepository users;
    private final AuthIdentityRepository identities;
    private final VerificationService verification;
    private final PendingRegistrationStore pendingRegistrations;
    private final StringRedisTemplate redis;
    private final AdminProperties admin;
    private ShortTx tx = ShortTx.direct();

    /** Parolasiz role olmayan hesapta yeniden dogrulama icin (istege bagli: OAuth modulu yoksa yok). */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private OAuthService oauth;

    /** Parolali hesapta yeniden dogrulama: AuthService'in parola denetimi OAuthService yoksa da calissin. */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private org.springframework.security.crypto.password.PasswordEncoder encoder;

    public RealEmailService(UserRepository users, AuthIdentityRepository identities, VerificationService verification,
                            PendingRegistrationStore pendingRegistrations, StringRedisTemplate redis,
                            AdminProperties admin) {
        this.users = users;
        this.identities = identities;
        this.verification = verification;
        this.pendingRegistrations = pendingRegistrations;
        this.redis = redis;
        this.admin = admin;
    }

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setTxManager(PlatformTransactionManager tm) {
        this.tx = ShortTx.of(tm);
    }

    /** Adrese kod gonderir. Hata: 400 VALIDATION_ERROR / EMAIL_ALIAS_NOT_ALLOWED / EMAIL_RELAY_NOT_ALLOWED / EMAIL_UNCHANGED. */
    public StartResponse start(Long uid, String rawEmail, String password, OAuthProvider reauthProvider,
                               String reauthToken, String reauthNonce) {
        User user = loadActive(uid);
        requireChangeAllowed(user);
        String email = normalize(rawEmail);
        if (RelayEmails.isRelay(email)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "EMAIL_RELAY_NOT_ALLOWED",
                    "Gizli (geçici) bir adres kullanılamaz; aktif olarak kullandığınız gerçek e-posta adresinizi yazın.");
        }
        if (email.equals(user.getEmail()) && user.isEmailVerified() && !user.isEmailRelay()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "EMAIL_UNCHANGED", "Bu adres zaten hesabınızın e-posta adresi.");
        }
        if (!user.isEmailRelay()) {
            reauthenticate(user, password, reauthProvider, reauthToken, reauthNonce);
        }
        verification.requireMailQuota();
        String key = PENDING_PREFIX + uid;
        String previous = redis.opsForValue().get(key);
        verification.issueEmailChange(subject(uid, email), email, Lang.of(user.getLanguage()));
        if (previous != null && !previous.equals(email)) {
            verification.clearEmailChange(subject(uid, previous)); // eski adres icin kod artik gecersiz
        }
        redis.opsForValue().set(key, email, PENDING_TTL);
        log.info("Gercek e-posta kodu gonderildi (user {}, adres {})", uid, LogMasking.email(email));
        return new StartResponse(true, LogMasking.email(email), (int) PENDING_TTL.toSeconds(), 180);
    }

    /** Kodu dogrular; dogruysa hesabin tek e-postasi bekleyen adres olur. `scope`: istemci anahtari (IP). */
    public VerifyResponse verify(Long uid, String code, String scope) {
        loadActive(uid);
        String key = PENDING_PREFIX + uid;
        String email = redis.opsForValue().get(key);
        if (email == null) {
            throw invalidCode();
        }
        if (!verification.verifyEmailChange(subject(uid, email), code, scope)) {
            throw invalidCode();
        }
        VerifyResponse out = tx.call(() -> apply(uid, email));
        redis.delete(key);
        verification.clearEmailChange(subject(uid, email));
        verification.clearVerify(email); // ayni adres icin acik kayit dogrulama kodu varsa o da bitsin
        try {
            pendingRegistrations.delete(email); // adres artik bir hesaba ait: bekleyen kayit anlamsiz
        } catch (RuntimeException e) {
            log.debug("Bekleyen kayit temizlenemedi: {}", e.toString());
        }
        return out;
    }

    private VerifyResponse apply(Long uid, String email) {
        User user = loadActive(uid);
        requireChangeAllowed(user);
        if (admin.isAdminEmail(email)) {
            throw unavailable(); // yonetici ayricaligi adrese baglidir: baska hesap bu adrese tasinamaz
        }
        User other = users.findByEmail(email).orElse(null);
        if (other != null && !other.getId().equals(uid)) {
            throw unavailable();
        }
        boolean wasRelay = user.isEmailRelay();
        user.setEmail(email);
        user.setEmailVerified(true);
        user.setVerificationDeferred(false);
        user.setEmailRelay(false);
        user.setRealEmailRequired(false);
        user.setRealEmailVerifiedAt(Instant.now());
        try {
            users.saveAndFlush(user);
        } catch (DataIntegrityViolationException e) {
            throw unavailable();
        }
        if (wasRelay) {
            // KVKK: eski role adresi saklanmaz; yalniz saglayici `sub` kalir
            for (AuthIdentity i : identities.findByUserIdOrderByCreatedAtAsc(uid)) {
                if (i.isEmailIsPrivate()) {
                    i.setEmail(null);
                    i.setEmailIsPrivate(false);
                    identities.save(i);
                }
            }
        }
        log.info("Hesap e-postasi guncellendi (user {}, adres {}, onceki role: {})", uid, LogMasking.email(email), wasRelay);
        return new VerifyResponse(email, true, false, false);
    }

    private void reauthenticate(User user, String password, OAuthProvider provider, String token, String nonce) {
        if (oauth != null) {
            oauth.reauthenticate(user, password, provider, token, nonce);
            return;
        }
        if (!user.hasPassword() || encoder == null || password == null || password.isBlank()
                || !encoder.matches(password, user.getPasswordHash())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "WRONG_PASSWORD", "Şifre hatalı.");
        }
    }

    private void requireChangeAllowed(User user) {
        if (user.getRole() == Role.ADMIN || admin.isAdminEmail(user.getEmail())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "EMAIL_CHANGE_NOT_ALLOWED",
                    "Bu hesabın e-posta adresi buradan değiştirilemez.");
        }
    }

    private User loadActive(Long uid) {
        return users.findById(uid).filter(User::isActive)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "Oturum geçersiz."));
    }

    /** Kirpar, kucuk harfe cevirir, tam adres ister (okul numarasi kisayolu YOK), bicim + `+etiket` denetimi. */
    static String normalize(String raw) {
        String email = raw == null ? "" : raw.trim().toLowerCase(Locale.ROOT);
        if (email.indexOf('@') < 0 || !AuthService.isValidEmailFormat(email)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz istek.");
        }
        if (LoginIdentifier.hasPlusAlias(email)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "EMAIL_ALIAS_NOT_ALLOWED",
                    "E-posta adresinde + etiketi kullanılamaz.");
        }
        return email;
    }

    private static String subject(Long uid, String email) {
        return uid + ":" + email;
    }

    private static ApiException invalidCode() {
        return new ApiException(HttpStatus.BAD_REQUEST, "INVALID_CODE", "Kod geçersiz veya süresi dolmuş.");
    }

    private static ApiException unavailable() {
        return new ApiException(HttpStatus.CONFLICT, "EMAIL_UNAVAILABLE",
                "Bu e-posta adresi kullanılamıyor. Başka bir adres deneyin ya da bu adresle açılmış hesaba giriş yapın.");
    }
}
