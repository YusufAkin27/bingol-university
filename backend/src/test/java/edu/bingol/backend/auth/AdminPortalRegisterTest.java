package edu.bingol.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.startsWith;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import edu.bingol.backend.accessban.ClientContexts;
import edu.bingol.backend.auth.dto.MessageResponse;
import edu.bingol.backend.auth.dto.RegisterRequest;
import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.auth.token.PendingRegistrationStore;
import edu.bingol.backend.auth.token.PendingRegistrationStore.Pending;
import edu.bingol.backend.auth.token.RefreshTokenService;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.auth.token.VerificationService;
import edu.bingol.backend.catalog.CatalogService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.config.RateLimitProperties;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import java.time.Duration;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.web.bind.annotation.ResponseStatus;

/**
 * Yonetici paneli kayit sayfasi (adminPortal=true) guvenlik ozelligi: yalniz ADMIN_EMAILS adresleri kayit acabilir,
 * digerleri (bingol.edu.tr dahil) sessizce genel 202 alir ve hicbir yan etki dogmaz. Genel kayit kurali degismez.
 */
class AdminPortalRegisterTest {

    private static final String PW = "Kx7-mQ2vLp9z"; // 12 karakter: yonetici asgari uzunlugu
    private static final String ADMIN_GMAIL = "ops.admin@gmail.com";
    private static final String STUDENT = "ali@bingol.edu.tr";

    private final UserRepository users = mock(UserRepository.class);
    private final VerificationService verification = mock(VerificationService.class);
    private final PendingRegistrationStore pending = mock(PendingRegistrationStore.class);
    private final AuthService auth = new AuthService(users, new BCryptPasswordEncoder(4), mock(JwtService.class),
            mock(RefreshTokenService.class), verification, new AdminProperties(List.of(ADMIN_GMAIL)),
            mock(AccountCreator.class), pending, mock(SessionService.class), new CatalogService());

    private final RateLimiter limiter = mock(RateLimiter.class);
    private final I18n i18n = mock(I18n.class);
    private final AuthController controller = new AuthController(auth, limiter, i18n, new ClientIp("10.0.0.0/8"),
            mock(ClientContexts.class), mock(JwtService.class), mock(LoginThrottle.class),
            RateLimitProperties.defaults(), mock(RefreshTokenService.class));

    private static HttpServletRequest from(String ip) {
        MockHttpServletRequest req = new MockHttpServletRequest();
        req.setRemoteAddr(ip);
        return req;
    }

    private static RegisterRequest req(String email, String password, boolean portal) {
        return new RegisterRequest(email, password, "Ali Veli", true, "tr", null, null, null, portal);
    }

    @Test
    void portalWithUnlistedUniversityEmailIsSilentlyDroppedWithNoSideEffects() {
        auth.register(STUDENT, PW, "Ali", Lang.TR, null, null, null, true);

        verify(verification).requireMailQuota();
        verify(verification, never()).issue(anyString(), any());
        verify(pending, never()).save(anyString(), any(Pending.class));
        verifyNoInteractions(pending);
        verifyNoInteractions(users); // hesap aranmaz, olusturulmaz, dogrulanmis hesap varligi sezdirilmez
    }

    @Test
    void portalWithListedGmailSendsTheCodeAndKeepsThePendingRegistration() {
        when(users.findByEmail(ADMIN_GMAIL)).thenReturn(Optional.empty());

        auth.register(" Ops.Admin@Gmail.com ", PW, "Ops", Lang.TR, null, null, null, true);

        verify(verification).issue(ADMIN_GMAIL, Lang.TR);
        verify(pending).save(org.mockito.ArgumentMatchers.eq(ADMIN_GMAIL), any(Pending.class));
        verify(users, never()).save(any());
    }

    @Test
    void generalRegistrationStillRejectsAnUnlistedGmail() {
        ApiException e = assertThrows(ApiException.class,
                () -> auth.register("kisi@gmail.com", PW, "Ali", Lang.TR, null, null, null, false));

        assertEquals("EMAIL_DOMAIN_NOT_ALLOWED", e.code());
        verifyNoInteractions(users, verification, pending);
    }

    @Test
    void generalRegistrationStillRejectsAnUnlistedGmailWhenTheFlagIsAbsent() {
        ApiException e = assertThrows(ApiException.class,
                () -> auth.register("kisi@gmail.com", PW, "Ali", Lang.TR));

        assertEquals("EMAIL_DOMAIN_NOT_ALLOWED", e.code());
        verifyNoInteractions(users, verification, pending);
    }

    @Test
    void generalRegistrationOfAUniversityEmailIsUnchanged() {
        when(users.findByEmail(STUDENT)).thenReturn(Optional.empty());

        auth.register(STUDENT, "Kx7-mQ2vLp9z", "Ali", Lang.TR, null, null, null, false);

        verify(verification).issue(STUDENT, Lang.TR);
        verify(pending).save(org.mockito.ArgumentMatchers.eq(STUDENT), any(Pending.class));
    }

