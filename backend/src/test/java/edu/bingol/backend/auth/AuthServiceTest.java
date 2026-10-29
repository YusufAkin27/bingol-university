package edu.bingol.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.verifyNoMoreInteractions;
import static org.mockito.Mockito.when;

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

import java.util.List;
import java.util.Optional;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

class AuthServiceTest {

    private static final String EMAIL = "ali@bingol.edu.tr";

    private final UserRepository users = mock(UserRepository.class);
    private final VerificationService verification = mock(VerificationService.class);
    private final PendingRegistrationStore pending = mock(PendingRegistrationStore.class);
    private final SessionService sessions = mock(SessionService.class);
    private final AccountCreator accounts = mock(AccountCreator.class);
    private final JwtService jwt = mock(JwtService.class);
    private final RefreshTokenService refresh = mock(RefreshTokenService.class);
    /** Bekleyen kayitta saklanan parolanin (Sifre1234) ozeti: dogrulamada parola kaniti icin. */
    private static final String PW = "Sifre1234";
    private static final String PW_HASH = new BCryptPasswordEncoder(4).encode(PW);

    private final AuthService auth = new AuthService(users, new BCryptPasswordEncoder(4), jwt, refresh,
            verification, new AdminProperties(List.of()), accounts, pending, sessions, new CatalogService());

    @ParameterizedTest
    @ValueSource(strings = {"a@gmail.com", "a@bingol.edu.tr.evil.com", "a@evilbingol.edu.tr", "a@bingol.edu.com"})
    void rejectsNonUniversityEmails(String email) {
        ApiException e = assertThrows(ApiException.class, () -> auth.register(email, "Sifre1234", "Ali", Lang.TR));

        assertEquals("EMAIL_DOMAIN_NOT_ALLOWED", e.code());
        verifyNoInteractions(users, verification, pending);
    }

    @Test
    void normalizesEmail() {
        assertEquals("ali.veli@bingol.edu.tr", AuthService.normalizeEmail("  Ali.Veli@Bingol.EDU.tr "));
    }

    @Test
    void registerKeepsDataInRedisAndNeverTouchesUserTable() {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.empty());

        auth.register(" Ali@bingol.edu.tr ", "Sifre1234", " Ali ", Lang.TR);

