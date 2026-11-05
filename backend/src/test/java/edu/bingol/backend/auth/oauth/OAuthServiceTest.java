package edu.bingol.backend.auth.oauth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.auth.AccountCreator;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.PlatformTransactionManager;

/**
 * Giris/baglama is kurallari (H2 + gercek depolar; saglayici token'lari YEREL RSA anahtariyla uretilir, ag yok):
 * yeni kullanici, saglayici kimligiyle eslesme, e-posta cakismasinda OTOMATIK BIRLESME YOK (409 OAUTH_LINK_REQUIRED),
 * baglama (yeniden dogrulama), baglama kaldirma son yontem korumasi, Apple gizli e-posta.
 */
@SpringBootTest
class OAuthServiceTest {

    @Autowired AuthIdentityRepository identities;
    @Autowired UserRepository users;
    @Autowired AccountCreator accounts;
    @Autowired PasswordEncoder encoder;
    @Autowired PlatformTransactionManager tm;
    @Autowired org.springframework.jdbc.core.JdbcTemplate jdbc;

    final OAuthTestSupport t = new OAuthTestSupport();
    OAuthService svc;
    String tag;

    @BeforeEach
    void setUp() {
        svc = new OAuthService(t.props, t.verifier, identities, users, accounts, encoder);
        svc.setTxManager(tm);
        tag = UUID.randomUUID().toString().substring(0, 8);
    }

    private String email(String name) {
        return name + "." + tag + "@gmail.com";
    }

    private String googleToken(String sub, String email) {
        return t.sign(t.googleClaims(sub, email));
    }

    private User passwordUser(String email, String password) {
        User u = new User();
        u.setEmail(email);
        u.setPasswordHash(encoder.encode(password));
        u.setDisplayName("Mevcut Kisi");
        u.setEmailVerified(true);
        return users.save(u);
    }

    private static String code(Runnable r) {
        return assertThrows(ApiException.class, r::run).code();
    }

    // ------------------------------------------------------------------ yeni kullanici

    @Test
    void firstGoogleLoginCreatesAVerifiedPasswordlessIncompleteAccountWithPrefilledName() {
        String em = email("yeni");
        OAuthService.SignIn s = svc.signInGoogle(googleToken("g-" + tag, em));

        assertTrue(s.isNew());
        User u = users.findById(s.user().getId()).orElseThrow();
        assertEquals(em, u.getEmail());
        assertTrue(u.isEmailVerified());
        assertFalse(u.isVerificationDeferred());
        assertFalse(u.isProfileCompleted(), "profil tamamlanmadi: sunucu kapisi yazmayi keser");
        assertFalse(u.hasPassword(), "parola girisi kapali");
        assertTrue(u.getPasswordHash().startsWith(User.NO_PASSWORD_PREFIX));
        assertEquals("Ayşe", u.getFirstName());
        assertEquals("Yılmaz", u.getLastName());
        assertEquals("Ayşe Yılmaz", u.getDisplayName());
        assertNull(u.getUsername());
        assertEquals(edu.bingol.backend.user.Role.USER, u.getRole());
        AuthIdentity id = identities.findByProviderAndSubject(OAuthProvider.GOOGLE, "g-" + tag).orElseThrow();
        assertEquals(u.getId(), id.getUserId());
        assertEquals(em, id.getEmail());
    }

    @Test
    void secondLoginWithTheSameSubjectFindsTheSameAccountEvenIfTheProviderEmailChanged() {
        OAuthService.SignIn first = svc.signInGoogle(googleToken("g2-" + tag, email("a")));
        OAuthService.SignIn second = svc.signInGoogle(googleToken("g2-" + tag, email("degisti")));

        assertFalse(second.isNew());
        assertEquals(first.user().getId(), second.user().getId());
        // hesabin kendi e-postasi saglayici e-postasi degisti diye DEGISMEZ
        assertEquals(email("a"), users.findById(first.user().getId()).orElseThrow().getEmail());
        assertEquals(1, identities.countByUserId(first.user().getId()));
    }

    @Test
    void existingCompletedUserWithLinkedIdentityLogsInDirectlyAndStaysComplete() {
        User existing = passwordUser(email("tamam"), "Kx7-mQ2vLp9z");
        AuthIdentity id = new AuthIdentity();
        id.setUserId(existing.getId());
        id.setProvider(OAuthProvider.GOOGLE);
        id.setSubject("g3-" + tag);
        identities.save(id);

        OAuthService.SignIn s = svc.signInGoogle(googleToken("g3-" + tag, existing.getEmail()));

        assertFalse(s.isNew());
        assertEquals(existing.getId(), s.user().getId());
        assertTrue(s.user().isProfileCompleted(), "mevcut kullanici etkilenmez");
        assertTrue(s.user().hasPassword());
    }

