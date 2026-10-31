package edu.bingol.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.auth.dto.TokenResponse;
import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.auth.token.PendingRegistrationStore;
import edu.bingol.backend.auth.token.RefreshTokenService;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.auth.token.VerificationService;
import edu.bingol.backend.catalog.CatalogService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.config.JwtProperties;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.time.Duration;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

/** T-007: kaybolan refresh yanitinin yeniden denemesi AYNI cifti alir ve oturumlari kapatmaz; calinti yine kapatir. */
class RefreshIdempotencyTest {

    private final FakeRedis fake = new FakeRedis();
    private final RefreshTokenService refresh = new RefreshTokenService(fake.template,
            new JwtProperties("test-secret-test-secret-test-secret-1234", 15, 30));
    private final UserRepository users = mock(UserRepository.class);
    private final SessionService sessions = mock(SessionService.class);
    private final JwtService jwt = mock(JwtService.class);
    private final AtomicInteger seq = new AtomicInteger();
    private final AuthService auth = new AuthService(users, new BCryptPasswordEncoder(4), jwt, refresh,
            mock(VerificationService.class), new AdminProperties(List.of()), mock(AccountCreator.class),
            mock(PendingRegistrationStore.class), sessions, new CatalogService());

    RefreshIdempotencyTest() {
        User u = new User();
        u.setId(7L);
        u.setEmail("ali@bingol.edu.tr");
        u.setEmailVerified(true);
        u.setStatus(UserStatus.ACTIVE);
        when(users.findById(7L)).thenReturn(Optional.of(u));
        when(jwt.createAccessToken(any(), any())).thenAnswer(i -> "acc-" + seq.incrementAndGet());
        when(jwt.accessTtl()).thenReturn(Duration.ofMinutes(15));
    }

    @Test
    void retryOfALostRefreshResponseReturnsTheSamePairAndKeepsSessions() {
        String old = refresh.issue(7L, "mobile");

        TokenResponse first = auth.refresh(old);
        TokenResponse retry = auth.refresh(old); // yanit kayboldu, istemci ayni eski token'la yeniden denedi

        assertEquals(first, retry);
        verify(sessions, never()).revokeAll(any());
        // yeni refresh token hala tek ve gecerli
        assertEquals(7L, refresh.peekUserId(first.refreshToken()));
    }

    @Test
    void replayStopsWorkingOnceTheNewPairHasBeenRotatedAgain() {
        String old = refresh.issue(7L, "mobile");
        TokenResponse first = auth.refresh(old);
        TokenResponse second = auth.refresh(first.refreshToken()); // istemci yeni cifti aldi ve kullandi
        assertNotEquals(first.refreshToken(), second.refreshToken());

        // eski token tekrar sunulursa canlanmaz (first.refresh tuketildi); tolerans icinde oldugu icin tum oturumlar da kapanmaz
        ApiException e = assertThrows(ApiException.class, () -> auth.refresh(old));
        assertEquals("INVALID_REFRESH_TOKEN", e.code());
        verify(sessions, never()).revokeAll(any());
    }

    @Test
    void stolenOldTokenReusedAfterTheGraceWindowStillRevokesEverySession() {
        String old = refresh.issue(7L, "mobile");
        TokenResponse first = auth.refresh(old);
        auth.refresh(first.refreshToken()); // zincir ilerledi: replay artik gecerli degil

        // tuketim 60 sn once olmus gibi (tolerans 10 sn); rotasyon kaydi da suresi dolmus
        String hash = Hashing.sha256(old);
        fake.values.put("rtused:" + hash, "7:" + (System.currentTimeMillis() - 60_000));
        fake.values.remove("rtnext:" + hash);

        ApiException e = assertThrows(ApiException.class, () -> auth.refresh(old));

        assertEquals("INVALID_REFRESH_TOKEN", e.code());
        verify(sessions).revokeAll(7L);
    }

    @Test
    void rotationRecordIsSealedAndOnlyOpensWithTheOldToken() {
        String old = refresh.issue(7L, "web");
        TokenResponse first = auth.refresh(old);
        String sealed = fake.values.get("rtnext:" + Hashing.sha256(old));

        assertNotNull(sealed);
        assertFalse(sealed.contains(first.refreshToken()), "yeni refresh token Redis'te acik metin olmamali");
        assertFalse(sealed.contains(first.accessToken()));
        assertEquals(RefreshTokenService_NEXT_TTL, fake.ttls.get("rtnext:" + Hashing.sha256(old)));
        assertNotNull(refresh.replayRotation(old, p -> true));
        // baska bir token'la (yanlis anahtar) acilamaz
        fake.values.put("rtnext:" + Hashing.sha256("baska"), sealed);
        assertNull(refresh.replayRotation("baska", p -> true));
        // yeni cift gecerli degilse (predicate false) donmez
        assertNull(refresh.replayRotation(old, p -> false));
    }

    private static final Duration RefreshTokenService_NEXT_TTL = Duration.ofSeconds(45);
}