        verify(verification).issue(EMAIL, Lang.TR);
        verify(pending).save(eq(EMAIL), any(Pending.class));
        verify(users, never()).save(any());
    }

    @Test
    void registerDoesNotOverwriteExistingUnverifiedAccount() {
        User unverified = new User();
        unverified.setEmail(EMAIL);
        unverified.setPasswordHash("old-hash");
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(unverified));

        auth.register(EMAIL, "Sifre1234", "Mallory", Lang.TR);

        assertEquals("old-hash", unverified.getPasswordHash());
        verify(users, never()).save(any());
    }

    @Test
    void registerRejectsVerifiedEmail() {
        User verified = new User();
        verified.setEmailVerified(true);
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(verified));

        ApiException e = assertThrows(ApiException.class, () -> auth.register(EMAIL, "Sifre1234", "Ali", Lang.TR));

        assertEquals("EMAIL_ALREADY_REGISTERED", e.code());
        verify(verification).requireMailQuota();
        verifyNoMoreInteractions(verification);
    }

    @Test
    void resendCodeWithoutPendingRegistrationDoesNothing() {
        auth.resendCode(EMAIL);

        verify(verification).requireMailQuota();
        verifyNoMoreInteractions(verification);
    }

    @Test
    void resendCodeSwallowsCooldownAndMailFailures() {
        when(pending.find(EMAIL)).thenReturn(new Pending("h", "Ali", "tr"));
        doThrow(new ApiException(HttpStatus.TOO_MANY_REQUESTS, "RESEND_COOLDOWN", "x"))
                .when(verification).issue(anyString(), any());

        auth.resendCode(EMAIL);

        doThrow(new IllegalStateException("smtp")).when(verification).issue(anyString(), any());
        auth.resendCode(EMAIL);
    }

    @Test
    void verifyEmailWithoutPendingRegistrationIsGenericInvalidCode() {
        ApiException e = assertThrows(ApiException.class, () -> auth.verifyEmail(EMAIL, "123456", null, null, PW));

        assertEquals("INVALID_CODE", e.code());
        verifyNoInteractions(verification);
    }

    @Test
    void verifyEmailWithWrongCodeCreatesNoAccount() {
        when(pending.find(EMAIL)).thenReturn(new Pending(PW_HASH, "Ali", "tr"));
        when(verification.verify(EMAIL, "000000")).thenReturn(false);

        ApiException e = assertThrows(ApiException.class, () -> auth.verifyEmail(EMAIL, "000000", null, null, PW));

        assertEquals("INVALID_CODE", e.code());
        verify(users, never()).save(any());
    }

    @Test
    void verifyEmailCreatesAccountViaTransactionalCreatorAndClearsPending() {
        Pending p = new Pending(PW_HASH, "Ali", "en");
        when(pending.find(EMAIL)).thenReturn(p);
        when(verification.verify(EMAIL, "123456")).thenReturn(true);
        User created = verifiedUser();
        when(accounts.create(EMAIL, p)).thenReturn(created);
        when(jwt.accessTtl()).thenReturn(java.time.Duration.ofMinutes(15));

        auth.verifyEmail(EMAIL, " 123456 ", null, null, PW);

        verify(accounts).create(EMAIL, p);
        verify(pending).delete(EMAIL);
    }

    @Test
    void verifyEmailUniqueViolationBecomes409NotServerError() {
        Pending p = new Pending(PW_HASH, "Ali", "en");
        when(pending.find(EMAIL)).thenReturn(p);
        when(verification.verify(EMAIL, "123456")).thenReturn(true);
        when(accounts.create(EMAIL, p)).thenThrow(new org.springframework.dao.DataIntegrityViolationException("uq"));

        ApiException e = assertThrows(ApiException.class, () -> auth.verifyEmail(EMAIL, "123456", null, null, PW));

        assertEquals("EMAIL_ALREADY_REGISTERED", e.code());
        assertEquals(HttpStatus.CONFLICT, e.status());
    }

    @Test
    void registerWithPendingRegistrationLastWriterWinsAndIssuesNewCode() {
        // H1: ilk kayit edenin parolasi kilitlenmez; son istek bekleyen kaydi ezer, kod yenilenir.
        when(users.findByEmail(EMAIL)).thenReturn(Optional.empty());
        when(pending.find(EMAIL)).thenReturn(new Pending("saldirgan-hash", "Mallory", "en"));

        auth.register(EMAIL, "GercekSahip123", "Ali", Lang.TR);

        org.mockito.InOrder order = org.mockito.Mockito.inOrder(verification, pending);
        order.verify(verification).issue(EMAIL, Lang.TR);
        org.mockito.ArgumentCaptor<Pending> cap = org.mockito.ArgumentCaptor.forClass(Pending.class);
        order.verify(pending).save(eq(EMAIL), cap.capture());
        assertEquals("Ali", cap.getValue().displayName());
        assertTrue(new BCryptPasswordEncoder(4).matches("GercekSahip123", cap.getValue().passwordHash()));
        org.junit.jupiter.api.Assertions.assertFalse(
                new BCryptPasswordEncoder(4).matches("SaldirganSifre1", cap.getValue().passwordHash()));
    }

    @Test
    void registerDuringCooldownKeepsOldPendingSoOldCodeCannotActivateNewPassword() {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.empty());
        doThrow(new ApiException(HttpStatus.TOO_MANY_REQUESTS, "RESEND_COOLDOWN", "bekleyin"))
                .when(verification).issue(anyString(), any());

        assertThrows(ApiException.class, () -> auth.register(EMAIL, "BaskaSifre123", "Mallory", Lang.TR));

        // Kod gonderilemediyse bekleyen kayit EZILMEZ (eski kod eski parolayi etkinlestirir, yenisini degil).
        verify(pending, never()).save(any(), any());
    }

    @Test
    void registerRejectsPlusAliasWithoutSideEffects() {
        ApiException e = assertThrows(ApiException.class,
                () -> auth.register("ali+2@bingol.edu.tr", "Sifre1234", "Ali", Lang.TR));

        assertEquals("EMAIL_ALIAS_NOT_ALLOWED", e.code());
        assertEquals(HttpStatus.BAD_REQUEST, e.status());
        verifyNoInteractions(users, verification, pending);
    }

    @Test
    void registerRejectsPasswordOver72BytesBeforeSendingMail() {
        String longPw = "ğ".repeat(40); // 40 karakter = 80 bayt (UTF-8)

        ApiException e = assertThrows(ApiException.class, () -> auth.register(EMAIL, longPw, "Ali", Lang.TR));

        assertEquals("PASSWORD_TOO_LONG", e.code());
        assertEquals(HttpStatus.BAD_REQUEST, e.status());
        verifyNoInteractions(users, verification, pending);
    }

    @Test
    void registerAcceptsMultiByteButShortEnoughPassword() {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.empty());

        auth.register(EMAIL, "ğ".repeat(36), "Ali", Lang.TR); // 72 bayt

        verify(pending).save(eq(EMAIL), any(Pending.class));
    }

    @Test
    void loginWithOver72BytePasswordIsGenericInvalidCredentialsNot500() {
        ApiException e = assertThrows(ApiException.class, () -> auth.login(EMAIL, "ğ".repeat(40)));

        assertEquals("INVALID_CREDENTIALS", e.code());
        verifyNoInteractions(users);
    }

    @Test
    void resetPasswordRejectsOver72BytePassword() {
        ApiException e = assertThrows(ApiException.class,
                () -> auth.resetPassword(EMAIL, "tok", "ğ".repeat(40)));

        assertEquals("PASSWORD_TOO_LONG", e.code());
        verifyNoInteractions(verification);
    }

    @Test
    void refreshReuseBeyondGraceRevokesAllSessions() {
        when(refresh.detectReuse("calinan")).thenReturn(java.util.OptionalLong.of(7L));

        ApiException e = assertThrows(ApiException.class, () -> auth.refresh("calinan"));

        assertEquals("INVALID_REFRESH_TOKEN", e.code());
        verify(sessions).revokeAll(7L);
    }

    @Test
    void refreshUnknownTokenWithoutUsedMarkerRevokesNothing() {
        assertThrows(ApiException.class, () -> auth.refresh("bilinmeyen"));

        verify(sessions, never()).revokeAll(any());
    }

    @Test
    void refreshAfterAbsoluteSessionLifetimeIsRejected() {
        RefreshTokenService.Session old = new RefreshTokenService.Session(7L, "web", 1_000L);
        when(refresh.consumeSession("tok")).thenReturn(old);
        when(refresh.isExpired(old)).thenReturn(true);

        ApiException e = assertThrows(ApiException.class, () -> auth.refresh("tok"));

        assertEquals("INVALID_REFRESH_TOKEN", e.code());
        verify(refresh, never()).issue(any(), anyString(), org.mockito.ArgumentMatchers.anyLong());
    }

    @Test
    void refreshOfSessionRevokedAfterItStartedIsRejected() {
        RefreshTokenService.Session s = new RefreshTokenService.Session(7L, "web", 5_000L);
        when(refresh.consumeSession("tok")).thenReturn(s);
        when(sessions.isRevokedSince(7L, "web", 5_000L)).thenReturn(true);

        ApiException e = assertThrows(ApiException.class, () -> auth.refresh("tok"));

        assertEquals("INVALID_REFRESH_TOKEN", e.code());
        verify(refresh, never()).issue(any(), anyString(), org.mockito.ArgumentMatchers.anyLong());
    }

    @Test
    void refreshRotationKeepsOriginalAuthTime() {
        User u = loginUser();
        when(users.findById(7L)).thenReturn(Optional.of(u));
        when(refresh.consumeSession("tok")).thenReturn(new RefreshTokenService.Session(7L, "web", 5_000L));
        when(refresh.issue(7L, "web", 5_000L)).thenReturn("yeni");

        assertEquals("yeni", auth.refresh("tok").refreshToken());

        verify(refresh).issue(7L, "web", 5_000L);
    }

    @Test
    void refreshWhereRevokeAllRacedInClosesTheNewPairToo() {
        User u = loginUser();
        when(users.findById(7L)).thenReturn(Optional.of(u));
        when(refresh.consumeSession("tok")).thenReturn(new RefreshTokenService.Session(7L, "web", 5_000L));
        when(refresh.issue(7L, "web", 5_000L)).thenReturn("yeni");
        // ilk kontrol temiz, token uretildikten sonra revokeAll araya girmis
        when(sessions.isRevokedSince(7L, "web", 5_000L)).thenReturn(false, true);

        assertThrows(ApiException.class, () -> auth.refresh("tok"));

        verify(refresh).revoke("yeni");
    }

    @Test
    void verifyEmailWithClientContextScopesAttemptsToIpPrefix() {
        Pending p = new Pending(PW_HASH, "Ali", "en");
        when(pending.find(EMAIL)).thenReturn(p);
        when(verification.verify(EMAIL, "123456", "v6:2001:0db8:0001:0002::/64")).thenReturn(true);
        when(accounts.create(EMAIL, p)).thenReturn(verifiedUser());
        when(jwt.accessTtl()).thenReturn(java.time.Duration.ofMinutes(15));
        edu.bingol.backend.accessban.ClientContext ctx =
                new edu.bingol.backend.accessban.ClientContext("2001:db8:1:2:aaaa:bbbb:cccc:dddd", null, "WEB", null);

        auth.verifyEmail(EMAIL, "123456", "web", ctx, PW);

        verify(verification).verify(EMAIL, "123456", "v6:2001:0db8:0001:0002::/64");
    }

    @Test
    void verifyEmailWithWrongPasswordProofIsGenericInvalidCodeAndCountsAttemptWithoutConsumingCode() {
        // Hesap devralma: saldirgan ayni adrese yeniden kayit gonderdi; sahibinin kodu + sahibinin parolasi uyusmaz.
        when(pending.find(EMAIL)).thenReturn(new Pending(new BCryptPasswordEncoder(4).encode("SaldirganPw1"), "Mallory", "tr"));

        ApiException e = assertThrows(ApiException.class, () -> auth.verifyEmail(EMAIL, "123456", null, null, PW));

        assertEquals("INVALID_CODE", e.code());
        assertEquals(HttpStatus.BAD_REQUEST, e.status());
        verify(verification).recordWrongAttempt(EMAIL, null);
        verify(verification, never()).verify(anyString(), anyString());
        verify(verification, never()).verify(anyString(), anyString(), anyString());
        verifyNoInteractions(accounts);
        verify(pending, never()).delete(anyString());
    }

    @Test
    void verifyEmailWithoutPasswordIsRejectedWhenProofRequired() {
        when(pending.find(EMAIL)).thenReturn(new Pending(PW_HASH, "Ali", "tr"));

        ApiException e = assertThrows(ApiException.class, () -> auth.verifyEmail(EMAIL, "123456", null, null, null));

        assertEquals("INVALID_CODE", e.code());
        verify(verification).recordWrongAttempt(EMAIL, null);
        verifyNoInteractions(accounts);
    }

    @Test
    void verifyEmailWrongPasswordProofUsesIpScopeForAttemptCounter() {
        when(pending.find(EMAIL)).thenReturn(new Pending(PW_HASH, "Ali", "tr"));
        edu.bingol.backend.accessban.ClientContext ctx =
                new edu.bingol.backend.accessban.ClientContext("203.0.113.9", null, "WEB", null);

        assertThrows(ApiException.class, () -> auth.verifyEmail(EMAIL, "123456", "web", ctx, "YanlisSifre1"));

        verify(verification).recordWrongAttempt(EMAIL, "203.0.113.9");
    }

    @Test
    void verifyEmailLegacyClientWithoutPasswordPassesWhenFlagOff() {
        auth.setVerifyRequiresPassword(false);
        Pending p = new Pending(PW_HASH, "Ali", "tr");
        when(pending.find(EMAIL)).thenReturn(p);
        when(verification.verify(EMAIL, "123456")).thenReturn(true);
        when(accounts.create(EMAIL, p)).thenReturn(verifiedUser());
        when(jwt.accessTtl()).thenReturn(java.time.Duration.ofMinutes(15));

        auth.verifyEmail(EMAIL, "123456", null, null, null);

        verify(accounts).create(EMAIL, p);
        verify(verification, never()).recordWrongAttempt(anyString(), any());
    }

    @Test
    void verifyEmailPasswordIsStillCheckedWhenSuppliedAndFlagOff() {
        auth.setVerifyRequiresPassword(false);
        when(pending.find(EMAIL)).thenReturn(new Pending(PW_HASH, "Ali", "tr"));

        ApiException e = assertThrows(ApiException.class,
                () -> auth.verifyEmail(EMAIL, "123456", null, null, "BaskaSifre99"));

        assertEquals("INVALID_CODE", e.code());
        verifyNoInteractions(accounts);
    }

    @Test
    void loginForUnknownUserIsGenericInvalidCredentials() {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.empty());

        ApiException e = assertThrows(ApiException.class, () -> auth.login(EMAIL, "Sifre1234"));

        assertEquals("INVALID_CREDENTIALS", e.code());
    }

    @Test
    void studentNumberRegistersAsUniversityEmail() {
        when(users.findByEmail("226051015@bingol.edu.tr")).thenReturn(Optional.empty());

        auth.register("226 051 015", "Sifre1234", "Ali", Lang.TR);

        verify(verification).issue("226051015@bingol.edu.tr", Lang.TR);
        verify(pending).save(eq("226051015@bingol.edu.tr"), any(Pending.class));
    }

    @Test
    void studentNumberVerifiesAndLogsIn() {
        String mail = "226051015@bingol.edu.tr";
        Pending p = new Pending(PW_HASH, "Ali", "tr");
        when(pending.find(mail)).thenReturn(p);
        when(verification.verify(mail, "123456")).thenReturn(true);
        when(accounts.create(mail, p)).thenReturn(verifiedUser());
        when(jwt.accessTtl()).thenReturn(java.time.Duration.ofMinutes(15));

        auth.verifyEmail("226051015", "123456", null, null, PW);

        verify(accounts).create(mail, p);
        verify(pending).delete(mail);
    }

    @Test
    void loginWithStudentNumberFindsAccount() {
        User u = loginUser();
        u.setEmail("226051015@bingol.edu.tr");
        when(users.findByEmail("226051015@bingol.edu.tr")).thenReturn(Optional.of(u));

        auth.login("226051015", "Sifre1234");

        verify(users).findByEmail("226051015@bingol.edu.tr");
    }

    @Test
    void loginWithPendingRegistrationAndCorrectPasswordIsEmailNotVerified() {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.empty());
        String hash = new BCryptPasswordEncoder(4).encode("Sifre1234");
        when(pending.find(EMAIL)).thenReturn(new Pending(hash, "Ali", "tr"));

        ApiException e = assertThrows(ApiException.class, () -> auth.login(EMAIL, "Sifre1234"));

        assertEquals("EMAIL_NOT_VERIFIED", e.code());
        assertEquals(HttpStatus.FORBIDDEN, e.status());
    }

    @Test
    void loginWithPendingRegistrationAndWrongPasswordIsGeneric() {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.empty());
        String hash = new BCryptPasswordEncoder(4).encode("Sifre1234");
        when(pending.find(EMAIL)).thenReturn(new Pending(hash, "Ali", "tr"));

        ApiException e = assertThrows(ApiException.class, () -> auth.login(EMAIL, "Yanlis1234"));

        assertEquals("INVALID_CREDENTIALS", e.code());
    }

    @Test
    void resendCodeForPendingRegistrationCountsResend() {
        when(pending.find(EMAIL)).thenReturn(new Pending("h", "Ali", "tr"));

        auth.resendCode("Ali@Bingol.edu.tr");

        verify(verification).issue(EMAIL, Lang.TR);
        verify(pending).markResend(EMAIL);
    }

    @Test
    void logoutAllRevokesEverySession() {
        auth.logoutAll(7L);

        verify(sessions).revokeAll(7L);
    }

    private User loginUser() {
        User u = verifiedUser();
        u.setPasswordHash(new BCryptPasswordEncoder(4).encode("Sifre1234"));
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(u));
        when(jwt.accessTtl()).thenReturn(java.time.Duration.ofMinutes(15));
        return u;
    }

    @Test
    void mobileLoginRevokesPreviousMobileSessionsBeforeIssuingTokens() {
        loginUser();

        auth.login(EMAIL, "Sifre1234", "mobile");

        org.mockito.InOrder order = org.mockito.Mockito.inOrder(sessions, refresh);
        order.verify(sessions).revokeClient(7L, "mobile", true);
        order.verify(refresh).issue(7L, "mobile");
        verify(sessions, never()).revokeAll(any());
    }

    @Test
    void webLoginAndMissingClientRevokeNothing() {
        loginUser();

        auth.login(EMAIL, "Sifre1234", "web");
        auth.login(EMAIL, "Sifre1234");

        verify(sessions, never()).revokeClient(any(), anyString(), org.mockito.ArgumentMatchers.anyBoolean());
        verify(sessions, never()).revokeAll(any());
        verify(refresh, org.mockito.Mockito.times(2)).issue(7L, "web");
    }

    @Test
    void wrongPasswordRevokesNothing() {
        loginUser();

        assertThrows(ApiException.class, () -> auth.login(EMAIL, "yanlis", "mobile"));

        verifyNoInteractions(sessions);
    }

    @Test
    void refreshWithRevokedTokenIsSessionReplaced() {
        when(refresh.wasRevoked("tok")).thenReturn(true);

        ApiException e = assertThrows(ApiException.class, () -> auth.refresh("tok"));

        assertEquals("SESSION_REPLACED", e.code());
        assertEquals(HttpStatus.UNAUTHORIZED, e.status());
    }

    @Test
    void refreshWithUnknownTokenKeepsGenericCode() {
        ApiException e = assertThrows(ApiException.class, () -> auth.refresh("bilinmeyen"));

        assertEquals("INVALID_REFRESH_TOKEN", e.code());
    }

    @Test
    void refreshKeepsClientOfTheConsumedToken() {
        User u = loginUser();
        when(users.findById(7L)).thenReturn(Optional.of(u));
        when(refresh.consumeSession("tok")).thenReturn(new RefreshTokenService.Session(7L, "mobile"));

        auth.refresh("tok");

        verify(refresh).issue(7L, "mobile");
        verify(jwt).createAccessToken(u, "mobile");
        verifyNoInteractions(sessions);
    }

    @Test
    void passwordResetStillRevokesAllClients() {
        loginUser();
        when(verification.consumeResetToken(EMAIL, "rt")).thenReturn(true);

        auth.resetPassword(EMAIL, "rt", "YeniSifre123");

        verify(sessions).revokeAll(7L);
    }

    private static User verifiedUser() {
        User u = new User();
        u.setId(7L);
        u.setEmail(EMAIL);
        u.setEmailVerified(true);
        u.setPasswordHash("eski");
        u.setLanguage("tr");
        return u;
    }

    @Test
    void forgotPasswordIsSilentForUnknownAccount() {
        when(users.findByEmail("yok@bingol.edu.tr")).thenReturn(Optional.empty());

        auth.forgotPassword("yok@bingol.edu.tr");

        verify(verification, never()).issueReset(any(), any());
    }

    @Test
    void forgotPasswordSwallowsCooldownSoExistenceDoesNotLeak() {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(verifiedUser()));
        doThrow(new ApiException(HttpStatus.TOO_MANY_REQUESTS, "RESEND_COOLDOWN", "bekleyin"))
                .when(verification).issueReset(any(), any());

        auth.forgotPassword(EMAIL);
    }

    @Test
    void verifyResetCodeRejectsWrongCode() {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(verifiedUser()));
        when(verification.verifyReset(EMAIL, "111111")).thenReturn(false);

        ApiException e = assertThrows(ApiException.class, () -> auth.verifyResetCode(EMAIL, "111111"));

        assertEquals("INVALID_CODE", e.code());
        verify(verification, never()).issueResetToken(any());
    }

    @Test
    void verifyResetCodeReturnsToken() {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(verifiedUser()));
        when(verification.verifyReset(EMAIL, "123456")).thenReturn(true);
        when(verification.issueResetToken(EMAIL)).thenReturn("tok");

        assertEquals("tok", auth.verifyResetCode("Ali@bingol.edu.tr", "123456"));
    }

    @Test
    void resetPasswordRejectsBadToken() {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(verifiedUser()));
        when(verification.consumeResetToken(EMAIL, "kotu")).thenReturn(false);

        ApiException e = assertThrows(ApiException.class, () -> auth.resetPassword(EMAIL, "kotu", "YeniSifre123"));

        assertEquals("INVALID_CODE", e.code());
        verify(users, never()).save(any());
        verify(sessions, never()).revokeAll(any());
    }

    @Test
    void resetPasswordStoresNewHashAndClosesAllSessions() {
        User u = verifiedUser();
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(u));
        when(verification.consumeResetToken(EMAIL, "tok")).thenReturn(true);

        auth.resetPassword(" Ali@bingol.edu.tr ", "tok", "YeniSifre123");

        org.junit.jupiter.api.Assertions.assertNotEquals("eski", u.getPasswordHash());
        verify(users).save(u);
        verify(sessions).revokeAll(7L);
    }

    @Test
    void registerCarriesAcademicFieldsIntoPendingRegistration() {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.empty());

        auth.register(EMAIL, "Sifre1234", "Ali", Lang.TR, "Mühendislik Fakültesi", "Bilgisayar Mühendisliği", "2");

        org.mockito.ArgumentCaptor<Pending> cap = org.mockito.ArgumentCaptor.forClass(Pending.class);
        verify(pending).save(eq(EMAIL), cap.capture());
        assertEquals("Mühendislik Fakültesi", cap.getValue().faculty());
        assertEquals("Bilgisayar Mühendisliği", cap.getValue().department());
        assertEquals("2", cap.getValue().grade());
    }

    @Test
    void registerTreatsBlankAcademicFieldsAsMissing() {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.empty());

        auth.register(EMAIL, "Sifre1234", "Ali", Lang.TR, " ", "", null);

        org.mockito.ArgumentCaptor<Pending> cap = org.mockito.ArgumentCaptor.forClass(Pending.class);
        verify(pending).save(eq(EMAIL), cap.capture());
        org.junit.jupiter.api.Assertions.assertNull(cap.getValue().faculty());
        org.junit.jupiter.api.Assertions.assertNull(cap.getValue().grade());
    }

    @Test
    void registerRejectsInvalidAcademicFieldsWith400() {
        for (String[] bad : new String[][]{
                {"Hukuk Fakültesi", "Bilgisayar Mühendisliği", null}, {"Uydurma", null, null},
                {null, "Hukuk", null}, {null, null, "12"}}) {
            ApiException e = assertThrows(ApiException.class,
                    () -> auth.register(EMAIL, "Sifre1234", "Ali", Lang.TR, bad[0], bad[1], bad[2]));
            assertEquals("ACADEMIC_INVALID", e.code());
            assertEquals(HttpStatus.BAD_REQUEST, e.status());
        }
        verifyNoInteractions(verification);
        verify(pending, never()).save(anyString(), any());
    }
    // --- Yonetici e-postasi istisnasi (ADMIN_EMAILS alan adi kisitindan muaf, baska adres degil) ---

    private AuthService authWithAdmins(String... adminEmails) {
        return new AuthService(users, new BCryptPasswordEncoder(4), jwt, refresh, verification,
                new AdminProperties(List.of(adminEmails)), accounts, pending, sessions, new CatalogService());
    }

    @Test
    void adminListedNonUniversityEmailCanRegisterThroughNormalVerificationFlow() {
        String admin = "ysufakin23@gmail.com";
        when(users.findByEmail(admin)).thenReturn(Optional.empty());

        authWithAdmins(admin).register(" YsufAkin23@Gmail.com ", "Sifre1234", "Yonetici", Lang.TR);

        verify(verification).requireMailQuota();
        verify(verification).issue(admin, Lang.TR); // kod e-postayla gider: sahiplik kaniti sart
        verify(pending).save(eq(admin), any(Pending.class));
        verify(users, never()).save(any()); // hesap yalniz dogrulamadan sonra
    }

    @Test
    void nonAdminGmailIsStillRejectedWhenAdminListIsNonEmpty() {
        ApiException e = assertThrows(ApiException.class, () ->
                authWithAdmins("ysufakin23@gmail.com").register("baska@gmail.com", "Sifre1234", "X", Lang.TR));

        assertEquals("EMAIL_DOMAIN_NOT_ALLOWED", e.code());
        verifyNoInteractions(users, verification, pending);
    }

    @Test
    void adminDomainExemptionIsExactAddressNotDomainOrPrefix() {
        AuthService a = authWithAdmins("ysufakin23@gmail.com");
        for (String bad : new String[]{"ysufakin23@gmail.com.evil.com", "xysufakin23@gmail.com", "ysufakin23@mail.gmail.com"}) {
            ApiException e = assertThrows(ApiException.class, () -> a.register(bad, "Sifre1234", "X", Lang.TR));
            assertEquals("EMAIL_DOMAIN_NOT_ALLOWED", e.code());
        }
        verifyNoInteractions(users, verification, pending);
    }

    @Test
    void adminExemptionDoesNotLiftPlusAliasBan() {
        ApiException e = assertThrows(ApiException.class, () ->
                authWithAdmins("yonetici+x@gmail.com").register("yonetici+x@gmail.com", "Sifre1234", "X", Lang.TR));

        assertEquals("EMAIL_ALIAS_NOT_ALLOWED", e.code());
        verifyNoInteractions(users, verification, pending);
    }

    @Test
    void adminExemptionKeepsPasswordLimitAndExistingAccountConflict() {
        String admin = "ysufakin23@gmail.com";
        AuthService a = authWithAdmins(admin);
        ApiException tooLong = assertThrows(ApiException.class,
                () -> a.register(admin, "x".repeat(73), "X", Lang.TR));
        assertEquals("PASSWORD_TOO_LONG", tooLong.code());

        User verified = new User();
        verified.setEmailVerified(true);
        when(users.findByEmail(admin)).thenReturn(Optional.of(verified));
        ApiException dup = assertThrows(ApiException.class, () -> a.register(admin, "Sifre1234", "X", Lang.TR));
        assertEquals("EMAIL_ALREADY_REGISTERED", dup.code());
    }

    @Test
    void adminGmailLoginAndPasswordResetUseSameEmailWithoutDomainCheck() {
        String admin = "ysufakin23@gmail.com";
        User u = new User();
        u.setEmail(admin);
        u.setEmailVerified(true);
        u.setPasswordHash(PW_HASH);
        when(users.findByEmail(admin)).thenReturn(Optional.of(u));
        when(refresh.issue(any(), any())).thenReturn("rt");
        when(jwt.createAccessToken(any(), any())).thenReturn("at");
        when(jwt.accessTtl()).thenReturn(java.time.Duration.ofMinutes(15));
        AuthService a = authWithAdmins(admin);

        assertEquals("at", a.login("YsufAkin23@gmail.com", PW).accessToken());
        assertEquals(edu.bingol.backend.user.Role.ADMIN, u.getRole()); // giriste ADMIN/FULL'e terfi
        assertEquals(edu.bingol.backend.admin.rbac.AdminProfile.FULL, u.getAdminProfile());

        a.forgotPassword(admin);
        verify(verification).issueReset(eq(admin), any());
    }
}