    // ------------------------------------------------------------------ otomatik birlesme YOK

    @Test
    void sameEmailAsAnExistingAccountNeverAutoMerges() {
        User existing = passwordUser(email("var"), "Kx7-mQ2vLp9z");
        long usersBefore = users.count();

        OAuthLinkRequiredException ex = assertThrows(OAuthLinkRequiredException.class,
                () -> svc.signInGoogle(googleToken("g4-" + tag, existing.getEmail())));

        assertEquals("OAUTH_LINK_REQUIRED", ex.code());
        assertEquals(409, ex.status().value());
        Map<String, String> extra = ex.extraBody();
        assertEquals("GOOGLE", extra.get("provider"));
        assertTrue(extra.get("emailMasked").startsWith("v***@"), extra.get("emailMasked"));
        assertFalse(extra.get("emailMasked").contains(existing.getEmail().substring(0, existing.getEmail().indexOf('@'))));
        assertEquals(usersBefore, users.count(), "yeni hesap acilmadi");
        assertTrue(identities.findByProviderAndSubject(OAuthProvider.GOOGLE, "g4-" + tag).isEmpty(), "kimlik baglanmadi");
        assertEquals(0, identities.countByUserId(existing.getId()));
    }

    @Test
    void emailCollisionAlsoAppliesToUnverifiedAndAppleAccounts() {
        User unverified = new User();
        unverified.setEmail(email("dogrulanmamis"));
        unverified.setPasswordHash(encoder.encode("Kx7-mQ2vLp9z"));
        unverified.setDisplayName("D");
        unverified.setEmailVerified(false);
        users.save(unverified);

        assertEquals("OAUTH_LINK_REQUIRED", code(() -> svc.signInGoogle(googleToken("g5-" + tag, unverified.getEmail()))));
        String apple = t.sign(t.appleClaims("a5-" + tag, unverified.getEmail(), "n5"));
        assertEquals("OAUTH_LINK_REQUIRED", code(() -> svc.signInApple(apple, "n5", null, null)));
    }

    // ------------------------------------------------------------------ Apple

    @Test
    void applePrivateRelayEmailCreatesAccountAndClientNameIsStored() {
        String relay = "x" + tag + "@privaterelay.appleid.com";
        String token = t.sign(t.appleClaims("a1-" + tag, relay, "nonce-1"));

        OAuthService.SignIn s = svc.signInApple(token, "nonce-1", "Mehmet", "Demir");

        assertTrue(s.isNew());
        User u = users.findById(s.user().getId()).orElseThrow();
        assertEquals(relay, u.getEmail());
        assertEquals("Mehmet", u.getFirstName());
        assertEquals("Demir", u.getLastName());
        assertEquals("Mehmet Demir", u.getDisplayName());
        AuthIdentity id = identities.findByProviderAndSubject(OAuthProvider.APPLE, "a1-" + tag).orElseThrow();
        assertTrue(id.isEmailIsPrivate());
    }

    @Test
    void appleWithoutEmailMatchesByProviderSubjectButCannotCreateAnAccount() {
        // ilk giris (e-posta var) hesap acar
        String first = t.sign(t.appleClaims("a2-" + tag, "ilk" + tag + "@privaterelay.appleid.com", "n1"));
        User created = svc.signInApple(first, "n1", null, null).user();

        // sonraki giris: Apple e-posta GONDERMEZ; saglayici kimligiyle ayni hesap
        String later = t.sign(t.appleClaims("a2-" + tag, null, "n2"));
        OAuthService.SignIn s = svc.signInApple(later, "n2", null, null);
        assertFalse(s.isNew());
        assertEquals(created.getId(), s.user().getId());

        // tanimadigi kimlik + e-posta yok: hesap acilamaz
        String stranger = t.sign(t.appleClaims("a-yabanci-" + tag, null, "n3"));
        assertEquals("OAUTH_EMAIL_MISSING", code(() -> svc.signInApple(stranger, "n3", null, null)));
        assertTrue(identities.findByProviderAndSubject(OAuthProvider.APPLE, "a-yabanci-" + tag).isEmpty());
    }

    @Test
    void appleUsersWithoutAnyNameGetTheTemporaryDisplayName() {
        String token = t.sign(t.appleClaims("a3-" + tag, "isimsiz" + tag + "@privaterelay.appleid.com", "n"));
        User u = svc.signInApple(token, "n", null, null).user();
        assertNotNull(u.getDisplayName());
        assertTrue(u.getDisplayName().length() >= 2);
        assertNull(u.getFirstName());
    }

