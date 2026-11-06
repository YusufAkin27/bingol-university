package edu.bingol.backend.auth.realemail;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.auth.FakeRedis;
import edu.bingol.backend.auth.oauth.AuthIdentity;
import edu.bingol.backend.auth.oauth.AuthIdentityRepository;
import edu.bingol.backend.auth.token.PendingRegistrationStore;
import edu.bingol.backend.auth.token.VerificationService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.mail.MailService;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.test.util.ReflectionTestUtils;

/**
 * Gercek e-posta akisi (Redis taklidi + gercek VerificationService; depolar sahte): kod YENI adrese gider ve ona
 * baglidir, role adresine posta gitmez, dogrulamada hesabin tek e-postasi olur, cakisma/yonetici korumasi, yeniden
 * dogrulama (role olmayan hesap), yeniden gonderim beklemesi.
 */
class RealEmailServiceTest {

    private static final String RELAY = "abc123@privaterelay.appleid.com";

    private final FakeRedis redis = new FakeRedis();
    private final MailService mail = mock(MailService.class);
    private final UserRepository users = mock(UserRepository.class);
    private final AuthIdentityRepository identities = mock(AuthIdentityRepository.class);
    private final PendingRegistrationStore pending = mock(PendingRegistrationStore.class);
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder(4);
    private RealEmailService svc;
    private User relayUser;
    private AuthIdentity appleIdentity;

    @BeforeEach
    void setUp() {
        VerificationService verification = new VerificationService(redis.template, mail);
        svc = new RealEmailService(users, identities, verification, pending, redis.template,
                new AdminProperties(List.of("yonetici@gmail.com")));
        ReflectionTestUtils.setField(svc, "encoder", encoder);

        relayUser = new User();
        relayUser.setId(7L);
        relayUser.setEmail(RELAY);
        relayUser.setEmailVerified(true);
        relayUser.setEmailRelay(true);
        relayUser.setRealEmailRequired(true);
        relayUser.setPasswordHash(User.NO_PASSWORD_PREFIX + "x");
        relayUser.setLanguage("en");
        when(users.findById(7L)).thenReturn(Optional.of(relayUser));
        when(users.saveAndFlush(any(User.class))).thenAnswer(i -> i.getArgument(0));

        appleIdentity = new AuthIdentity();
        appleIdentity.setUserId(7L);
        appleIdentity.setEmail(RELAY);
        appleIdentity.setEmailIsPrivate(true);
        when(identities.findByUserIdOrderByCreatedAtAsc(7L)).thenReturn(new ArrayList<>(List.of(appleIdentity)));
    }

    private String lastCode() {
        ArgumentCaptor<String> code = ArgumentCaptor.forClass(String.class);
        verify(mail, org.mockito.Mockito.atLeastOnce()).sendVerificationCode(anyString(), code.capture(), anyInt(), any(Lang.class));
        return code.getValue();
    }

    private static String code(Runnable r) {
        return assertThrows(ApiException.class, r::run).code();
    }

    // ------------------------------------------------------------------ basari yolu

    @Test
    void codeGoesToTheRealAddressNeverToTheRelayAndVerifyMakesItTheOnlyEmail() {
        var res = svc.start(7L, "  Gercek.Kisi@Gmail.com ", null, null, null, null);

        assertTrue(res.sent());
        assertEquals("g***@gmail.com", res.emailMasked());
        verify(mail).sendVerificationCode(eq("gercek.kisi@gmail.com"), anyString(), eq(10), eq(Lang.EN));
        verify(mail, never()).sendVerificationCode(eq(RELAY), anyString(), anyInt(), any(Lang.class));

        var done = svc.verify(7L, lastCode(), "1.2.3.4");

        assertEquals("gercek.kisi@gmail.com", done.email());
        assertTrue(done.emailVerified());
        assertFalse(done.emailNeedsReal());
        assertFalse(done.realEmailRequired());
        assertEquals("gercek.kisi@gmail.com", relayUser.getEmail());
        assertTrue(relayUser.isEmailVerified());
        assertFalse(relayUser.isEmailRelay());
        assertFalse(relayUser.isRealEmailRequired());
        assertNotNull(relayUser.getRealEmailVerifiedAt());
        // KVKK: eski role adresi saklanmaz
        assertNull(appleIdentity.getEmail());
        assertFalse(appleIdentity.isEmailIsPrivate());
        verify(identities).save(appleIdentity);
        assertFalse(redis.values.containsKey("rem:7"), "bekleyen adres temizlendi");
    }

