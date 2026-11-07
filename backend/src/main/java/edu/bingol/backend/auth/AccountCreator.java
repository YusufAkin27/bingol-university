package edu.bingol.backend.auth;

import edu.bingol.backend.auth.token.PendingRegistrationStore.Pending;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.legal.LegalService;
import edu.bingol.backend.profile.privacy.ProfilePrivacy;
import edu.bingol.backend.profile.privacy.ProfilePrivacyRepository;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Dogrulanan kaydin hesabini olusturur. Ayri bean: @Transactional AuthService icinden self-invocation ile
 * calismazdi. Kullanici + sozlesme onayi tek transaction'dadir; biri duserse ikisi de geri alinir.
 */
@Component
public class AccountCreator {

    private final UserRepository users;
    private final LegalService legal;
    private final AdminProperties admin;

    /** Ihlal defteri (istege bagli: defter olmadan kurulan testler icin). */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private edu.bingol.backend.moderation.ViolationLedgerService ledger;

    /** Gizlilik ayarlari (istege bagli: depo olmadan kurulan birim testleri icin). */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private ProfilePrivacyRepository privacy;

    /** Yeni hesaplar HERKESE ACIK acilir (kullanici karari 2026-11-07); true yapilirsa gizli acilir. Kullanici ayarlardan gizliye alir. */
    @org.springframework.beans.factory.annotation.Value("${app.profile.default-private-account:false}")
    private boolean defaultPrivateAccount;

    /** OAuth ayarlari (istege bagli): parola ile kaydolanlar da profil tamamlama kapisindan gecsin mi. */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private edu.bingol.backend.auth.oauth.OAuthProperties oauthProps;

    /** Yeni role (Apple gizli e-posta) hesabini gercek e-posta dogrulanana kadar kapida tut (kolay kapatma: bayrak). */
    @org.springframework.beans.factory.annotation.Value("${app.auth.real-email-gate.enabled:true}")
    private boolean realEmailGateEnabled = true;

    public AccountCreator(UserRepository users, LegalService legal, AdminProperties admin) {
        this.users = users;
        this.legal = legal;
        this.admin = admin;
    }

    /** E-posta KODU dogrulamasiyla gelen kayit: ADMIN_EMAILS adresi yonetici (FULL) olur. */
    @Transactional
    public User create(String email, Pending p) {
        return create(email, p, true);
    }

    /**
     * `promoteAdmin=false`: e-posta sahipligi KODLA kanitlanmadan (yonetici elle dogrulama) acilan hesap ADMIN_EMAILS
     * terfisi almaz (T-011); sabit FULL yonetici yalniz kodlu dogrulamayla olusur.
     */
    @Transactional
    public User create(String email, Pending p, boolean promoteAdmin) {
        return save(email, p, promoteAdmin, false);
    }

    /**
     * Kota asiminda ERTELENMIS dogrulama (QT-BE): e-posta KODLA kanitlanmadan acilan hesap. emailVerified=false,
     * verificationDeferred=true; ADMIN_EMAILS terfisi YOK (kimlik taklidiyle yonetici olunamaz). Sozlesme onayi,
     * gizlilik varsayilani ve ihlal defteri devri normal hesapla ayni.
     */
    @Transactional
    public User createDeferred(String email, Pending p) {
        return save(email, p, false, true);
    }

    private User save(String email, Pending p, boolean promoteAdmin, boolean deferred) {
        User user = users.findByEmail(email).orElseGet(User::new);
        user.setEmail(email);
        user.setPasswordHash(p.passwordHash());
        user.setDisplayName(p.displayName());
        user.setLanguage(p.language());
        user.setFaculty(p.faculty());
        user.setDepartment(p.department());
        user.setGrade(p.grade());
        user.setEmailVerified(!deferred);
        user.setVerificationDeferred(deferred);
        if (deferred) {
            user.setVerificationMailedAt(null);
        }
        if (promoteAdmin && user.getRole() != Role.ADMIN && admin.isAdminEmail(email)) {
            user.setRole(Role.ADMIN);
            user.setAdminProfile(edu.bingol.backend.admin.rbac.AdminProfile.FULL); // ADMIN_EMAILS hesabi her zaman FULL
        }
        boolean fresh = user.getId() == null;
        if (fresh && oauthProps != null && oauthProps.passwordSignupsNeedOnboarding()) {
            user.setProfileCompletedAt(null); // yeni parola kaydi da onboarding'den gecsin (varsayilan: gecmez)
        }
        user = users.saveAndFlush(user);
        legal.recordSignupConsent(user.getId());
        defaultsForNewAccount(user, fresh, email);
        return user;
    }

    /**
     * Google/Apple ile ilk giriste hesap acar (e-posta SAGLAYICIDA dogrulanmis; parola yok; profil tamamlanmamis).
     * Sozlesme onayi BURADA yazilmaz: onboarding'de ({@code acceptTerms}) kaydedilir. ADMIN_EMAILS terfisi yok.
     * Gizlilik varsayilani ve ihlal defteri devri parola kaydiyla ayni.
     */
    @Transactional
    public User createFromOAuth(String email, String displayName, String firstName, String lastName, String language) {
        return createFromOAuth(email, displayName, firstName, lastName, language, false);
    }

    /**
     * `relay=true`: e-posta Apple "E-postami gizle" role adresi. Hesap acilir ama {@code emailRelay} + (bayrak aciksa)
     * {@code realEmailRequired} isaretlenir: gercek e-posta kodla dogrulanana kadar yazma uclari kapali (REAL_EMAIL_REQUIRED).
     */
    @Transactional
    public User createFromOAuth(String email, String displayName, String firstName, String lastName, String language,
                                boolean relay) {
        User user = new User();
        user.setEmailRelay(relay);
        user.setRealEmailRequired(relay && realEmailGateEnabled);
        user.setEmail(email);
        user.setPasswordHash(User.NO_PASSWORD_PREFIX + java.util.UUID.randomUUID());
        user.setDisplayName(displayName);
        user.setFirstName(firstName);
        user.setLastName(lastName);
        user.setLanguage(language);
        user.setEmailVerified(true);
        user.setVerificationDeferred(false);
        user.setProfileCompletedAt(null);
        user = users.saveAndFlush(user);
        defaultsForNewAccount(user, true, email);
        return user;
    }

    private void defaultsForNewAccount(User user, boolean fresh, String email) {
        if (fresh && defaultPrivateAccount && privacy != null && !privacy.existsById(user.getId())) {
            ProfilePrivacy settings = ProfilePrivacy.defaults(user.getId());
            settings.setPrivateAccount(true);
            privacy.save(settings);
        }
        // Silinip ayni e-postayla yeniden kayit: ihlal defterindeki strike'lar devralinir (T-058)
        if (fresh && ledger != null) {
            ledger.inheritOnRegister(user.getId(), email);
        }
    }
}
