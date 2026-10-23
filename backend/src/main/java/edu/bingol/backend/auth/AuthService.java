package edu.bingol.backend.auth;

import edu.bingol.backend.auth.dto.TokenResponse;
import edu.bingol.backend.auth.dto.UserView;
import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.auth.token.RefreshTokenService;
import edu.bingol.backend.auth.token.VerificationService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.legal.LegalService;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.UserStatus;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.Locale;
import java.util.regex.Pattern;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
public class AuthService {

    /** bingol.edu.tr ve alt alan adlari (ogr.bingol.edu.tr gibi). */
    private static final Pattern UNIVERSITY_EMAIL =
            Pattern.compile("^[a-z0-9._%+\\-]+@([a-z0-9\\-]+\\.)*bingol\\.edu\\.tr$");

    private final UserRepository users;
    private final PasswordEncoder encoder;
    private final JwtService jwt;
    private final RefreshTokenService refresh;
    private final VerificationService verification;
    private final AdminProperties admin;
    private final LegalService legal;

    public AuthService(UserRepository users, PasswordEncoder encoder, JwtService jwt,
                       RefreshTokenService refresh, VerificationService verification, AdminProperties admin,
                       LegalService legal) {
        this.admin = admin;
        this.legal = legal;
        this.users = users;
        this.encoder = encoder;
        this.jwt = jwt;
        this.refresh = refresh;
        this.verification = verification;
    }

    public static String normalizeEmail(String email) {
        return email.trim().toLowerCase(Locale.ROOT);
    }

    public void register(String rawEmail, String password, String displayName, Lang lang) {
        String email = normalizeEmail(rawEmail);
        if (!UNIVERSITY_EMAIL.matcher(email).matches()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "EMAIL_DOMAIN_NOT_ALLOWED",
                    "Yalnızca bingol.edu.tr uzantılı e-posta ile kayıt olunabilir.");
        }
        User user = users.findByEmail(email).orElse(null);
        if (user != null && user.isEmailVerified()) {
            throw new ApiException(HttpStatus.CONFLICT, "EMAIL_ALREADY_REGISTERED",
                    "Bu e-posta ile zaten kayıt olunmuş.");
        }
        if (user == null) {
            user = new User();
            user.setEmail(email);
        }
        // Dogrulanmamis kayit tekrar gelirse bilgiler guncellenir (e-postanin sahibi olmayan biri
        // adresi "rezerve" edemez: dogrulama olmadan hesap kullanilamaz).
        user.setPasswordHash(encoder.encode(password));
        user.setDisplayName(displayName.trim());
        user.setLanguage(lang.code());
        user = users.save(user);
        legal.recordSignupConsent(user.getId());
        verification.issue(email, lang);
    }

    public void resendCode(String rawEmail) {
        String email = normalizeEmail(rawEmail);
        users.findByEmail(email).filter(u -> !u.isEmailVerified())
                .ifPresent(u -> verification.issue(email, Lang.of(u.getLanguage())));
        // Hesap yoksa/dogrulanmissa da ayni cevap doner (e-posta taramasini engellemek icin).
    }

    public TokenResponse verifyEmail(String rawEmail, String code) {
        String email = normalizeEmail(rawEmail);
        User user = users.findByEmail(email)
                .orElseThrow(() -> new ApiException(HttpStatus.BAD_REQUEST, "INVALID_CODE", "Kod geçersiz veya süresi dolmuş."));
        if (!user.isEmailVerified()) {
            if (!verification.verify(email, code.trim())) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_CODE", "Kod geçersiz veya süresi dolmuş.");
            }
            user.setEmailVerified(true);
            promoteIfAdmin(user);
            users.save(user);
        } else {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_CODE", "Kod geçersiz veya süresi dolmuş.");
        }
        return tokens(user);
    }

    public TokenResponse login(String rawEmail, String password) {
        User user = users.findByEmail(normalizeEmail(rawEmail)).orElse(null);
        if (user == null || !encoder.matches(password, user.getPasswordHash())) {
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

    public UserView me(Long userId) {
        User u = users.findById(userId)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "Oturum geçersiz."));
        return new UserView(u.getId(), u.getEmail(), u.getDisplayName());
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