    @Test
    void theCodeIsSingleUseAndBoundToTheAddress() {
        svc.start(7L, "ilk@gmail.com", null, null, null, null);
        String first = lastCode();
        // adres duzeltildi: yeni adres icin yeni kod, eski adrese ait kod artik gecersiz
        svc.start(7L, "ikinci@gmail.com", null, null, null, null);
        String second = lastCode();
        if (!first.equals(second)) {
            assertEquals("INVALID_CODE", code(() -> svc.verify(7L, first, "ip")));
        }
        assertEquals("ikinci@gmail.com", svc.verify(7L, second, "ip").email());
        assertEquals("INVALID_CODE", code(() -> svc.verify(7L, second, "ip")), "kod tek kullanimlik");
    }

    @Test
    void verifyWithoutStartIsAGenericInvalidCode() {
        assertEquals("INVALID_CODE", code(() -> svc.verify(7L, "123456", "ip")));
        assertEquals(RELAY, relayUser.getEmail());
    }

    @Test
    void wrongCodeIsRejectedAndFiveWrongAttemptsLockTheAddress() {
        svc.start(7L, "gercek@gmail.com", null, null, null, null);
        String good = lastCode();
        String bad = good.equals("000000") ? "000001" : "000000";
        for (int i = 0; i < 5; i++) {
            assertEquals("INVALID_CODE", code(() -> svc.verify(7L, bad, "ip")));
        }
        assertEquals("TOO_MANY_ATTEMPTS", code(() -> svc.verify(7L, good, "ip")), "5 yanlistan sonra dogru kod da kilitli");
        assertEquals(RELAY, relayUser.getEmail());
    }

    @Test
    void resendWithinCooldownIsRejectedWithRetryAfter() {
        svc.start(7L, "gercek@gmail.com", null, null, null, null);
        assertEquals("RESEND_COOLDOWN", code(() -> svc.start(7L, "gercek@gmail.com", null, null, null, null)));
    }

    // ------------------------------------------------------------------ girdi denetimi

    @Test
    void relayPlusAliasBadFormatAndUnchangedAddressesAreRejectedBeforeAnyMail() {
        assertEquals("EMAIL_RELAY_NOT_ALLOWED", code(() -> svc.start(7L, "baska@privaterelay.appleid.com", null, null, null, null)));
        assertEquals("EMAIL_RELAY_NOT_ALLOWED", code(() -> svc.start(7L, "BASKA@PrivateRelay.AppleID.com", null, null, null, null)));
        assertEquals("EMAIL_ALIAS_NOT_ALLOWED", code(() -> svc.start(7L, "ali+1@gmail.com", null, null, null, null)));
        assertEquals("VALIDATION_ERROR", code(() -> svc.start(7L, "123456", null, null, null, null)), "okul numarasi kisayolu yok");
        assertEquals("VALIDATION_ERROR", code(() -> svc.start(7L, "yok-at-isareti", null, null, null, null)));
        assertEquals("VALIDATION_ERROR", code(() -> svc.start(7L, "a@b", null, null, null, null)));
        verify(mail, never()).sendVerificationCode(anyString(), anyString(), anyInt(), any(Lang.class));
    }

