package edu.bingol.backend.auth.oauth;

import edu.bingol.backend.auth.AccountCreator;
import edu.bingol.backend.auth.realemail.RelayEmails;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.ShortTx;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.observability.LogMasking;
import edu.bingol.backend.profile.naming.DisplayNamePolicy;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.nio.charset.StandardCharsets;
import java.text.Normalizer;
import java.time.Instant;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;

/**
 * Google/Apple ile giris, hesap baglama ve baglama kaldirma.
 *
 * <p>ESLESME KURALI: hesap yalniz saglayici kimligiyle ({@code provider + subject}) bulunur. Kimlik tanimiyor ama ayni
 * e-posta mevcut bir hesapta varsa OTOMATIK BIRLESTIRME YAPILMAZ: 409 {@code OAUTH_LINK_REQUIRED}; kullanici once
 * mevcut yontemiyle (e-posta + sifre) girip {@link #link} ile yeniden dogrulayarak baglar. Yeni kullanici: e-posta
 * saglayicida dogrulanmis sayilir, parola yoktur, profil tamamlanmamistir (sunucu kapisi onboarding'e kadar yazmayi keser).
 */
@Service
public class OAuthService {

    private static final Logger log = LoggerFactory.getLogger(OAuthService.class);
    private static final int NAME_MAX = 60;

    /** Giris sonucu: hesap + bu istekte yeni mi acildi. */
    public record SignIn(User user, boolean isNew) {
    }

    /** Bagli kimlik ozeti (hesap guvenligi ekrani). */
    public record IdentityView(String provider, String email, boolean emailPrivate, String linkedAt) {
    }

    private final OAuthProperties props;
    private final OAuthTokenVerifier verifier;
    private final AuthIdentityRepository identities;
    private final UserRepository users;
    private final AccountCreator accounts;
    private final PasswordEncoder encoder;
    private ShortTx tx = ShortTx.direct();

    /** Gorunen ad on dolduruntusu icin uygunsuz ifade denetimi (istege bagli: guard'siz testler). */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private ContentGuard guard;

    public OAuthService(OAuthProperties props, OAuthTokenVerifier verifier, AuthIdentityRepository identities,
                        UserRepository users, AccountCreator accounts, PasswordEncoder encoder) {
        this.props = props;
        this.verifier = verifier;
        this.identities = identities;
        this.users = users;
        this.accounts = accounts;
        this.encoder = encoder;
    }

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setTxManager(PlatformTransactionManager tm) {
        this.tx = ShortTx.of(tm);
    }

    public boolean enabled() {
        return props.enabled();
    }

    /** Bayrak kapaliyken tum OAuth uclari 404 OAUTH_DISABLED. */
    public void requireEnabled() {
        if (!props.enabled()) {
            throw new ApiException(HttpStatus.NOT_FOUND, "OAUTH_DISABLED", "Bu giriş yöntemi şu anda kullanılamıyor.");
        }
    }

    // ------------------------------------------------------------------ giris

    public SignIn signInGoogle(String idToken) {
        requireEnabled();
        return resolve(verifier.verifyGoogle(idToken), null, null);
    }

    /** Apple ad bilgisini YALNIZ ilk yetkilendirmede verir; istemci gonderirse yeni hesapta saklanir. */
    public SignIn signInApple(String identityToken, String nonce, String firstName, String lastName) {
        requireEnabled();
        return resolve(verifier.verifyApple(identityToken, nonce), firstName, lastName);
    }

    SignIn resolve(OAuthClaims claims, String hintFirst, String hintLast) {
        try {
            return tx.call(() -> resolveInTx(claims, hintFirst, hintLast));
        } catch (DataIntegrityViolationException race) {
            // Ayni kimlikle eszamanli iki ilk giris: kazanan hesabi + kimligi tek islemde yazdi; ikinci deneme onu bulur
            return tx.call(() -> resolveInTx(claims, hintFirst, hintLast));
        }
    }

