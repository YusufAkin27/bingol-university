package edu.bingol.backend.auth;

import edu.bingol.backend.auth.dto.TokenResponse;
import edu.bingol.backend.auth.dto.UserView;
import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.auth.token.PendingRegistrationStore;
import edu.bingol.backend.auth.token.PendingRegistrationStore.Pending;
import edu.bingol.backend.auth.token.RefreshTokenService;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.auth.token.VerificationService;
import edu.bingol.backend.catalog.CatalogService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.UserStatus;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.Locale;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
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

    public static String normalizeEmail(String email) {
        return email.trim().toLowerCase(Locale.ROOT);
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
            return;
        }
        // Kod once gider (bekleme suresi doluysa burada 429); bekleme sirasinda bekleyen kayit ezilmez.
        verification.issue(email, lang);
        pending.save(email, new Pending(encoder.encode(password), displayName.trim(), lang.code(), fa, de, gr));
    }

    public void resendCode(String rawEmail) {
        String email = normalizeEmail(rawEmail);
        Pending p = pending.find(email);
        if (p == null) {
            return;
        }
        try {
            verification.issue(email, Lang.of(p.language()));
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

    public TokenResponse verifyEmail(String rawEmail, String code) {
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
        return tokens(user);
    }

    public TokenResponse login(String rawEmail, String password) {
        User user = users.findByEmail(normalizeEmail(rawEmail)).orElse(null);
        boolean passwordOk = encoder.matches(password, user == null ? dummyHash : user.getPasswordHash());
        if (user == null || !passwordOk) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS", "E-posta veya şifre hatalı.");
        }
        if (!user.isEmailVerified()) {
            throw new ApiException(HttpStatus.FORBIDDEN, "EMAIL_NOT_VERIFIED",
                    "Giriş için önce e-posta adresinizi doğrulayın.");
        }
        requireActive(user);
        if (promoteIfAdmin(user)) {
            users.save(user);
        }
        return tokens(user);
    }

    public TokenResponse refresh(String refreshToken) {
        Long userId = refresh.consume(refreshToken);
        User user = userId == null ? null : users.findById(userId).filter(User::isEmailVerified).filter(User::isActive).orElse(null);
        if (user == null) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_REFRESH_TOKEN", "Oturum süresi doldu, tekrar giriş yapın.");
        }
        return tokens(user);
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

    private TokenResponse tokens(User user) {
        return new TokenResponse(jwt.createAccessToken(user), refresh.issue(user.getId()),
                jwt.accessTtl().toSeconds(), "Bearer");
    }
}
