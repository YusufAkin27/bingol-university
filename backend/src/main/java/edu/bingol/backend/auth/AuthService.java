package edu.bingol.backend.auth;

import edu.bingol.backend.accessban.AccessGuard;
import edu.bingol.backend.accessban.ClientContext;
import edu.bingol.backend.accessban.DeviceLogService;
import edu.bingol.backend.auth.dto.TokenResponse;
import edu.bingol.backend.auth.dto.VerificationDtos;
import edu.bingol.backend.auth.dto.UserView;
import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.auth.session.UserSessionService;
import edu.bingol.backend.auth.token.PendingRegistrationStore;
import edu.bingol.backend.auth.token.PendingRegistrationStore.Pending;
import edu.bingol.backend.auth.token.MilliTick;
import edu.bingol.backend.auth.token.RefreshTokenService;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.auth.token.VerificationService;
import edu.bingol.backend.auth.twofactor.TwoFactorRequiredException;
import edu.bingol.backend.auth.twofactor.TwoFactorService;
import edu.bingol.backend.catalog.CatalogService;
import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.moderation.profanity.ContentGuard.Entity;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.observability.LogMasking;
import edu.bingol.backend.profile.naming.DisplayNamePolicy;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.UserStatus;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.nio.charset.StandardCharsets;
import java.util.OptionalLong;
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

    /**
     * Kayit e-postasi icin YALNIZ bicim denetimi (2026-11-05 karari: alan adi kisiti kalkti; gmail/outlook/hotmail/yahoo
     * ve her gecerli saglayici kabul). Alan adi kara/beyaz listesi yok; sahiplik kaniti 6 haneli e-posta kodudur.
     * Yerel kisim: harf/rakam/_/-/+ ve tek noktalar (basta/sonda/ardisik nokta ve % yok); alan adi: en az iki etiket,
     * son etiket harf (ya da xn--). {@code matches()} tam eslesme; ic ice belirsiz nicelik yok (ReDoS yok).
     */
    private static final Pattern EMAIL_FORMAT = Pattern.compile(
            "^[a-z0-9_+\\-]{1,64}(\\.[a-z0-9_+\\-]{1,64}){0,15}@([a-z0-9]([a-z0-9\\-]{0,61}[a-z0-9])?\\.){1,10}"
                    + "([a-z]{2,24}|xn--[a-z0-9\\-]{2,58})$");

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
    /** Dogrulamada parola kaniti zorunlu mu (varsayilan evet; eski istemciler icin kapatilabilir). */
    @org.springframework.beans.factory.annotation.Value("${app.auth.verify-requires-password:true}")
    private boolean verifyRequiresPassword = true;
    /** Parola politikasi: kullanici icin yalniz en az uzunluk (6); yonetici hesaplari icin daha uzun + tam guc denetimi (T-005). */
    @org.springframework.beans.factory.annotation.Value("${app.auth.password-min-length:6}")
    private int passwordMinLength = PasswordPolicy.DEFAULT_MIN;
    @org.springframework.beans.factory.annotation.Value("${app.auth.password-min-length-admin:12}")
    private int passwordMinLengthAdmin = PasswordPolicy.DEFAULT_ADMIN_MIN;
    /**
     * Tek mobil oturum kurali (eski davranis): true iken mobil giris onceki MOBIL oturumlari kapatir ve FCM kayitlarini
     * siler. Varsayilan false = COKLU OTURUM: girisler birbirini kapatmaz, "Cihazlarim"dan tek tek cikilir.
     */
    @org.springframework.beans.factory.annotation.Value("${app.auth.single-mobile-session:false}")
    private boolean singleMobileSession = false;
    /** Kota asiminda ertelenmis e-posta dogrulama (QT-BE); false = eski davranis (503 MAIL_QUOTA_EXHAUSTED). */
    @org.springframework.beans.factory.annotation.Value("${app.auth.deferred-verification.enabled:true}")
    private boolean deferredVerificationEnabled = true;
    /** Kullanici yokken de encoder.matches calissin diye: giris suresi hesap varligini sizdirmasin. */
    private final String dummyHash;
    /** Erisim engeli (IP/cihaz/kullanici) ve cihaz gunlugu; testlerde/eski cagrilarda null olabilir. */
    private AccessGuard guard;
    private DeviceLogService deviceLog;
    /** Guvenlik e-postasi (istege bagli: mail'siz kurulan testler icin). */
    @Autowired(required = false)
    private edu.bingol.backend.mail.MailService mail;

    /** Ihlal defteri (istege bagli: defter olmadan kurulan testler icin). */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private edu.bingol.backend.moderation.ViolationLedgerService violationLedger;

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

    /** Bu hesap icin gecerli en kisa parola uzunlugu (yoneticiler daha uzun). */
    private int minPasswordFor(boolean adminAccount) {
        return adminAccount ? Math.max(passwordMinLength, passwordMinLengthAdmin) : passwordMinLength;
    }

    /** Yonetici: tam guc politikasi (PASSWORD_TOO_WEAK); diger hesaplar: yalniz en az uzunluk (PASSWORD_TOO_SHORT). */
    private void requirePasswordPolicy(String password, boolean adminAccount, PasswordPolicy.Context ctx) {
        if (adminAccount) {
            PasswordPolicy.require(password, minPasswordFor(true), ctx);
        } else {
            PasswordPolicy.requireForUser(password, passwordMinLength);
        }
    }

    void setVerifyRequiresPassword(boolean v) {
        this.verifyRequiresPassword = v;
    }

    /**
     * Iki faktorlu dogrulama. Uygulamada ZORUNLU (bean yoksa acilis basarisiz: 2FA sessizce kapanmasin); yalniz Spring
     * disinda elle kurulan birim testlerinde null olabilir. null iken 2FA'si acik hesap GIRIS YAPAMAZ (fail-closed).
     */
    private TwoFactorService twoFactor;

    @Autowired
    void setTwoFactor(TwoFactorService twoFactor) {
        this.twoFactor = twoFactor;
    }

    /** Oturum kayitlari ("Cihazlarim"); yoksa (kayit olmadan kurulan birim testleri) token'lar sid'siz uretilir. */
    private UserSessionService userSessions;

    @Autowired(required = false)
    void setUserSessions(UserSessionService userSessions) {
        this.userSessions = userSessions;
    }

    void setSingleMobileSession(boolean v) {
        this.singleMobileSession = v;
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

    /** Kayit ile ayni bicim denetimi (alan adi kisiti yok): kucuk harfe normallestirilmis tam adres uygunsa true. */
    public static boolean isValidEmailFormat(String normalizedEmail) {
        return normalizedEmail != null && EMAIL_FORMAT.matcher(normalizedEmail).matches();
    }

    /** E-posta ya da okul numarasi -> tam e-posta (bkz. LoginIdentifier); gecersizse 400 VALIDATION_ERROR. */
    public static String normalizeEmail(String email) {
        return LoginIdentifier.normalize(email);
    }

    /**
     * Kayit verisi dogrulanana kadar yalnizca Redis'te tutulur; veritabaninda hesap olusmaz. Ayni e-posta icin
     * bekleyen kayit varken yeni istek SON YAZAN KAZANIR kuralini isletir: bekleyen kayit (parola/ad) ezilir ve eski
     * kod gecersiz olur; dogrulama yalniz SON istegin parolasini etkinlestirir. Boylece baskasinin e-postasiyla
     * onceden kayit acan biri, adres sahibi kendi kaydini yaptiginda parolasini hesaba yazdiramaz. Kayit, kod
     * GONDERILDIKTEN sonra ezilir (bekleme suresi 429 verirse eski kayit ve eski kod birlikte kalir: eski kod yeni
     * parolayi etkinlestiremez). Bekleyen kaydin varligi ayri bir cevapla sezdirilmez (her durumda 202).
     */
    public void register(String rawEmail, String password, String displayName, Lang lang) {
        register(rawEmail, password, displayName, lang, null, null, null);
    }

    /** faculty/department/grade opsiyoneldir; verilenler katalogla dogrulanir (bos metin = verilmedi). */
    public void register(String rawEmail, String password, String displayName, Lang lang, String faculty,
                         String department, String grade) {
        register(rawEmail, password, displayName, lang, faculty, department, grade, false);
    }

    /**
     * adminPortal=true (yonetici paneli kayit sayfasi): YALNIZ daha siki. Adres ADMIN_EMAILS'te degilse (ya da zaten
     * dogrulanmis hesapsa) kod gonderilmez, bekleyen kayit yazilmaz, hesap acilmaz; cagirana genel basari doner (202),
     * boylece liste uyeligi sizmaz. Dogrulamalar (parola/ad/katalog/alias/kota) iki durumda da AYNI ve yonetici
     * kurallariyla kosar (yanit farki liste uyeligini sezdirmesin); gecersiz girdi iki durumda da ayni hatayi alir.
     * Parola ozeti iki durumda da hesaplanir (sure farki sizdirmasin). adminPortal=false: genel kayit kurali aynen.
     */
    public void register(String rawEmail, String password, String displayName, Lang lang, String faculty,
                         String department, String grade, boolean adminPortal) {
        doRegister(rawEmail, password, displayName, lang, faculty, department, grade, adminPortal, false, null, null);
    }

    /**
     * Kayit + kota asiminda ERTELENMIS dogrulama (QT-BE). Kota dolu degilse {@link #register} ile ayni (null doner:
     * kod gonderildi, bekleyen kayit yazildi). Kota doluyken (503 MAIL_QUOTA_EXHAUSTED yerine) gercek hesap acilir:
     * emailVerified=false, verificationDeferred=true, jeton cifti DONER (cagiran 201 verir). Yonetici adresleri
     * (ADMIN_EMAILS) ve yonetici portali ertelenmez (kimlik taklidiyle yonetici terfisi riski): onlarda eski 503.
     */
    public TokenResponse registerOrDefer(String rawEmail, String password, String displayName, Lang lang,
                                         String faculty, String department, String grade, boolean adminPortal,
                                         String client, ClientContext ctx) {
        return doRegister(rawEmail, password, displayName, lang, faculty, department, grade, adminPortal,
                deferredVerificationEnabled, client, ctx);
    }

    private TokenResponse doRegister(String rawEmail, String password, String displayName, Lang lang, String faculty,
                                     String department, String grade, boolean adminPortal, boolean allowDefer,
                                     String client, ClientContext ctx) {
        // Kayitta okul numarasi kisayolu yok: kod gidecek adres kullanicinin yazdigi TAM adres olmali (numara@ tahmini,
        // gercek kutusu olmayan ogrencilerde kodun kaybolmasina yol aciyordu). Giris/sifre sifirlama numarayi kabul etmeye devam eder.
        if (rawEmail != null && !rawEmail.isBlank() && rawEmail.indexOf('@') < 0) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "EMAIL_FULL_REQUIRED",
                    "E-posta adresinizin tamamını yazın, örn. ad.soyad@ornek.com");
        }
        String email = normalizeEmail(rawEmail);
        boolean authorizedAdmin = admin.isAdminEmail(email);
        // Alan adi kisiti YOK (2026-11-05): yalniz bicim; gecersizse genel dogrulama hatasi. Yonetici portalinda bicim karari
        // verilmez: yetkisiz adres asagida sessizce elenir.
        if (!adminPortal && !authorizedAdmin && !EMAIL_FORMAT.matcher(email).matches()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz istek.");
        }
        if (LoginIdentifier.hasPlusAlias(email)) {
            // Tek posta kutusu = tek hesap: +etiketli adresler sinirsiz hesap/oy/kota carpani olurdu.
            throw new ApiException(HttpStatus.BAD_REQUEST, "EMAIL_ALIAS_NOT_ALLOWED",
                    "E-posta adresinde + etiketi kullanılamaz.");
        }
        requirePasswordBytes(password);
        // Gorunen ad politikasi + parola politikasi: hicbir yan etki (kota, kod e-postasi) olmadan ONCE (T-001/T-005).
        // ADMIN_EMAILS yalniz "ayrilmis ad" kisitindan muaftir; bicim kurallari (gorunmez karakter, baglanti...) herkese.
        boolean adminAddress = authorizedAdmin || adminPortal;
        // Ad kayitta istege bagli (mobil: kayittan sonra profil tamamlama adiminda girilir): bos gelirse gecici varsayilan.
        // Yonetici kaydi icin ad zorunlu kalir (bos ad = INVALID_DISPLAY_NAME, eski davranis).
        boolean nameGiven = adminAddress || (displayName != null && !displayName.isBlank());
        String name = nameGiven ? DisplayNamePolicy.normalize(displayName, adminAddress) : DisplayNamePolicy.temporaryFor(email);
        String guardedName = nameGiven ? name : null; // turetilmis ad uygunsuz ifade filtresine sokulmaz
        requirePasswordPolicy(password, adminAddress, new PasswordPolicy.Context(email, name));
        String fa = blankToNull(faculty);
        String de = blankToNull(department);
        String gr = blankToNull(grade);
        catalog.requireValid(fa, de, gr);
        // Askiya alinmisken silinen hesabin adresi yeniden kayit olamaz (ihlal defteri, T-058); genel 403
        if (violationLedger != null) {
            violationLedger.requireNotBanned(email);
        }
        try {
            verification.requireMailQuota();
        } catch (ApiException e) {
            if (allowDefer && !adminPortal && !authorizedAdmin && "MAIL_QUOTA_EXHAUSTED".equals(e.code())) {
                return registerDeferred(email, password, name, guardedName, lang, fa, de, gr, client, ctx);
            }
            throw e;
        }
        if (adminPortal && !authorizedAdmin) {
            // Yetkisiz adres: yetkili akisla ayni sure/cevap (parola ozeti + ayni dogrulamalar), yan etki YOK.
            ContentGuard.clean(contentGuard, Entity.PROFILE, "displayName", null, guardedName);
            encoder.encode(password);
            log.info("Yonetici portali kaydi yetkisiz adres icin sessizce atlandi: {}", LogMasking.email(email));
            return null;
        }
        User user = users.findByEmail(email).orElse(null);
        if (user != null && user.isEmailVerified()) {
            if (adminPortal) {
                // Yetkili ama zaten kayitli: 409 ADMIN_EMAILS uyeligini sizdirirdi; yetkisizle ayni sessiz 202.
                ContentGuard.clean(contentGuard, Entity.PROFILE, "displayName", null, guardedName);
                encoder.encode(password);
                log.info("Yonetici portali kaydi zaten kayitli adres icin atlandi: {}", LogMasking.email(email));
                return null;
            }
            throw new ApiException(HttpStatus.CONFLICT, "EMAIL_ALREADY_REGISTERED",
                    "Bu e-posta ile zaten kayıt olunmuş.");
        }
        // Kod e-postasi gitmeden once her sey dogrulansin (hata kod gonderiminden sonra kalmasin).
        ContentGuard.clean(contentGuard, Entity.PROFILE, "displayName", null, guardedName);
        String hash = encoder.encode(password);
        // Kod once gider (bekleme suresi doluysa burada 429); bekleyen kayit ancak sonra ezilir.
        try {
            verification.issue(email, lang);
        } catch (ApiException e) {
            if (adminPortal && "RESEND_COOLDOWN".equals(e.code())) {
                // 429 yalnizca yetkili adreste doneceginden liste uyeligini sizdirirdi: portalda yutulur (eski kod/kayit kalir).
                log.debug("Yonetici portali kayit bekleme suresi nedeniyle atlandi: {}", LogMasking.email(email));
                return null;
            }
            throw e;
        }
        pending.save(email, new Pending(hash, name, lang.code(), fa, de, gr));
        return null;
    }

    /**
     * Kota doluyken kayit (QT-BE): bekleyen kayit yerine GERCEK kullanici satiri (emailVerified=false,
     * verificationDeferred=true, rol USER, sozlesme onayi yazilir). Dogrulanmis hesap 409 (normal akisla ayni).
     * Ayni adreste dogrulanmamis satir varsa YENIDEN KULLANILIR ("son yazan kazanir", bekleyen kayitla ayni kural):
     * parola/ad ezilir ve eski satirin tum oturumlari kapanir, boylece onceden kayit acan biri adres sahibinin yeni
     * kaydinin oturumunu tasiyamaz. Bu noktaya kadar tum dogrulamalar (alan adi, +etiket, parola, ad, katalog, ihlal
     * defteri) calisti; kod e-postasi GITMEZ (kota dolu), dogrulama sonradan JWT'li uclarla/DeferredVerificationJob ile.
     */
    private TokenResponse registerDeferred(String email, String password, String name, String guardedName, Lang lang,
                                           String fa, String de, String gr, String client, ClientContext ctx) {
        User existing = users.findByEmail(email).orElse(null);
        if (existing != null && existing.isEmailVerified()) {
            throw new ApiException(HttpStatus.CONFLICT, "EMAIL_ALREADY_REGISTERED",
                    "Bu e-posta ile zaten kayıt olunmuş.");
        }
        ContentGuard.clean(contentGuard, Entity.PROFILE, "displayName", null, guardedName);
        String hash = encoder.encode(password);
        User user;
        try {
            user = accounts.createDeferred(email, new Pending(hash, name, lang.code(), fa, de, gr));
        } catch (DataIntegrityViolationException e) {
            throw new ApiException(HttpStatus.CONFLICT, "EMAIL_ALREADY_REGISTERED",
                    "Bu e-posta ile zaten kayıt olunmuş.");
        }
        pending.delete(email);
        if (existing != null) {
            sessions.revokeAll(user.getId());
            MilliTick.awaitNext(); // yeni jetonun iatms'i iptal isaretinden kesin buyuk olsun
        }
        log.info("Kota dolu: ertelenmis dogrulamayla hesap acildi (userId={}, {})", user.getId(), LogMasking.email(email));
        logDevice(user.getId(), ctx, "REGISTER");
        return newSessionTokens(user, client, ctx, false);
    }

    public void resendCode(String rawEmail) {
        String email = normalizeEmail(rawEmail);
        verification.requireMailQuota();
        Pending p = pending.find(email);
        if (p == null) {
            verification.touchResendCooldown(email);
            return;
        }
        try {
            verification.issue(email, Lang.of(p.language()));
            pending.markResend(email);
        } catch (ApiException e) {
            // 180 sn bekleme (429 RESEND_COOLDOWN + Retry-After) istemciye aynen doner; bekleyen kayit yoksa da
            // touchResendCooldown ayni 429'u verdiginden cevap farki kayit varligini sezdirmez.
            if ("RESEND_COOLDOWN".equals(e.code())) {
                throw e;
            }
            log.debug("resend-code atlandi: {}", e.code());
        } catch (RuntimeException e) {
            log.warn("Dogrulama e-postasi gonderilemedi: {}", e.getMessage());
        }
        // Hesap yoksa/dogrulanmissa da ayni cevap doner (e-posta taramasini engellemek icin).
    }

    /**
     * Dogrulanmis ve aktif hesaba sifirlama kodu gonderir. BILINCLI ISTISNA (kullanici karari): hesap yoksa (dogrulanmamis,
     * askida, silinmis/anonimlestirilmis dahil) kod GONDERILMEZ ve 404 ACCOUNT_NOT_FOUND doner (yalniz bu uc; diger
     * kimlik uclari genel cevap verir). Koruma: IP/cihaz/e-posta hiz sinirlari ve kod kotasi (controller + requireMailQuota).
     * Hesap varsa 180 sn icinde ikinci istek 429 RESEND_COOLDOWN (+ Retry-After).
     */
    public void forgotPassword(String rawEmail) {
        String email = normalizeEmail(rawEmail);
        verification.requireMailQuota();
        User u = users.findByEmail(email).filter(User::isEmailVerified).filter(User::isActive)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "ACCOUNT_NOT_FOUND",
                        "Bu okul numarasına ait kayıtlı hesap bulunamadı."));
        verification.issueReset(email, Lang.of(u.getLanguage()));
    }

    /** Sifirlama kodunu dogrular; dogruysa yeni sifre adimi icin tek kullanimlik anahtar verir. */
    public String verifyResetCode(String rawEmail, String code) {
        return verifyResetCode(rawEmail, code, null);
    }

    /** `scope` (IP /64 anahtari) verilirse yanlis deneme sayaci (e-posta, istemci) cifti basinadir: baskasi kilitleyemez. */
    public String verifyResetCode(String rawEmail, String code, String scope) {
        String email = normalizeEmail(rawEmail);
        users.findByEmail(email).filter(User::isEmailVerified).filter(User::isActive)
                .orElseThrow(() -> new ApiException(HttpStatus.BAD_REQUEST, "INVALID_CODE", "Kod geçersiz veya süresi dolmuş."));
        boolean ok = scope == null ? verification.verifyReset(email, code.trim())
                : verification.verifyReset(email, code.trim(), scope);
        if (!ok) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_CODE", "Kod geçersiz veya süresi dolmuş.");
        }
        return verification.issueResetToken(email);
    }

    public void resetPassword(String rawEmail, String resetToken, String newPassword) {
        requirePasswordBytes(newPassword);
        String email = normalizeEmail(rawEmail);
        User user = users.findByEmail(email).filter(User::isEmailVerified).filter(User::isActive)
                .orElseThrow(() -> new ApiException(HttpStatus.BAD_REQUEST, "INVALID_CODE", "Kod geçersiz veya süresi dolmuş."));
        // Anahtar GECERLI mi (tuketmeden): zayif/ayni parola reddi anahtari yakmasin, kullanici duzeltip tekrar denesin.
        if (!verification.checkResetToken(email, resetToken)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_CODE", "Kod geçersiz veya süresi dolmuş.");
        }
        requirePasswordPolicy(newPassword, isAdminAccount(user),
                new PasswordPolicy.Context(user.getEmail(), user.getDisplayName()));
        if (encoder.matches(newPassword, user.getPasswordHash())) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "PASSWORD_UNCHANGED",
                    "Yeni şifre mevcut şifreyle aynı olamaz.");
        }
        if (!verification.consumeResetToken(email, resetToken)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_CODE", "Kod geçersiz veya süresi dolmuş.");
        }
        // Iptal isareti DB kaydindan ONCE (FIX-P02/A01#12): kayittan sonra Redis kesilirse parola degismis ama calinmis
        // access token'lar acik kalirdi; isaret onceden yazilirsa o pencere kapanir.
        sessions.markPasswordChanged(user.getId());
        user.setPasswordHash(encoder.encode(newPassword));
        users.save(user);
        // Sifre degisince calinmis olabilecek tum oturumlar (refresh + access) kapanir.
        sessions.revokeAll(user.getId());
        clearTrustedDevices(user.getId()); // 2FA: sifre sifirlaninca guvenilen cihazlar da gecersiz
        // Hesap sahibi bilsin (kod e-postasina erisen biri sifreyi degistirmis olabilir).
        notifyPasswordChanged(user);
    }

    private boolean isAdminAccount(User user) {
        return user.getRole() == Role.ADMIN || admin.isAdminEmail(user.getEmail());
    }

    /**
     * Oturum acik kullanicinin sifre degisimi. Tum oturumlar (refresh + access, WebSocket dahil) kapanir; isteyen
     * cihaz ayni istemci turunde yeni token cifti alir (mevcut mekanizma tek cihazi koruyamaz: `pwchg:` isareti
     * kullanicinin TUM eski token'larini reddeder). Sifre/ozet log'a yazilmaz.
     */
    public TokenResponse changePassword(Long userId, String currentPassword, String newPassword, String client) {
        return changePassword(userId, currentPassword, newPassword, client, null);
    }

    public TokenResponse changePassword(Long userId, String currentPassword, String newPassword, String client,
                                        ClientContext ctx) {
        User user = users.findById(userId).filter(User::isActive)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "Oturum geçersiz."));
        // 72 bayt ustu parola bcrypt'te istisna firlatirdi (500); sistemde boyle bir parola olamaz.
        if (!fitsBcrypt(currentPassword) || !encoder.matches(currentPassword, user.getPasswordHash())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "WRONG_PASSWORD", "Şifre hatalı.");
        }
        requirePasswordBytes(newPassword);
        if (currentPassword.equals(newPassword)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "PASSWORD_UNCHANGED",
                    "Yeni şifre mevcut şifreyle aynı olamaz.");
        }
        requirePasswordPolicy(newPassword, isAdminAccount(user),
                new PasswordPolicy.Context(user.getEmail(), user.getDisplayName()));
        sessions.markPasswordChanged(userId); // isaret DB kaydindan once (bkz. resetPassword)
        user.setPasswordHash(encoder.encode(newPassword));
        users.save(user);
        sessions.revokeAll(userId);
        clearTrustedDevices(userId); // 2FA: sifre degisince guvenilen cihazlar da gecersiz
        // Iptal isareti `iatms <= isaret` token'lari reddeder: yeni token'in iatms'i kesin buyuk olsun.
        MilliTick.awaitNext();
        notifyPasswordChanged(user);
        return newSessionTokens(user, client, ctx, false);
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
        return verifyEmail(rawEmail, code, client, ctx, null);
    }

    /**
     * `password`: kayit sirasinda girilen parolanin yeniden gonderilmesi (parola kaniti). Bekleyen kaydin parola
     * ozetiyle eslesmezse genel 400 INVALID_CODE doner ve yanlis deneme sayilir; boylece adres sahibine giden bir
     * kodu, baskasinin ayni adrese yeniden gonderdigi kayit (son yazan kazanir) icin kullandirmak parolayi
     * etkinlestiremez. `app.auth.verify-requires-password=false` iken parola YOKSA kontrol atlanir (eski istemciler);
     * parola varsa her durumda dogrulanir.
     */
    public TokenResponse verifyEmail(String rawEmail, String code, String client, ClientContext ctx, String password) {
        String email = normalizeEmail(rawEmail);
        Pending p = pending.find(email);
        User existing = users.findByEmail(email).orElse(null);
        if (p == null || (existing != null && existing.isEmailVerified())) {
            // Zamanlama yan kanali (FIX-P02/A01#15): bekleyen kayit VARSA asagida bcrypt calisir; yoksa da ayni maliyet
            // odenir, boylece yanit suresinden bekleyen kayit varligi sezilmez.
            if (password != null && fitsBcrypt(password)) {
                encoder.matches(password, dummyHash);
            }
            throw invalidCode();
        }
        if (password != null || verifyRequiresPassword) {
            boolean proven = password != null && fitsBcrypt(password) && encoder.matches(password, p.passwordHash());
            if (!proven) {
                // Kodu tuketmeden yanlis deneme say (kod dogru olsa bile): tahmin/DoS butceleri ayni kalir.
                verification.recordWrongAttempt(email, ctx == null || ctx.ip() == null ? null : ClientIp.limitKey(ctx.ip()));
                throw invalidCode();
            }
        }
        boolean ok = ctx == null || ctx.ip() == null ? verification.verify(email, code.trim())
                : verification.verify(email, code.trim(), ClientIp.limitKey(ctx.ip()));
        if (!ok) {
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
        if (existing != null && existing.isVerificationDeferred()) {
            // Adres sahibi kodla dogruladi: onceden ertelenmis kayit acmis olabilecek baskasinin oturumlari kapanir.
            sessions.revokeAll(user.getId());
            MilliTick.awaitNext();
        }
        logDevice(user.getId(), ctx, "REGISTER");
        return newSessionTokens(user, client, ctx, false);
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
        if (!fitsBcrypt(password)) {
            // Hesaptan bagimsiz sabit cevap: bcrypt 72 bayt ustunde istisna firlatirdi.
            throw new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS", "E-posta veya şifre hatalı.");
        }
        User user = users.findByEmail(email).orElse(null);
        // Hesap yoksa bekleyen (dogrulanmamis) kaydin ozetiyle karsilastirilir; ikisi de yoksa sahte ozet (sure esit).
        Pending waiting = user == null ? pending.find(email) : null;
        String hash = user != null ? user.getPasswordHash() : (waiting != null ? waiting.passwordHash() : dummyHash);
        // OAuth ile acilmis hesabin parolasi yok (bcrypt olmayan isaret): sure esit kalsin diye sahte ozetle karsilastirilir
        boolean passwordless = user != null && !User.hasUsablePassword(hash);
        boolean passwordOk = encoder.matches(password, passwordless ? dummyHash : hash) && !passwordless;
        if (!passwordOk || (user == null && waiting == null)) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS", "E-posta veya şifre hatalı.");
        }
        if (user == null) {
            // Bekleyen kayit + dogru sifre: varlik yalnizca sifreyi bilene soylenir (enumerasyon yok).
            throw new ApiException(HttpStatus.FORBIDDEN, "EMAIL_NOT_VERIFIED",
                    "Giriş için önce e-posta adresinizi doğrulayın.");
        }
        if (!user.isEmailVerified() && !user.isVerificationDeferred()) {
            // Ertelenmis dogrulama hesabi (kota asimi) girer (kisitli mod); diger dogrulanmamis satirlar eskisi gibi reddedilir.
            throw new ApiException(HttpStatus.FORBIDDEN, "EMAIL_NOT_VERIFIED",
                    "Giriş için önce e-posta adresinizi doğrulayın.");
        }
        return finishLogin(user, client, ctx, "/api/auth/login", true);
    }

    /**
     * Kimlik kaniti (parola ya da dogrulanmis OAuth saglayici kimligi) gectikten SONRAKI ortak giris adimlari: hesap
     * durumu, erisim engeli, (istenirse) yonetici terfisi, 2FA, cihaz gunlugu, tek cihaz kurali ve jeton uretimi.
     * OAuth girisi yonetici terfisi YAPMAZ ({@code promoteAdmin=false}): ADMIN_EMAILS terfisi yalniz e-posta kodu/parola
     * yolunda; OAuth ile yeni acilan hesap kendiliginden yonetici olmaz. 2FA'li hesapta OAuth girisi de
     * {@link TwoFactorRequiredException} (202) akisina girer.
     */
    public TokenResponse finishLogin(User user, String client, ClientContext ctx, String path, boolean promoteAdmin) {
        requireActive(user);
        // Sifre dogru olduktan sonra kontrol: yanlis sifreyle engel durumu sizdirilmaz
        requireNotBlocked(ctx, user.getId(), path);
        if (promoteAdmin && promoteIfAdmin(user)) {
            users.save(user);
        }
        String c = RefreshTokenService.normalizeClient(client);
        // 2FA: sifre ve engel kontrolleri gecti. Acik + cihaz guvenilir degilse (ya da cihaz basligi yoksa) token
        // URETILMEZ: kod e-postaya gider, 202 challenge doner. Oturum iptali/cihaz gunlugu/yeni giris bildirimi
        // kod dogrulandiktan sonra (completeTwoFactorLogin) calisir.
        if (user.isTwoFactorEnabled()) {
            // Servis yoksa (yalniz yanlis kurulum) 2FA'li hesap kodsuz girmez: fail-closed
            TwoFactorService tf = requireTwoFactorService();
            if (!tf.touchIfTrusted(user.getId(), ctx == null ? null : ctx.deviceHash())) {
                throw new TwoFactorRequiredException(tf.begin(user, ctx, c));
            }
        }
        logDevice(user.getId(), ctx, "LOGIN");
        if (singleMobileSession && RefreshTokenService.MOBILE.equals(c)) {
            sessions.revokeClient(user.getId(), c, true);
        }
        return newSessionTokens(user, c, ctx, true);
    }

    /**
     * 2FA ikinci adimi: challenge + e-posta kodu. Once hesap/engel kontrolleri (kod tuketilmeden), sonra kod;
     * basarida cihaz (istenirse) guvenilir yapilir ve normal girisle ayni sonuc doner (tek cihaz kurali, cihaz
     * gunlugu, yeni giris bildirimi dahil). Challenge tek kullanimliktir.
     */
    public TokenResponse completeTwoFactorLogin(String challengeToken, String code, boolean trustDevice,
                                                ClientContext ctx) {
        TwoFactorService.Challenge ch = requireTwoFactorService().peek(challengeToken);
        User user = loginableUser(ch);
        requireNotBlocked(ctx, user.getId(), "/api/auth/login/2fa");
        // 2FA challenge'tan sonra kapatildiysa (kullanici/yonetici) challenge artik gecersiz
        if (!user.isTwoFactorEnabled()) {
            throw TwoFactorService.challengeExpired();
        }
        twoFactor.verifyAndConsume(challengeToken, ch, code, ctx);
        if (trustDevice) {
            twoFactor.trust(user.getId(), ch.deviceHash(), ch.platform(), ch.appVersion());
        }
        logDevice(user.getId(), ctx, "LOGIN");
        String c = RefreshTokenService.normalizeClient(ch.client());
        if (singleMobileSession && RefreshTokenService.MOBILE.equals(c)) {
            sessions.revokeClient(user.getId(), c, true);
        }
        return newSessionTokens(user, c, ctx, true);
    }

    /** 2FA kodunu ayni challenge icin yeniden gonderir; kalan omur (sn) doner. Sinir controller'da. */
    public long resendTwoFactorCode(String challengeToken, ClientContext ctx) {
        TwoFactorService.Challenge ch = requireTwoFactorService().peek(challengeToken);
        User user = loginableUser(ch);
        requireNotBlocked(ctx, user.getId(), "/api/auth/login/2fa/resend");
        if (!user.isTwoFactorEnabled()) {
            throw TwoFactorService.challengeExpired();
        }
        return twoFactor.resend(challengeToken, ch);
    }

    /** Challenge sahibi hesap hala girebilir mi (dogrulanmis, silinmemis, askida degil)? Degilse challenge gecersiz. */
    private User loginableUser(TwoFactorService.Challenge ch) {
        User user = users.findById(ch.userId()).filter(User::isEmailVerified)
                .orElseThrow(TwoFactorService::challengeExpired);
        requireActive(user);
        return user;
    }

    private TwoFactorService requireTwoFactorService() {
        if (twoFactor == null) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "INTERNAL_ERROR",
                    "Beklenmeyen bir hata oluştu. Lütfen daha sonra tekrar deneyin.");
        }
        return twoFactor;
    }

    /**
     * Sifre degisimi/sifirlama/logout-all: guvenilen cihazlar silinir (sonraki giriste kod istenir), bekleyen kod ve
     * yeni cihaz kilidi temizlenir. Acik giris challenge'lari sifre degisim isaretiyle (`pwchg:`) gecersiz olur.
     */
    private void clearTrustedDevices(Long userId) {
        if (twoFactor != null) {
            twoFactor.onCredentialsChanged(userId);
        }
    }

    /**
     * 2FA etkinlestirme/kapatma sonrasi oturumlar kapatildiysa (closeOtherSessions): bu cihaza yeni jeton cifti.
     * Iptal isareti `iatms <= isaret` token'lari reddeder, yeni token'in iatms'i kesin buyuk olsun (changePassword gibi).
     */
    public TokenResponse reissueTokens(Long userId, String client) {
        return reissueTokens(userId, client, null);
    }

    public TokenResponse reissueTokens(Long userId, String client, ClientContext ctx) {
        User user = users.findById(userId).filter(User::isActive)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "Oturum geçersiz."));
        MilliTick.awaitNext();
        return newSessionTokens(user, client, ctx, false);
    }

    public TokenResponse refresh(String refreshToken) {
        return refresh(refreshToken, null);
    }

    public TokenResponse refresh(String refreshToken, ClientContext ctx) {
        RefreshTokenService.Session s = refresh.consumeSession(refreshToken);
        if (s == null) {
            // Yaniti kaybolan istegin yeniden denemesi (T-007): ayni eski token, kisa pencerede AYNI yeni cifti alir;
            // oturumlar kapanmaz. Cift hala gecerliyse (yeniden donmediyse/iptal edilmediyse) doner.
            TokenResponse again = replayRotation(refreshToken);
            if (again != null) {
                return again;
            }
            if (refresh.rotationInProgress(refreshToken)) {
                // Es zamanli ikinci istek (FIX-P02/K1): ilk istek yeni cifti yaziyor olabilir. Kisa bekleyip kaydi oku;
                // yine yoksa 401 (istemci "oturum bitti" sanip cikis yapar) yerine 409 + Retry-After: istemci tekrar dener.
                for (int i = 0; i < REPLAY_WAIT_TRIES; i++) {
                    sleepQuietly(REPLAY_WAIT_MS);
                    again = replayRotation(refreshToken);
                    if (again != null) {
                        return again;
                    }
                }
                throw new RefreshInProgressException();
            }
            if (refresh.wasRevoked(refreshToken)) {
                // Askiya alma da oturumlari iptal eder: "baska cihazdan giris" yaniltmasi yerine gercek neden (A11-07).
                Long owner = refresh.revokedOwner(refreshToken);
                User u = owner == null ? null : users.findById(owner).orElse(null);
                if (u != null && u.getStatus() == UserStatus.SUSPENDED) {
                    throw new ApiException(HttpStatus.FORBIDDEN, "ACCOUNT_SUSPENDED", "Hesabınız askıya alınmıştır.");
                }
                throw new ApiException(HttpStatus.UNAUTHORIZED, "SESSION_REPLACED",
                        "Hesabınıza başka bir cihazdan giriş yapıldı.");
            }
            // Tuketilmis token tekrar sunuldu (toleransin otesinde): zincirin bir kopyasi calinmis olabilir;
            // hangisinin gercek oldugu bilinemez. Kullanici karari (FIX-P02/K1): YALNIZ bu oturum ailesi kapanir,
            // kullanicinin diger cihazlari/girisleri acik kalir. Aile bilinmiyorsa (eski kayit) guvenli tarafta kalinir.
            java.util.Optional<RefreshTokenService.Reuse> reused = refresh.findReuse(refreshToken);
            if (reused.isPresent()) {
                RefreshTokenService.Reuse r = reused.get();
                if (r.familyKnown()) {
                    int n = refresh.revokeFamily(r.userId(), r.client(), r.authTimeMs());
                    endSessionFamily(r.userId(), r.authTimeMs(), r.sid());
                    log.warn("Refresh token yeniden kullanimi tespit edildi (user {}): oturum ailesi kapatildi ({} token)",
                            r.userId(), n);
                } else {
                    log.warn("Refresh token yeniden kullanimi tespit edildi (user {}, aile bilinmiyor): tum oturumlar kapatiliyor",
                            r.userId());
                    sessions.revokeAll(r.userId());
                }
            }
            throw invalidRefresh();
        }
        User found = users.findById(s.userId()).orElse(null);
        if (found != null && found.getStatus() == UserStatus.SUSPENDED) {
            throw new ApiException(HttpStatus.FORBIDDEN, "ACCOUNT_SUSPENDED", "Hesabınız askıya alınmıştır.");
        }
        if (refresh.isExpired(s) || sessionRevoked(s)) {
            throw invalidRefresh();
        }
        User user = found != null && (found.isEmailVerified() || found.isVerificationDeferred()) && found.isActive()
                ? found : null;
        if (user == null) {
            throw invalidRefresh();
        }
        requireNotBlocked(ctx, user.getId(), "/api/auth/refresh");
        logDevice(user.getId(), ctx, "REFRESH");
        // Oturum kaydi: sid korunur (kayit yoksa/eski zincirse devralinir); kayit hatasi yenilemeyi bozmaz.
        String sid = userSessions == null ? s.sid()
                : userSessions.refreshed(user.getId(), s.sid(), s.client(), s.authTimeMs(), ctx);
        TokenResponse next = tokens(user, s.client(), s.authTimeMs(), sid);
        // Tuketme ile yeni token uretimi arasinda revokeAll araya girdiyse (sifre sifirlama) yeni cift de kapanir;
        // ayni sekilde bu oturum (sid) tek basina iptal edildiyse.
        if (sessionRevoked(s)) {
            refresh.revoke(next.refreshToken());
            throw invalidRefresh();
        }
        refresh.rememberRotation(refreshToken, next.accessToken() + "\n" + next.refreshToken() + "\n"
                + next.expiresInSeconds() + "\n" + next.tokenType());
        return next;
    }

    private static final int REPLAY_WAIT_TRIES = 2;
    private static final long REPLAY_WAIT_MS = 150;

    private static void sleepQuietly(long ms) {
        try {
            Thread.sleep(ms);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    /** Kayitli rotasyon sonucunu (bkz. RefreshTokenService.rememberRotation) cozer; yoksa/gecersizse null. */
    private TokenResponse replayRotation(String oldToken) {
        String payload = refresh.replayRotation(oldToken, p -> {
            String[] f = p.split("\n", 4);
            return f.length == 4 && refresh.peekUserId(f[1]) != null;
        });
        if (payload == null) {
            return null;
        }
        String[] f = payload.split("\n", 4);
        try {
            return new TokenResponse(f[0], f[1], Long.parseLong(f[2]), f[3]);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /** Oturum, acilisindan sonra "tum cihazlardan cik"/sifre degisimi/tek cihaz kuraliyla kapatildi mi (eski token: hayir). */
    private boolean sessionRevoked(RefreshTokenService.Session s) {
        return (s.authTimeMs() > 0 && sessions.isRevokedSince(s.userId(), s.client(), s.authTimeMs()))
                || (s.sid() != null && sessions.isSidRevoked(s.sid()));
    }

    /** Calinti suphesiyle kapanan refresh ailesinin oturum kaydi kapanir; sid biliniyorsa erisim isareti de konur. */
    private void endSessionFamily(Long userId, long authTimeMs, String sid) {
        if (userSessions != null) {
            userSessions.markFamilyRevoked(userId, authTimeMs);
        }
        if (sid != null) {
            sessions.revokeSession(userId, sid);
        }
    }

    private static ApiException invalidRefresh() {
        return new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_REFRESH_TOKEN", "Oturum süresi doldu, tekrar giriş yapın.");
    }

    public void logout(String refreshToken) {
        logout(refreshToken, null);
    }

    /** fcmToken verilirse o cihazin push kaydi da silinir (cikis yapan kullanicinin bildirimi telefonda kalmasin). */
    public void logout(String refreshToken, String fcmToken) {
        Long userId = fcmToken == null || fcmToken.isBlank() ? null : refresh.peekUserId(refreshToken);
        RefreshTokenService.Session ended = refresh.revoke(refreshToken);
        if (userId != null) {
            sessions.deviceLoggedOut(userId, fcmToken.trim());
        }
        // Cok oturum: yalniz bu cihazin oturum kaydi kapanir, access token'i aninda gecersiz olur, o oturumdan
        // kaydolmus push cihazi silinir; kullanicinin diger cihazlari etkilenmez.
        if (ended != null && ended.sid() != null) {
            if (userSessions != null) {
                userSessions.markRevoked(ended.sid());
            }
            sessions.revokeSession(ended.userId(), ended.sid());
        }
    }

    /** Tum cihazlardaki oturumlari kapatir (refresh token'lar + eski access token'lar). */
    public void logoutAll(Long userId) {
        sessions.revokeAll(userId);
        clearTrustedDevices(userId); // 2FA: "tum cihazlardan cik" guvenilen cihazlari da sifirlar
    }

    public UserView me(Long userId) {
        User u = users.findById(userId)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "Oturum geçersiz."));
        return new UserView(u.getId(), u.getEmail(), u.getDisplayName(), u.hasPassword());
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
        // E-posta dogrulanmadan yonetici terfisi YOK (ertelenmis dogrulama hesabi baskasinin adresiyle acilmis olabilir).
        if (user.isEmailVerified() && user.getRole() != Role.ADMIN && admin.isAdminEmail(user.getEmail())) {
            user.setRole(Role.ADMIN);
            user.setAdminProfile(edu.bingol.backend.admin.rbac.AdminProfile.FULL); // ADMIN_EMAILS hesabi her zaman FULL
            return true;
        }
        return false;
    }

    /**
     * YENI giris zinciri: oturum kaydi acilir (sid), token'lar sid'li uretilir. `announce`: yeni cihaz bildirimi
     * tetiklensin mi (yalniz gercek giris; sifre degisimi/2FA sonrasi yeniden duzenleme degil). Kayit servisi yoksa
     * ya da kayit acilamazsa eski bicimde (sid'siz) token verilir.
     */
    private TokenResponse newSessionTokens(User user, String client, ClientContext ctx, boolean announce) {
        String c = RefreshTokenService.normalizeClient(client);
        if (userSessions == null) {
            return tokens(user, c, 0L, null);
        }
        long auth = System.currentTimeMillis();
        String sid = userSessions.open(user.getId(), c, auth, ctx, announce);
        return tokens(user, c, auth, sid);
    }

    /** `authTimeMs` > 0 ise rotasyondur: oturumun ilk giris ani korunur (mutlak omur + iptal karsilastirmasi). */
    private TokenResponse tokens(User user, String client, long authTimeMs, String sid) {
        String c = RefreshTokenService.normalizeClient(client);
        String rt = sid != null ? refresh.issue(user.getId(), c, authTimeMs, sid)
                : authTimeMs > 0 ? refresh.issue(user.getId(), c, authTimeMs) : refresh.issue(user.getId(), c);
        String at = sid != null ? jwt.createAccessToken(user, c, sid) : jwt.createAccessToken(user, c);
        TokenResponse t = new TokenResponse(at, rt, jwt.accessTtl().toSeconds(), "Bearer");
        return user.isVerificationDeferred() && !user.isEmailVerified() ? t.asDeferred() : t;
    }

    // ---------------------------------------------------------------- ertelenmis dogrulamayi tamamlama (JWT'li)

    public VerificationDtos.StatusResponse verificationStatus(Long userId) {
        User u = loadSelf(userId);
        return new VerificationDtos.StatusResponse(u.isEmailVerified(), u.isVerificationDeferred() && !u.isEmailVerified(),
                u.getEmail());
    }

    /**
     * Giris yapmis dogrulanmamis hesaba dogrulama kodu gonderir. Kota korumasi uygulanir (doluysa 429
     * MAIL_QUOTA_EXCEEDED + Retry-After), 180 sn bekleme (429 RESEND_COOLDOWN). Zaten dogrulanmissa 409.
     */
    public void resendOwnVerification(Long userId) {
        User u = loadSelf(userId);
        if (u.isEmailVerified()) {
            throw new ApiException(HttpStatus.CONFLICT, "EMAIL_ALREADY_VERIFIED", "E-posta adresiniz zaten doğrulanmış.");
        }
        verification.requireVerificationQuota();
        verification.issue(u.getEmail(), Lang.of(u.getLanguage()));
    }

    /** Kod dogruysa emailVerified=true, verificationDeferred=false (idempotent); yanlis/suresi dolmus 400 INVALID_CODE. */
    public VerificationDtos.VerifiedResponse verifyOwnEmail(Long userId, String code, String scope) {
        User u = loadSelf(userId);
        if (u.isEmailVerified()) {
            return new VerificationDtos.VerifiedResponse(true, false);
        }
        boolean ok = scope == null ? verification.verify(u.getEmail(), code.trim())
                : verification.verify(u.getEmail(), code.trim(), scope);
        if (!ok) {
            throw invalidCode();
        }
        u.setEmailVerified(true);
        u.setVerificationDeferred(false);
        users.save(u);
        accounts.joinDepartmentAfterVerification(u);
        return new VerificationDtos.VerifiedResponse(true, false);
    }

    private User loadSelf(Long userId) {
        return users.findById(userId).filter(User::isActive)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "Oturum geçersiz."));
    }

    /** BCrypt yalniz ilk 72 BAYT'i kullanir (ustu istisna); karakter degil bayt sayilir (Turkce/Arapca/emoji). */
    static boolean fitsBcrypt(String password) {
        return password != null && password.getBytes(StandardCharsets.UTF_8).length <= 72;
    }

    private static void requirePasswordBytes(String password) {
        if (!fitsBcrypt(password)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "PASSWORD_TOO_LONG",
                    "Şifre çok uzun (en fazla 72 bayt; Türkçe/Arapça karakterler birden çok bayt tutar).");
        }
    }
}