    private SignIn resolveInTx(OAuthClaims claims, String hintFirst, String hintLast) {
        AuthIdentity known = identities.findByProviderAndSubject(claims.provider(), claims.subject()).orElse(null);
        if (known != null) {
            User user = users.findById(known.getUserId()).orElse(null);
            if (user == null || user.getStatus() == UserStatus.DELETED) {
                throw new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS", "Giriş yapılamadı.");
            }
            known.setLastLoginAt(Instant.now());
            // Gercek e-postasini dogrulamis hesapta role adresi geri yazilmaz (KVKK: eski role adresi saklanmaz)
            boolean skipRelayEcho = claims.emailPrivate() && !user.isEmailRelay();
            if (claims.email() != null && !skipRelayEcho) {
                known.setEmail(claims.email());
                known.setEmailIsPrivate(claims.emailPrivate());
            }
            if (!user.isEmailRelay() && RelayEmails.isRelay(user.getEmail())) {
                user.setEmailRelay(true); // kendini onarma: role alan adli hesap her zaman isaretli (kapi zorlamaz)
                users.save(user);
            }
            identities.save(known);
            return new SignIn(user, false);
        }
        if (claims.email() == null) {
            // Apple sonraki girislerde e-posta vermez; kimlik tanimiyorsa hesap acilamaz
            throw new ApiException(HttpStatus.BAD_REQUEST, "OAUTH_EMAIL_MISSING", "E-posta adresi alınamadı.");
        }
        if (users.findByEmail(claims.email()).isPresent()) {
            // OTOMATIK BIRLESTIRME YOK: yalniz e-posta esitligi hesap sahipligi kaniti degildir
            throw new OAuthLinkRequiredException(claims.provider(), LogMasking.email(claims.email()));
        }
        String first = cleanName(claims.givenName() != null ? claims.givenName() : hintFirst);
        String last = cleanName(claims.familyName() != null ? claims.familyName() : hintLast);
        boolean relay = claims.emailPrivate() || RelayEmails.isRelay(claims.email());
        User created = accounts.createFromOAuth(claims.email(), prefillName(claims.email(), first, last), first, last,
                Lang.of(LocaleContextHolder.getLocale()).code(), relay);
        AuthIdentity id = newIdentity(created.getId(), claims);
        id.setLastLoginAt(Instant.now());
        identities.saveAndFlush(id);
        return new SignIn(created, true);
    }

    private static AuthIdentity newIdentity(Long userId, OAuthClaims claims) {
        AuthIdentity id = new AuthIdentity();
        id.setUserId(userId);
        id.setProvider(claims.provider());
        id.setSubject(claims.subject());
        id.setEmail(claims.email());
        id.setEmailIsPrivate(claims.emailPrivate());
        return id;
    }

    /** Saglayici adini on doldurur; kurallardan gecmezse e-posta/gecici ad. Onboarding'de kullanici degistirir. */
    private String prefillName(String email, String first, String last) {
        String full = ((first == null ? "" : first) + " " + (last == null ? "" : last)).trim();
        if (!full.isEmpty()) {
            try {
                String name = DisplayNamePolicy.normalize(full, false);
                ContentGuard.clean(guard, ContentGuard.Entity.PROFILE, "displayName", null, name);
                return name;
            } catch (ApiException e) {
                log.debug("OAuth ad on dolduruntusu reddedildi: {}", e.code());
            }
        }
        return DisplayNamePolicy.temporaryFor(email);
    }

    /** Saglayicidan gelen ad parcasi: Unicode NFC, kontrol/gorunmez karakter at, bosluk sadele, en cok 60. */
    static String cleanName(String raw) {
        if (raw == null) {
            return null;
        }
        String s = Normalizer.normalize(raw, Normalizer.Form.NFC);
        StringBuilder sb = new StringBuilder();
        s.codePoints().forEach(cp -> {
            if (Character.isLetter(cp) || cp == ' ' || cp == '-' || cp == '.'
                    || Character.getType(cp) == Character.NON_SPACING_MARK) {
                sb.appendCodePoint(cp);
            }
        });
        String out = sb.toString().trim().replaceAll("\\s+", " ");
        if (out.codePoints().filter(Character::isLetter).count() < 1) {
            return null;
        }
        return out.codePointCount(0, out.length()) > NAME_MAX ? out.substring(0, out.offsetByCodePoints(0, NAME_MAX)) : out;
    }

    // ------------------------------------------------------------------ baglama

    /**
     * Mevcut hesaba saglayici baglar. Yeniden dogrulama ZORUNLU: parolasi olan hesapta parola; parolasiz (yalniz OAuth)
     * hesapta zaten bagli bir saglayicinin taze token'i ({@code reauth*}).
     */
    public void link(Long userId, OAuthProvider provider, String token, String nonce, String password,
                     OAuthProvider reauthProvider, String reauthToken, String reauthNonce) {
        requireEnabled();
        User user = loadActive(userId);
        reauthenticate(user, password, reauthProvider, reauthToken, reauthNonce);
        OAuthClaims claims = verify(provider, token, nonce);
        tx.run(() -> {
            AuthIdentity existing = identities.findByProviderAndSubject(provider, claims.subject()).orElse(null);
            if (existing != null) {
                if (existing.getUserId().equals(userId)) {
                    return; // zaten bagli: idempotent
                }
                throw new ApiException(HttpStatus.CONFLICT, "OAUTH_IDENTITY_TAKEN",
                        "Bu hesap başka bir kullanıcıya bağlı.");
            }
            if (identities.findByUserIdAndProvider(userId, provider).isPresent()) {
                throw new ApiException(HttpStatus.CONFLICT, "OAUTH_PROVIDER_ALREADY_LINKED",
                        "Bu sağlayıcı için hesabınıza zaten bir kimlik bağlı.");
            }
            try {
                identities.saveAndFlush(newIdentity(userId, claims));
            } catch (DataIntegrityViolationException e) {
                throw new ApiException(HttpStatus.CONFLICT, "OAUTH_IDENTITY_TAKEN", "Bu hesap başka bir kullanıcıya bağlı.");
            }
        });
    }