    // ------------------------------------------------------------------ bayrak

    @Test
    void featureFlagOffMakesEveryEntryPoint404() {
        OAuthTestSupport off = new OAuthTestSupport(false);
        OAuthService disabled = new OAuthService(off.props, off.verifier, identities, users, accounts, encoder);

        for (Runnable r : new Runnable[] {
                () -> disabled.signInGoogle("x"), () -> disabled.signInApple("x", "n", null, null),
                () -> disabled.link(1L, OAuthProvider.GOOGLE, "x", null, "p", null, null, null),
                () -> disabled.unlink(1L, OAuthProvider.GOOGLE), () -> disabled.identitiesOf(1L)}) {
            ApiException e = assertThrows(ApiException.class, r::run);
            assertEquals("OAUTH_DISABLED", e.code());
            assertEquals(404, e.status().value());
        }
    }

    // ------------------------------------------------------------------ baglama (link)

    @Test
    void linkRequiresTheCurrentPasswordAndBindsTheProviderIdentity() {
        User me = passwordUser(email("baglayan"), "Kx7-mQ2vLp9z");
        String token = googleToken("gl-" + tag, "baska.hesap." + tag + "@gmail.com");

        assertEquals("WRONG_PASSWORD", code(() -> svc.link(me.getId(), OAuthProvider.GOOGLE, token, null, "yanlis-parola", null, null, null)));
        assertEquals("WRONG_PASSWORD", code(() -> svc.link(me.getId(), OAuthProvider.GOOGLE, token, null, null, null, null, null)));
        assertEquals(0, identities.countByUserId(me.getId()), "yanlis parolada baglanmadi");

        svc.link(me.getId(), OAuthProvider.GOOGLE, token, null, "Kx7-mQ2vLp9z", null, null, null);

        assertEquals(me.getId(), identities.findByProviderAndSubject(OAuthProvider.GOOGLE, "gl-" + tag).orElseThrow().getUserId());
        // sonraki Google girisi artik bu hesaba gider (e-posta farkli olsa da)
        assertEquals(me.getId(), svc.signInGoogle(token).user().getId());
        // ayni baglama tekrari idempotent
        svc.link(me.getId(), OAuthProvider.GOOGLE, token, null, "Kx7-mQ2vLp9z", null, null, null);
        assertEquals(1, identities.countByUserId(me.getId()));
    }

    @Test
    void linkRejectsASubjectBoundToAnotherAccountAndASecondIdentityOfTheSameProvider() {
        User owner = passwordUser(email("sahip"), "Kx7-mQ2vLp9z");
        User other = passwordUser(email("diger"), "Kx7-mQ2vLp9z");
        svc.link(owner.getId(), OAuthProvider.GOOGLE, googleToken("gx-" + tag, "p" + tag + "@gmail.com"), null,
                "Kx7-mQ2vLp9z", null, null, null);

        String sameSub = googleToken("gx-" + tag, "p" + tag + "@gmail.com");
        assertEquals("OAUTH_IDENTITY_TAKEN", code(() -> svc.link(other.getId(), OAuthProvider.GOOGLE, sameSub, null,
                "Kx7-mQ2vLp9z", null, null, null)));
        assertEquals(0, identities.countByUserId(other.getId()));

        String anotherGoogle = googleToken("gy-" + tag, "q" + tag + "@gmail.com");
        assertEquals("OAUTH_PROVIDER_ALREADY_LINKED", code(() -> svc.link(owner.getId(), OAuthProvider.GOOGLE, anotherGoogle,
                null, "Kx7-mQ2vLp9z", null, null, null)));
    }

    @Test
    void linkWithAnInvalidProviderTokenIsRejected() {
        User me = passwordUser(email("gecersiz"), "Kx7-mQ2vLp9z");
        assertEquals("OAUTH_TOKEN_INVALID", code(() -> svc.link(me.getId(), OAuthProvider.GOOGLE, "sahte.token.degeri", null,
                "Kx7-mQ2vLp9z", null, null, null)));
    }

