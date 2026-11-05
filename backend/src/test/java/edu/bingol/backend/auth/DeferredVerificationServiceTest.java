package edu.bingol.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.accessban.ClientContext;
import edu.bingol.backend.auth.dto.TokenResponse;
import edu.bingol.backend.auth.dto.VerificationDtos;
import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.auth.token.PendingRegistrationStore;
import edu.bingol.backend.auth.token.PendingRegistrationStore.Pending;
import edu.bingol.backend.auth.token.RefreshTokenService;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.auth.token.VerificationService;
import edu.bingol.backend.catalog.CatalogService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimitedException;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Duration;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

/**
 * Kota asiminda ERTELENMIS e-posta dogrulama (QT-BE): kayit, giris, jeton isaretleri, kimlik taklidi korumalari ve
 * JWT'li dogrulama uclari (servis katmani).
 */
class DeferredVerificationServiceTest {

    private static final String EMAIL = "ali@bingol.edu.tr";
    private static final String ADMIN_GMAIL = "ops.admin@gmail.com";
    private static final String PW = "Kx7-mQ2vLp9z";

    private final UserRepository users = mock(UserRepository.class);
    private final VerificationService verification = mock(VerificationService.class);
    private final PendingRegistrationStore pending = mock(PendingRegistrationStore.class);
    private final SessionService sessions = mock(SessionService.class);
    private final AccountCreator accounts = mock(AccountCreator.class);
    private final JwtService jwt = mock(JwtService.class);
    private final RefreshTokenService refresh = mock(RefreshTokenService.class);
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder(4);

    private final AuthService auth = new AuthService(users, encoder, jwt, refresh, verification,
            new AdminProperties(List.of(ADMIN_GMAIL)), accounts, pending, sessions, new CatalogService());