    /** Baglantiyi kaldirir; hesapta baska giris yontemi kalmiyorsa 409 OAUTH_LAST_LOGIN_METHOD. */
    public void unlink(Long userId, OAuthProvider provider) {
        requireEnabled();
        User user = loadActive(userId);
        tx.run(() -> {
            AuthIdentity id = identities.findByUserIdAndProvider(userId, provider)
                    .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "OAUTH_IDENTITY_NOT_FOUND",
                            "Bu sağlayıcı hesabınıza bağlı değil."));
            if (!user.hasPassword() && identities.countByUserId(userId) <= 1) {
                throw new ApiException(HttpStatus.CONFLICT, "OAUTH_LAST_LOGIN_METHOD",
                        "Bu, hesabınızdaki tek giriş yöntemi. Önce şifre belirleyin ya da başka bir sağlayıcı bağlayın.");
            }
            identities.delete(id);
        });
    }

    public List<IdentityView> identitiesOf(Long userId) {
        requireEnabled();
        return identities.findByUserIdOrderByCreatedAtAsc(userId).stream()
                .map(i -> new IdentityView(i.getProvider().name(), i.getEmail(), i.isEmailIsPrivate(),
                        i.getCreatedAt().toString()))
                .toList();
    }

    /** /users/me icin bagli saglayici adlari (GOOGLE, APPLE); bayrak kapaliyken de okunur (bos liste dogal). */
    public List<String> providersOf(Long userId) {
        return identities.findByUserIdOrderByCreatedAtAsc(userId).stream().map(i -> i.getProvider().name()).toList();
    }

    // ------------------------------------------------------------------ yeniden dogrulama

    /** Hassas islem (baglama, hesap silme) oncesi: parola ya da bagli saglayicinin taze token'i. Basarisizsa 403. */
    public void reauthenticate(User user, String password, OAuthProvider reauthProvider, String reauthToken,
                               String reauthNonce) {
        if (user.hasPassword()) {
            if (password == null || password.isBlank() || password.getBytes(StandardCharsets.UTF_8).length > 72
                    || !encoder.matches(password, user.getPasswordHash())) {
                throw new ApiException(HttpStatus.FORBIDDEN, "WRONG_PASSWORD", "Şifre hatalı.");
            }
            return;
        }
        // Parolasiz hesap: bagli saglayicidan taze kimlik
        if (reauthProvider == null || reauthToken == null || reauthToken.isBlank()) {
            throw new ApiException(HttpStatus.FORBIDDEN, "OAUTH_REAUTH_REQUIRED",
                    "Bu işlem için bağlı hesabınızla yeniden doğrulama gerekli.");
        }
        OAuthClaims claims = verify(reauthProvider, reauthToken, reauthNonce);
        AuthIdentity own = identities.findByUserIdAndProvider(user.getId(), reauthProvider).orElse(null);
        if (own == null || !own.getSubject().equals(claims.subject())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "OAUTH_REAUTH_REQUIRED",
                    "Bu işlem için bağlı hesabınızla yeniden doğrulama gerekli.");
        }
    }

    /** Hesap silme icin yeniden dogrulama (parolasiz hesap: bagli saglayici token'i). */
    public void reauthenticateById(Long userId, String password, OAuthProvider provider, String token, String nonce) {
        reauthenticate(loadActive(userId), password, provider, token, nonce);
    }

    private OAuthClaims verify(OAuthProvider provider, String token, String nonce) {
        if (provider == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "OAUTH_TOKEN_INVALID", "Giriş doğrulanamadı.");
        }
        return provider == OAuthProvider.GOOGLE ? verifier.verifyGoogle(token) : verifier.verifyApple(token, nonce);
    }

    private User loadActive(Long userId) {
        return users.findById(userId).filter(User::isActive)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "Oturum geçersiz."));
    }
}