    @Test
    void passwordlessAccountReauthenticatesWithItsLinkedProviderToLinkAnotherOne() {
        OAuthService.SignIn s = svc.signInGoogle(googleToken("gp-" + tag, email("parolasiz")));
        Long uid = s.user().getId();
        String apple = t.sign(t.appleClaims("ap-" + tag, "yeni" + tag + "@privaterelay.appleid.com", "nl"));

        // yeniden dogrulama yok: reddedilir
        assertEquals("OAUTH_REAUTH_REQUIRED", code(() -> svc.link(uid, OAuthProvider.APPLE, apple, "nl", null, null, null, null)));
        // BASKASININ Google token'i ile yeniden dogrulama olmaz
        String stranger = googleToken("baska-sub-" + tag, "z" + tag + "@gmail.com");
        assertEquals("OAUTH_REAUTH_REQUIRED", code(() -> svc.link(uid, OAuthProvider.APPLE, apple, "nl", null,
                OAuthProvider.GOOGLE, stranger, null)));
        // kendi Google token'i ile olur
        svc.link(uid, OAuthProvider.APPLE, apple, "nl", null, OAuthProvider.GOOGLE, googleToken("gp-" + tag, email("parolasiz")), null);
        assertEquals(2, identities.countByUserId(uid));
    }

    // ------------------------------------------------------------------ baglama kaldirma

    @Test
    void unlinkProtectsTheLastLoginMethod() {
        // yalniz OAuth hesabi: tek kimlik kaldirilamaz
        Long onlyOauth = svc.signInGoogle(googleToken("gu-" + tag, email("tek"))).user().getId();
        assertEquals("OAUTH_LAST_LOGIN_METHOD", code(() -> svc.unlink(onlyOauth, OAuthProvider.GOOGLE)));
        assertEquals(1, identities.countByUserId(onlyOauth));

        // iki kimlik: biri kaldirilabilir, kalan son olur
        svc.link(onlyOauth, OAuthProvider.APPLE, t.sign(t.appleClaims("au-" + tag, "u" + tag + "@privaterelay.appleid.com", "n")),
                "n", null, OAuthProvider.GOOGLE, googleToken("gu-" + tag, email("tek")), null);
        svc.unlink(onlyOauth, OAuthProvider.APPLE);
        assertEquals("OAUTH_LAST_LOGIN_METHOD", code(() -> svc.unlink(onlyOauth, OAuthProvider.GOOGLE)));

        // parolasi olan hesap tek kimligi kaldirabilir
        User withPassword = passwordUser(email("parolali"), "Kx7-mQ2vLp9z");
        svc.link(withPassword.getId(), OAuthProvider.GOOGLE, googleToken("gv-" + tag, "v" + tag + "@gmail.com"), null,
                "Kx7-mQ2vLp9z", null, null, null);
        svc.unlink(withPassword.getId(), OAuthProvider.GOOGLE);
        assertEquals(0, identities.countByUserId(withPassword.getId()));
        assertEquals("OAUTH_IDENTITY_NOT_FOUND", code(() -> svc.unlink(withPassword.getId(), OAuthProvider.GOOGLE)));
    }

    @Test
    void identitiesListsLinkedProviders() {
        Long uid = svc.signInGoogle(googleToken("gi-" + tag, email("liste"))).user().getId();
        var list = svc.identitiesOf(uid);
        assertEquals(1, list.size());
        assertEquals("GOOGLE", list.get(0).provider());
        assertEquals(email("liste"), list.get(0).email());
        assertEquals(java.util.List.of("GOOGLE"), svc.providersOf(uid));
    }

    // ------------------------------------------------------------------ silinmis/askida

    @Test
    void identityOfADeletedAccountIsRejectedAndSuspendedAccountsStillResolve() {
        Long uid = svc.signInGoogle(googleToken("gd-" + tag, email("silinecek"))).user().getId();
        User u = users.findById(uid).orElseThrow();
        u.setStatus(UserStatus.DELETED);
        users.save(u);

        assertEquals("INVALID_CREDENTIALS", code(() -> svc.signInGoogle(googleToken("gd-" + tag, email("silinecek")))));
        // kimlik baska hesaba kayamaz: ayni sub icin yeni hesap acilmaz
        assertNotEquals(0, identities.countByUserId(uid));
    }

    @Test
    void accountDeletionPurgerRemovesTheIdentityRows() {
        Long uid = svc.signInGoogle(googleToken("gdel-" + tag, email("kvkk"))).user().getId();
        assertEquals(1, identities.countByUserId(uid));

        String sql = edu.bingol.backend.profile.AccountDataPurger.DELETES.stream()
                .filter(x -> x.startsWith("DELETE FROM auth_identity ")).findFirst().orElseThrow();
        jdbc.update(sql, uid);

        assertEquals(0, identities.countByUserId(uid));
        // ayni saglayici kimligiyle donus: eski hesap degil, YENI hesap (e-posta yine bos: yeni kullanici)
        OAuthService.SignIn back = svc.signInGoogle(googleToken("gdel-" + tag, email("kvkk2")));
        assertTrue(back.isNew());
        assertNotEquals(uid, back.user().getId());
    }
}
