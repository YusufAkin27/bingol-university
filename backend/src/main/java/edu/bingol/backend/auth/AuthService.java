package edu.bingol.backend.auth;

import edu.bingol.backend.accessban.AccessGuard;
import edu.bingol.backend.accessban.ClientContext;
import edu.bingol.backend.accessban.DeviceLogService;
import edu.bingol.backend.auth.dto.TokenResponse;
import edu.bingol.backend.auth.dto.UserView;
import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.auth.token.PendingRegistrationStore;
import edu.bingol.backend.auth.token.PendingRegistrationStore.Pending;
import edu.bingol.backend.auth.token.RefreshTokenService;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.auth.token.VerificationService;
import edu.bingol.backend.catalog.CatalogService;
import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.moderation.profanity.ContentGuard.Entity;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.UserStatus;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);

    /** bingol.edu.tr ve alt alan adlari (ogr.bingol.edu.tr gibi). */
    private static final Pattern UNIVERSITY_EMAIL =
            Pattern.compile("^[a-z0-9._%+\\-]+@([a-z0-9\\-]+\\.)*bingol\\.edu\\.tr$");

    private final UserRepository users;
    private final PasswordEncoder encoder;
    private final JwtService jwt;
    private final RefreshTokenService refresh;
    private final VerificationService verification;
    private final AdminProperties admin;
    private final AccountCreator accounts;
    private final PendingRegistrationStore pending;
    private final SessionService sessions;
    private final CatalogService catalog;
    /** Kullanici yokken de encoder.matches calissin diye: giris suresi hesap varligini sizdirmasin. */
    private final String dummyHash;
    /** Erisim engeli (IP/cihaz/kullanici) ve cihaz gunlugu; testlerde/eski cagrilarda null olabilir. */
    private AccessGuard guard;
    private DeviceLogService deviceLog;
    /** Guvenlik e-postasi (istege bagli: mail'siz kurulan testler icin). */
    @Autowired(required = false)
    private edu.bingol.backend.mail.MailService mail;

    /** Herkese acik gorunen ad denetimi (istege bagli: guard'siz kurulan testler icin). */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private ContentGuard contentGuard;

    public AuthService(UserRepository users, PasswordEncoder encoder, JwtService jwt,
                       RefreshTokenService refresh, VerificationService verification, AdminProperties admin,
                       AccountCreator accounts, PendingRegistrationStore pending, SessionService sessions,
                       CatalogService catalog) {
        this.catalog = catalog;
        this.admin = admin;
        this.accounts = accounts;
        this.users = users;
        this.encoder = encoder;
        this.jwt = jwt;
        this.refresh = refresh;
        this.verification = verification;
        this.pending = pending;
        this.sessions = sessions;
        this.dummyHash = encoder.encode("dummy-password-for-timing");
    }

    @Autowired(required = false)
    void setAccessControls(AccessGuard guard, DeviceLogService deviceLog) {
        this.guard = guard;
        this.deviceLog = deviceLog;
    }

    private void requireNotBlocked(ClientContext ctx, Long userId, String path) {
        if (guard != null && ctx != null) {
            guard.require(ctx, userId, path);
        }
    }

    private void logDevice(Long userId, ClientContext ctx, String event) {
        if (deviceLog != null && ctx != null) {
            deviceLog.record(userId, ctx, event);
        }
    }

    /** E-posta ya da okul numarasi -> tam e-posta (bkz. LoginIdentifier); gecersizse 400 VALIDATION_ERROR. */
    public static String normalizeEmail(String email) {
        return LoginIdentifier.normalize(email);
    }

    /**
     * Kayit verisi dogrulanana kadar yalnizca Redis'te tutulur; veritabaninda hesap olusmaz. Boylece baskasinin
     * e-postasiyla onceden kayit acip sifreyi belirleyen biri, sahibi dogruladiginda hesabi ele gecirmez.
     */
    public void register(String rawEmail, String password, String displayName, Lang lang) {
        register(rawEmail, password, displayName, lang, null, null, null);
    }

    /** faculty/department/grade opsiyoneldir; verilenler katalogla dogrulanir (bos metin = verilmedi). */
    public void register(String rawEmail, String password, String displayName, Lang lang, String faculty,
                         String department, String grade) {
        String email = normalizeEmail(rawEmail);
        if (!UNIVERSITY_EMAIL.matcher(email).matches()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "EMAIL_DOMAIN_NOT_ALLOWED",
                    "Yalnızca bingol.edu.tr uzantılı e-posta ile kayıt olunabilir.");
        }
        String fa = blankToNull(faculty);
        String de = blankToNull(department);
        String gr = blankToNull(grade);
        catalog.requireValid(fa, de, gr);
        verification.requireMailQuota();
        User user = users.findByEmail(email).orElse(null);
        if (user != null && user.isEmailVerified()) {
            throw new ApiException(HttpStatus.CONFLICT, "EMAIL_ALREADY_REGISTERED",
                    "Bu e-posta ile zaten kayıt olunmuş.");
        }
        Pending waiting = pending.find(email);
        if (waiting != null) {
            // Bekleyen kayit varken sifre/ad ezilmez (baskasinin e-postasiyla kaydi ele gecirme penceresi);
            // yalnizca yeni kod gider (bekleme suresi doluysa burada 429).
            verification.issue(email, Lang.of(waiting.language()));
            pending.markResend(email);
            return;
        }
        // Kod once gider (bekleme suresi doluysa burada 429); bekleme sirasinda bekleyen kayit ezilmez.
        verification.issue(email, lang);
        ContentGuard.clean(contentGuard, Entity.PROFILE, "displayName", null, displayName);
        pending.save(email, new Pending(encoder.encode(password), displayName.trim(), lang.code(), fa, de, gr));
    }

    public void resendCode(String rawEmail) {
        String email = normalizeEmail(rawEmail);
        verification.requireMailQuota();
        Pending p = pending.find(email);
        if (p == null) {
            return;
        }
        try {
            verification.issue(email, Lang.of(p.language()));
            pending.markResend(email);
        } catch (ApiException e) {
            // Bekleme suresi cevabi hesabin varligini sizdirirdi: ayni genel cevap doner.
            log.debug("resend-code atlandi: {}", e.code());
        } catch (RuntimeException e) {
            log.warn("Dogrulama e-postasi gonderilemedi: {}", e.getMessage());
        }
        // Hesap yoksa/dogrulanmissa da ayni cevap doner (e-posta taramasini engellemek icin).
    }

    /** Hesap var ve dogrulanmissa sifirlama kodu gonderir; her durumda ayni cevap (enumerasyon yok). */
    public void forgotPassword(String rawEmail) {
        String email = normalizeEmail(rawEmail);
        verification.requireMailQuota();
        users.findByEmail(email).filter(User::isEmailVerified).filter(User::isActive).ifPresent(u -> {
            try {
                verification.issueReset(email, Lang.of(u.getLanguage()));
            } catch (ApiException e) {
                // Bekleme suresi cevabi hesabin varligini sizdirirdi: sessizce yutulur.
                if (!"RESEND_COOLDOWN".equals(e.code())) {
                    throw e;
                }
            }
        });
    }

    /** Sifirlama kodunu dogrular; dogruysa yeni sifre adimi icin tek kullanimlik anahtar verir. */
    public String verifyResetCode(String rawEmail, String code) {
        String email = normalizeEmail(rawEmail);
        users.findByEmail(email).filter(User::isEmailVerified).filter(User::isActive)
                .orElseThrow(() -> new ApiException(HttpStatus.BAD_REQUEST, "INVALID_CODE", "Kod geçersiz veya süresi dolmuş."));
        if (!verification.verifyReset(email, code.trim())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_CODE", "Kod geçersiz veya süresi dolmuş.");
        }
        return verification.issueResetToken(email);
    }

    public void resetPassword(String rawEmail, String resetToken, String newPassword) {
        String email = normalizeEmail(rawEmail);
        User user = users.findByEmail(email).filter(User::isEmailVerified).filter(User::isActive)
                .orElseThrow(() -> new ApiException(HttpStatus.BAD_REQUEST, "INVALID_CODE", "Kod geçersiz veya süresi dolmuş."));
        if (!verification.consumeResetToken(email, resetToken)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_CODE", "Kod geçersiz veya süresi dolmuş.");
        }
        user.setPasswordHash(encoder.encode(newPassword));
        users.save(user);
        // Sifre degisince calinmis olabilecek tum oturumlar (refresh + access) kapanir.
        sessions.revokeAll(user.getId());
    }

    /**
     * Oturum acik kullanicinin sifre degisimi. Tum oturumlar (refresh + access, WebSocket dahil) kapanir; isteyen
     * cihaz ayni istemci turunde yeni token cifti alir (mevcut mekanizma tek cihazi koruyamaz: `pwchg:` isareti
     * kullanicinin TUM eski token'larini reddeder). Sifre/ozet log'a yazilmaz.
     */
    public TokenResponse changePassword(Long userId, String currentPassword, String newPassword, String client) {
        User user = users.findById(userId).filter(User::isActive)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "Oturum geçersiz."));
        if (!encoder.matches(currentPassword, user.getPasswordHash())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "WRONG_PASSWORD", "Şifre hatalı.");
        }
        if (currentPassword.equals(newPassword)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "PASSWORD_UNCHANGED",
                    "Yeni şifre mevcut şifreyle aynı olamaz.");
        }
        user.setPasswordHash(encoder.encode(newPassword));
        users.save(user);
        sessions.revokeAll(userId);
        // Iptal isareti `iatms <= isaret` token'lari reddeder: yeni token'in iatms'i kesin buyuk olsun.
        try {
            Thread.sleep(1);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        notifyPasswordChanged(user);
        return tokens(user, client);
    }

    private void notifyPasswordChanged(User user) {
        if (mail == null) {
            return;
        }
        try {
            mail.sendPasswordChanged(user.getEmail(),
                    java.time.format.DateTimeFormatter.ofPattern("dd.MM.yyyy HH:mm")
                            .format(java.time.ZonedDateTime.now(java.time.ZoneId.of("Europe/Istanbul"))),
                    Lang.of(user.getLanguage()));
        } catch (RuntimeException e) {
            log.warn("Sifre degisti e-postasi kuyruga yazilamadi (user {}): {}", user.getId(), e.toString());
        }
    }

    public TokenResponse verifyEmail(String rawEmail, String code) {
        return verifyEmail(rawEmail, code, null);
    }

    /** Yeni hesap acilisi mevcut oturumu kapatmaz; `client` yalnizca token'lari etiketler. */
    public TokenResponse verifyEmail(String rawEmail, String code, String client) {
        return verifyEmail(rawEmail, code, client, null);
    }

    public TokenResponse verifyEmail(String rawEmail, String code, String client, ClientContext ctx) {
        String email = normalizeEmail(rawEmail);
        Pending p = pending.find(email);
        User existing = users.findByEmail(email).orElse(null);
        if (p == null || (existing != null && existing.isEmailVerified())) {
            throw invalidCode();
        }
        if (!verification.verify(email, code.trim())) {
            throw invalidCode();
        }
        User user;
        try {
            user = accounts.create(email, p);
        } catch (DataIntegrityViolationException e) {
            // Es zamanli kayit/benzersizlik ihlali: 500 yerine anlamli cevap; bekleyen kayit artik gereksiz.
            pending.delete(email);
            throw new ApiException(HttpStatus.CONFLICT, "EMAIL_ALREADY_REGISTERED",
                    "Bu e-posta ile zaten kayıt olunmuş.");
        }
        pending.delete(email);
        logDevice(user.getId(), ctx, "REGISTER");
        return tokens(user, client);
    }

    public TokenResponse login(String rawEmail, String password) {
        return login(rawEmail, password, null);
    }

    /**
     * `client` = mobile ise tek cihaz kurali: kullanicinin onceki MOBIL oturumlari kapanir (web oturumlarina
     * dokunulmaz); web girisi hicbir oturumu kapatmaz. Iptal, yeni token'lar uretilmeden ONCE yapilir.
     */
    public TokenResponse login(String rawEmail, String password, String client) {
        return login(rawEmail, password, client, null);
    }

    public TokenResponse login(String rawEmail, String password, String client, ClientContext ctx) {
        String email = normalizeEmail(rawEmail);
        User user = users.findByEmail(email).orElse(null);
        // Hesap yoksa bekleyen (dogrulanmamis) kaydin ozetiyle karsilastirilir; ikisi de yoksa sahte ozet (sure esit).
        Pending waiting = user == null ? pending.find(email) : null;
        String hash = user != null ? user.getPasswordHash() : (waiting != null ? waiting.passwordHash() : dummyHash);
        boolean passwordOk = encoder.matches(password, hash);
        if (!passwordOk || (user == null && waiting == null)) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS", "E-posta veya şifre hatalı.");
        }
        if (user == null) {
            // Bekleyen kayit + dogru sifre: varlik yalnizca sifreyi bilene soylenir (enumerasyon yok).
            throw new ApiException(HttpStatus.FORBIDDEN, "EMAIL_NOT_VERIFIED",
                    "Giriş için önce e-posta adresinizi doğrulayın.");
        }
        if (!user.isEmailVerified()) {
            throw new ApiException(HttpStatus.FORBIDDEN, "EMAIL_NOT_VERIFIED",
                    "Giriş için önce e-posta adresinizi doğrulayın.");
        }
        requireActive(user);
        // Sifre dogru olduktan sonra kontrol: yanlis sifreyle engel durumu sizdirilmaz
        requireNotBlocked(ctx, user.getId(), "/api/auth/login");
        if (promoteIfAdmin(user)) {
            users.save(user);
        }
        logDevice(user.getId(), ctx, "LOGIN");
        String c = RefreshTokenService.normalizeClient(client);
        if (RefreshTokenService.MOBILE.equals(c)) {
            sessions.revokeClient(user.getId(), c, true);
        }
        return tokens(user, c);
    }

    public TokenResponse refresh(String refreshToken) {
        return refresh(refreshToken, null);
    }

    public TokenResponse refresh(String refreshToken, ClientContext ctx) {
        RefreshTokenService.Session s = refresh.consumeSession(refreshToken);
        if (s == null && refresh.wasRevoked(refreshToken)) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "SESSION_REPLACED",
                    "Hesabınıza başka bir cihazdan giriş yapıldı.");
        }
        User user = s == null ? null
                : users.findById(s.userId()).filter(User::isEmailVerified).filter(User::isActive).orElse(null);
        if (user == null) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_REFRESH_TOKEN", "Oturum süresi doldu, tekrar giriş yapın.");
        }
        requireNotBlocked(ctx, user.getId(), "/api/auth/refresh");
        logDevice(user.getId(), ctx, "REFRESH");
        return tokens(user, s.client());
    }

    public void logout(String refreshToken) {
        refresh.revoke(refreshToken);
    }

    /** Tum cihazlardaki oturumlari kapatir (refresh token'lar + eski access token'lar). */
    public void logoutAll(Long userId) {
        sessions.revokeAll(userId);
    }

    public UserView me(Long userId) {
        User u = users.findById(userId)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "Oturum geçersiz."));
        return new UserView(u.getId(), u.getEmail(), u.getDisplayName());
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }

    private static ApiException invalidCode() {
        return new ApiException(HttpStatus.BAD_REQUEST, "INVALID_CODE", "Kod geçersiz veya süresi dolmuş.");
    }

    /** Askiya alinmis hesaplar giris yapamaz; silinmis hesaplar hic var olmamis gibi davranir. */
    private static void requireActive(User user) {
        if (user.getStatus() == UserStatus.SUSPENDED) {
            throw new ApiException(HttpStatus.FORBIDDEN, "ACCOUNT_SUSPENDED", "Hesabınız askıya alınmıştır.");
        }
        if (user.getStatus() == UserStatus.DELETED) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS", "E-posta veya şifre hatalı.");
        }
    }

    /** app.admin.emails listesindeki adresler ADMIN olur. Rol degistiyse true. */
    private boolean promoteIfAdmin(User user) {
        if (user.getRole() != Role.ADMIN && admin.isAdminEmail(user.getEmail())) {
            user.setRole(Role.ADMIN);
            return true;
        }
        return false;
    }

    private TokenResponse tokens(User user, String client) {
        String c = RefreshTokenService.normalizeClient(client);
        return new TokenResponse(jwt.createAccessToken(user, c), refresh.issue(user.getId(), c),
                jwt.accessTtl().toSeconds(), "Bearer");
    }
}