    @Test
    void anAddressAlreadyOnAnotherAccountStillGetsACodeButVerifyFailsWithUnavailable() {
        User other = new User();
        other.setId(99L);
        other.setEmail("dolu@gmail.com");
        when(users.findByEmail("dolu@gmail.com")).thenReturn(Optional.of(other));

        // enumerasyon yok: baslangic cevabi bos bir adresle ayni, kod yine gonderilir
        var res = svc.start(7L, "dolu@gmail.com", null, null, null, null);
        assertTrue(res.sent());
        verify(mail).sendVerificationCode(eq("dolu@gmail.com"), anyString(), anyInt(), any(Lang.class));

        assertEquals("EMAIL_UNAVAILABLE", code(() -> svc.verify(7L, lastCode(), "ip")));
        assertEquals(RELAY, relayUser.getEmail(), "hesap degismedi");
        assertTrue(relayUser.isEmailRelay());
        assertTrue(relayUser.isRealEmailRequired());
    }

    @Test
    void uniqueConstraintRaceAtTheEndIsAlsoUnavailable() {
        when(users.saveAndFlush(any(User.class))).thenThrow(new org.springframework.dao.DataIntegrityViolationException("dup"));
        svc.start(7L, "yaris@gmail.com", null, null, null, null);
        assertEquals("EMAIL_UNAVAILABLE", code(() -> svc.verify(7L, lastCode(), "ip")));
    }

    // ------------------------------------------------------------------ yonetici korumasi

    @Test
    void adminAccountsCannotChangeTheirAddressAndNobodyCanMoveOntoAnAdminAddress() {
        User admin = new User();
        admin.setId(1L);
        admin.setEmail("yonetici@gmail.com");
        admin.setRole(Role.ADMIN);
        when(users.findById(1L)).thenReturn(Optional.of(admin));
        assertEquals("EMAIL_CHANGE_NOT_ALLOWED", code(() -> svc.start(1L, "yeni@gmail.com", "x", null, null, null)));

        // ADMIN_EMAILS adresine tasima: ayricalik adrese bagli oldugundan reddedilir
        svc.start(7L, "yonetici@gmail.com", null, null, null, null);
        assertEquals("EMAIL_UNAVAILABLE", code(() -> svc.verify(7L, lastCode(), "ip")));
        assertEquals(Role.USER, relayUser.getRole());
    }

    // ------------------------------------------------------------------ role olmayan hesap: yeniden dogrulama

    @Test
    void nonRelayPasswordAccountNeedsItsCurrentPassword() {
        User u = new User();
        u.setId(8L);
        u.setEmail("eski@gmail.com");
        u.setEmailVerified(true);
        u.setPasswordHash(encoder.encode("Kx7-mQ2vLp9z"));
        u.setLanguage("tr");
        when(users.findById(8L)).thenReturn(Optional.of(u));

        assertEquals("WRONG_PASSWORD", code(() -> svc.start(8L, "yeni@gmail.com", null, null, null, null)));
        assertEquals("WRONG_PASSWORD", code(() -> svc.start(8L, "yeni@gmail.com", "yanlis-parola", null, null, null)));
        verify(mail, never()).sendVerificationCode(anyString(), anyString(), anyInt(), any(Lang.class));

        svc.start(8L, "yeni@gmail.com", "Kx7-mQ2vLp9z", null, null, null);
        assertEquals("yeni@gmail.com", svc.verify(8L, lastCode(), "ip").email());
        assertEquals("yeni@gmail.com", u.getEmail());
        assertFalse(u.isRealEmailRequired());
    }

    @Test
    void sameAddressOnAVerifiedNonRelayAccountIsUnchanged() {
        User u = new User();
        u.setId(8L);
        u.setEmail("ayni@gmail.com");
        u.setEmailVerified(true);
        u.setPasswordHash(encoder.encode("Kx7-mQ2vLp9z"));
        when(users.findById(8L)).thenReturn(Optional.of(u));
        assertEquals("EMAIL_UNCHANGED", code(() -> svc.start(8L, "ayni@gmail.com", "Kx7-mQ2vLp9z", null, null, null)));
    }
}