    private static ApiException quotaExhausted() {
        return new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "MAIL_QUOTA_EXHAUSTED", "x");
    }

    @BeforeEach
    void setUp() {
        when(jwt.accessTtl()).thenReturn(Duration.ofMinutes(15));
        when(jwt.createAccessToken(any(User.class), anyString())).thenReturn("at");
        when(refresh.issue(any(Long.class), anyString())).thenReturn("rt");
        when(users.findByEmail(anyString())).thenReturn(Optional.empty());
        when(accounts.createDeferred(anyString(), any(Pending.class))).thenAnswer(i -> {
            User u = new User();
            u.setId(41L);
            u.setEmail(i.getArgument(0, String.class));
            u.setVerificationDeferred(true);
            return u;
        });
    }

    private TokenResponse register(String email) {
        return auth.registerOrDefer(email, PW, "Ali", Lang.TR, null, null, null, false, "mobile", (ClientContext) null);
    }

    // ------------------------------------------------------------------ kayit

    @Test
    void registerWhenQuotaIsFullOpensDeferredAccountAndReturnsTokensFlaggedUnverified() {
        doThrow(quotaExhausted()).when(verification).requireMailQuota();

        TokenResponse t = register(EMAIL);

        assertNotNull(t);
        assertEquals("at", t.accessToken());
        assertEquals("rt", t.refreshToken());
        assertEquals(Boolean.FALSE, t.emailVerified());
        assertEquals(Boolean.TRUE, t.verificationDeferred());
        verify(accounts).createDeferred(eq(EMAIL), any(Pending.class));
        verify(pending).delete(EMAIL);
        verify(verification, never()).issue(anyString(), any()); // kota dolu: kod GITMEZ
        verify(pending, never()).save(anyString(), any(Pending.class)); // bekleyen kayit yok
        verify(sessions, never()).revokeAll(any()); // yeni satir: kapatilacak oturum yok
    }

    @Test
    void registerWhenQuotaHasRoomKeepsTheOldFlowUnchanged() {
        TokenResponse t = register(EMAIL);

        assertNull(t);
        verify(verification).issue(EMAIL, Lang.TR);
        verify(pending).save(eq(EMAIL), any(Pending.class));
        verify(accounts, never()).createDeferred(anyString(), any());
    }

    @Test
    void legacyRegisterMethodStillThrowsTheQuotaError() {
        doThrow(quotaExhausted()).when(verification).requireMailQuota();

        ApiException e = assertThrows(ApiException.class, () -> auth.register(EMAIL, PW, "Ali", Lang.TR));

        assertEquals("MAIL_QUOTA_EXHAUSTED", e.code());
        verify(accounts, never()).createDeferred(anyString(), any());
    }

    @Test
    void domainRulesStillApplyBeforeTheDeferral() {
        doThrow(quotaExhausted()).when(verification).requireMailQuota();

        ApiException e = assertThrows(ApiException.class, () -> register("kisi@gmail.com"));
        assertEquals("EMAIL_DOMAIN_NOT_ALLOWED", e.code());
        ApiException alias = assertThrows(ApiException.class, () -> register("ali+1@bingol.edu.tr"));
        assertEquals("EMAIL_ALIAS_NOT_ALLOWED", alias.code());
        ApiException weak = assertThrows(ApiException.class,
                () -> auth.registerOrDefer(EMAIL, "123", "Ali", Lang.TR, null, null, null, false, null, null));
        assertEquals("PASSWORD_TOO_SHORT", weak.code());
        verify(accounts, never()).createDeferred(anyString(), any());
    }

    @Test
    void adminEmailsAndAdminPortalAreNeverDeferred() {
        doThrow(quotaExhausted()).when(verification).requireMailQuota();

        ApiException admin = assertThrows(ApiException.class, () -> auth.registerOrDefer(ADMIN_GMAIL, "Kx7-mQ2vLp9z-Aa", "Ops",
                Lang.TR, null, null, null, false, null, null));
        assertEquals("MAIL_QUOTA_EXHAUSTED", admin.code());
        ApiException portal = assertThrows(ApiException.class, () -> auth.registerOrDefer(EMAIL, PW, "Ali", Lang.TR,
                null, null, null, true, null, null));
        assertEquals("MAIL_QUOTA_EXHAUSTED", portal.code());
        verify(accounts, never()).createDeferred(anyString(), any());
    }

    @Test
    void otherMailErrorsAreNotDeferred() {
        doThrow(new RateLimitedException(600)).when(verification).requireMailQuota(); // IP gunluk sayaci

        assertThrows(RateLimitedException.class, () -> register(EMAIL));
        verify(accounts, never()).createDeferred(anyString(), any());
    }

    @Test
    void featureFlagOffRestoresTheOldBehaviour() {
        doThrow(quotaExhausted()).when(verification).requireMailQuota();
        AuthService off = new AuthService(users, encoder, jwt, refresh, verification, new AdminProperties(List.of()),
                accounts, pending, sessions, new CatalogService());
        org.springframework.test.util.ReflectionTestUtils.setField(off, "deferredVerificationEnabled", false);

        ApiException e = assertThrows(ApiException.class,
                () -> off.registerOrDefer(EMAIL, PW, "Ali", Lang.TR, null, null, null, false, null, null));
        assertEquals("MAIL_QUOTA_EXHAUSTED", e.code());
    }

    @Test
    void alreadyVerifiedEmailStillGets409() {
        doThrow(quotaExhausted()).when(verification).requireMailQuota();
        User verified = new User();
        verified.setEmailVerified(true);
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(verified));

        ApiException e = assertThrows(ApiException.class, () -> register(EMAIL));

        assertEquals("EMAIL_ALREADY_REGISTERED", e.code());
        verify(accounts, never()).createDeferred(anyString(), any());
    }

    @Test
    void reRegisteringOverAnUnverifiedRowReusesItAndClosesTheOldSessions() {
        doThrow(quotaExhausted()).when(verification).requireMailQuota();
        User squatter = new User();
        squatter.setId(41L);
        squatter.setEmail(EMAIL);
        squatter.setVerificationDeferred(true);
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(squatter));

        TokenResponse t = register(EMAIL);

        assertEquals(Boolean.TRUE, t.verificationDeferred());
        verify(sessions).revokeAll(41L); // onceki kayit acanin oturumlari kapanir
    }

    // ------------------------------------------------------------------ giris

    private User row(boolean verified, boolean deferred) {
        User u = new User();
        u.setId(41L);
        u.setEmail(EMAIL);
        u.setPasswordHash(encoder.encode(PW));
        u.setEmailVerified(verified);
        u.setVerificationDeferred(deferred);
        return u;
    }

    @Test
    void deferredAccountCanLoginAndGetsTheFlags() {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(row(false, true)));

        TokenResponse t = auth.login(EMAIL, PW, "mobile", null);

        assertEquals(Boolean.FALSE, t.emailVerified());
        assertEquals(Boolean.TRUE, t.verificationDeferred());
    }

    @Test
    void normalLoginHasNoExtraFlags() {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(row(true, false)));

        TokenResponse t = auth.login(EMAIL, PW, "web", null);

        assertNull(t.emailVerified());
        assertNull(t.verificationDeferred());
    }

    @Test
    void otherUnverifiedRowsStillGetEmailNotVerified() {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(row(false, false)));

        ApiException e = assertThrows(ApiException.class, () -> auth.login(EMAIL, PW, "web", null));

        assertEquals("EMAIL_NOT_VERIFIED", e.code());
    }

    @Test
    void unverifiedAdminEmailIsNeverPromotedAtLogin() {
        User u = row(false, true);
        u.setEmail(ADMIN_GMAIL);
        when(users.findByEmail(ADMIN_GMAIL)).thenReturn(Optional.of(u));

        auth.login(ADMIN_GMAIL, PW, "web", null);

        assertEquals(Role.USER, u.getRole());
        verify(users, never()).save(any());
    }

    @Test
    void refreshWorksForDeferredAccounts() {
        when(refresh.consumeSession("old")).thenReturn(new RefreshTokenService.Session(41L, "web", 0L));
        when(users.findById(41L)).thenReturn(Optional.of(row(false, true)));

        TokenResponse t = auth.refresh("old");

        assertEquals(Boolean.TRUE, t.verificationDeferred());
    }

    // ------------------------------------------------------------------ JWT'li dogrulama

    @Test
    void statusReflectsTheRow() {
        when(users.findById(41L)).thenReturn(Optional.of(row(false, true)));

        VerificationDtos.StatusResponse s = auth.verificationStatus(41L);

        assertFalse(s.emailVerified());
        assertTrue(s.verificationDeferred());
        assertEquals(EMAIL, s.email());
    }

    @Test
    void verifyWithTheRightCodeLiftsTheRestriction() {
        User u = row(false, true);
        when(users.findById(41L)).thenReturn(Optional.of(u));
        when(verification.verify(EMAIL, "482913", "ip")).thenReturn(true);

        VerificationDtos.VerifiedResponse r = auth.verifyOwnEmail(41L, " 482913 ", "ip");

        assertTrue(r.emailVerified());
        assertFalse(r.verificationDeferred());
        assertTrue(u.isEmailVerified());
        assertFalse(u.isVerificationDeferred());
        verify(users).save(u);
    }

    @Test
    void verifyWithAWrongCodeIs400AndChangesNothing() {
        User u = row(false, true);
        when(users.findById(41L)).thenReturn(Optional.of(u));
        when(verification.verify(EMAIL, "000000", "ip")).thenReturn(false);

        ApiException e = assertThrows(ApiException.class, () -> auth.verifyOwnEmail(41L, "000000", "ip"));

        assertEquals("INVALID_CODE", e.code());
        assertTrue(u.isVerificationDeferred());
        verify(users, never()).save(any());
    }

    @Test
    void verifyIsIdempotentForAlreadyVerifiedAccounts() {
        when(users.findById(41L)).thenReturn(Optional.of(row(true, false)));

        assertTrue(auth.verifyOwnEmail(41L, "123456", "ip").emailVerified());
        verify(verification, never()).verify(anyString(), anyString(), anyString());
    }

    @Test
    void resendAppliesTheQuotaGuardThenIssuesTheCode() {
        when(users.findById(41L)).thenReturn(Optional.of(row(false, true)));

        auth.resendOwnVerification(41L);

        verify(verification).requireVerificationQuota();
        verify(verification).issue(EMAIL, Lang.TR);
    }

    @Test
    void resendWhenQuotaIsStillFullPropagatesTheQuotaError() {
        when(users.findById(41L)).thenReturn(Optional.of(row(false, true)));
        doThrow(new RateLimitedException("MAIL_QUOTA_EXCEEDED", "x", 3600)).when(verification).requireVerificationQuota();

        RateLimitedException e = assertThrows(RateLimitedException.class, () -> auth.resendOwnVerification(41L));

        assertEquals("MAIL_QUOTA_EXCEEDED", e.code());
        assertEquals(3600, e.retryAfterSeconds());
        verify(verification, never()).issue(anyString(), any());
    }

    @Test
    void resendOnAVerifiedAccountIs409() {
        when(users.findById(41L)).thenReturn(Optional.of(row(true, false)));

        ApiException e = assertThrows(ApiException.class, () -> auth.resendOwnVerification(41L));

        assertEquals("EMAIL_ALREADY_VERIFIED", e.code());
        verify(verification, never()).requireVerificationQuota();
    }
}