    @Test
    void generalRegistrationOfAListedGmailKeepsTheAdminExceptionWithoutThePortalFlag() {
        when(users.findByEmail(ADMIN_GMAIL)).thenReturn(Optional.empty());

        auth.register(ADMIN_GMAIL, PW, "Ops", Lang.TR, null, null, null, false);

        verify(verification).issue(ADMIN_GMAIL, Lang.TR);
    }

    @Test
    void portalAnswersAreIdenticalForAuthorizedAndUnauthorizedAddresses() throws Exception {
        when(i18n.current("msg.register.sent")).thenReturn("Kod gonderildi");
        when(users.findByEmail(ADMIN_GMAIL)).thenReturn(Optional.empty());

        MessageResponse authorized = controller.register(req(ADMIN_GMAIL, PW, true), from("203.0.113.9"));
        MessageResponse unauthorized = controller.register(req(STUDENT, PW, true), from("203.0.113.9"));

        assertEquals(authorized, unauthorized);
        assertEquals("Kod gonderildi", unauthorized.message());
        assertEquals(HttpStatus.ACCEPTED, AuthController.class
                .getMethod("register", RegisterRequest.class, HttpServletRequest.class)
                .getAnnotation(ResponseStatus.class).value());
        // Hiz siniri ve kota sayaclari iki durumda da ayni sekilde tuketilir (controller akisi bayraktan bagimsiz).
        verify(limiter, times(2)).check(startsWith("register:ip:"), anyInt(), any(Duration.class));
        verify(limiter, times(2)).check(startsWith("register:email:"), anyInt(), any(Duration.class));
        verify(limiter, times(2)).check(startsWith("codemail:day:"), anyInt(), any(Duration.class));
        verify(verification, times(2)).requireMailQuota();
        // Yalniz yetkili adres icin kod gitti.
        verify(verification, times(1)).issue(anyString(), any());
        verify(verification).issue(ADMIN_GMAIL, Lang.TR);
    }

    @Test
    void portalValidationErrorsAreTheSameForListedAndUnlistedAddresses() {
        String weak = "kisa12345"; // yonetici asgari uzunlugunun altinda: iki adreste de AYNI hata
        ApiException listed = assertThrows(ApiException.class,
                () -> auth.register(ADMIN_GMAIL, weak, "Ops", Lang.TR, null, null, null, true));
        ApiException unlisted = assertThrows(ApiException.class,
                () -> auth.register(STUDENT, weak, "Ali", Lang.TR, null, null, null, true));

        assertEquals(listed.code(), unlisted.code());
        assertEquals(listed.status(), unlisted.status());

        ApiException aliasListed = assertThrows(ApiException.class,
                () -> auth.register("ops.admin+1@gmail.com", PW, "Ops", Lang.TR, null, null, null, true));
        ApiException aliasUnlisted = assertThrows(ApiException.class,
                () -> auth.register("ali+1@bingol.edu.tr", PW, "Ali", Lang.TR, null, null, null, true));
        assertEquals("EMAIL_ALIAS_NOT_ALLOWED", aliasListed.code());
        assertEquals(aliasListed.code(), aliasUnlisted.code());
        verify(verification, never()).issue(anyString(), any());
    }

    @Test
    void portalDoesNotRevealThatAListedAddressIsAlreadyRegistered() {
        User verified = new User();
        verified.setEmailVerified(true);
        when(users.findByEmail(ADMIN_GMAIL)).thenReturn(Optional.of(verified));

        auth.register(ADMIN_GMAIL, PW, "Ops", Lang.TR, null, null, null, true); // 409 yerine sessiz basari

        verify(verification, never()).issue(anyString(), any());
        verifyNoInteractions(pending);
    }

    @Test
    void portalSwallowsTheResendCooldownSoTheListIsNotLeaked() {
        when(users.findByEmail(ADMIN_GMAIL)).thenReturn(Optional.empty());
        doThrow(new ApiException(HttpStatus.TOO_MANY_REQUESTS, "RESEND_COOLDOWN", "x"))
                .when(verification).issue(anyString(), any());

        auth.register(ADMIN_GMAIL, PW, "Ops", Lang.TR, null, null, null, true);

        verify(pending, never()).save(anyString(), any(Pending.class)); // eski kayit/kod ezilmez
    }

    @Test
    void generalRegistrationStillReportsAnAlreadyRegisteredEmail() {
        User verified = new User();
        verified.setEmailVerified(true);
        when(users.findByEmail(STUDENT)).thenReturn(Optional.of(verified));

        ApiException e = assertThrows(ApiException.class,
                () -> auth.register(STUDENT, PW, "Ali", Lang.TR, null, null, null, false));

        assertEquals("EMAIL_ALREADY_REGISTERED", e.code());
    }
}
