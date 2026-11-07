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
    void stolenOldTokenReusedAfterTheGraceWindowClosesOnlyThatSessionFamily() throws Exception {
        String old = refresh.issue(7L, "mobile");
        Thread.sleep(3); // baska girisin authTime'i farkli olsun
        String otherDevice = refresh.issue(7L, "web"); // kullanicinin ayri bir girisi (baska aile)
        TokenResponse first = auth.refresh(old);
        TokenResponse second = auth.refresh(first.refreshToken()); // zincir ilerledi: replay artik gecerli degil

        // tuketim 60 sn once olmus gibi (tolerans 10 sn); rotasyon kaydi da suresi dolmus
        String hash = Hashing.sha256(old);
        String[] f = fake.values.get("rtused:" + hash).split(":");
        assertEquals(4, f.length, "rtused degeri sahip:an:istemci:girisAni olmali");
        fake.values.put("rtused:" + hash, f[0] + ":" + (System.currentTimeMillis() - 60_000) + ":" + f[2] + ":" + f[3]);
        fake.values.remove("rtnext:" + hash);

        ApiException e = assertThrows(ApiException.class, () -> auth.refresh(old));

        assertEquals("INVALID_REFRESH_TOKEN", e.code());
        verify(sessions, never()).revokeAll(any()); // K1: tum cihazlar DEGIL
        assertNull(refresh.peekUserId(second.refreshToken()), "calinti suphesi olan ailenin canli token'i kapanir");
        assertEquals(7L, refresh.peekUserId(otherDevice), "kullanicinin diger girisi acik kalir");
    }

    @Test
    void concurrentSecondRequestGetsRetryableConflictInsteadOfSessionEnd() {
        String old = refresh.issue(7L, "mobile");
        // ilk istek token'i tuketti ama yeni cifti henuz yazmadi (araya giren es zamanli istek)
        refresh.consumeSession(old);

        ApiException e = assertThrows(ApiException.class, () -> auth.refresh(old));

        assertEquals("REFRESH_IN_PROGRESS", e.code());
        assertEquals(409, e.status().value());
        verify(sessions, never()).revokeAll(any());
    }

    @Test
    void concurrentSecondRequestReceivesTheSamePairWhenTheFirstFinishesDuringTheShortWait() throws Exception {
        String old = refresh.issue(7L, "mobile");
        refresh.consumeSession(old);
        TokenResponse winner = new TokenResponse("acc-w", refresh.issue(7L, "mobile"), 900, "Bearer");
        Thread t = new Thread(() -> {
            try {
                Thread.sleep(10); // bekleme penceresinin (150 ms) cok altinda: yuklu makinede de kararli
            } catch (InterruptedException ignored) {
                // yoksay
            }
            refresh.rememberRotation(old, winner.accessToken() + "\n" + winner.refreshToken() + "\n900\nBearer");
        });
        t.start();

        TokenResponse got = null;
        RuntimeException err = null;
        try {
            got = auth.refresh(old);
        } catch (RuntimeException e) {
            err = e;
        }
        t.join();

        assertNotNull(fake.values.get("rtnext:" + Hashing.sha256(old)), "ilk istek rotasyon kaydini yazdi");
        assertNotNull(fake.values.get("rt:" + Hashing.sha256(winner.refreshToken())), "yeni refresh token canli");
        assertNull(err, String.valueOf(err));
        assertEquals(winner, got);
    }

    @Test
    void lostResponseRetryAfterTheOldFortyFiveSecondsStillGetsThePairAndKeepsAllSessions() {
        String old = refresh.issue(7L, "mobile");
        TokenResponse first = auth.refresh(old);
        // istemci 4 dakika sonra (eski 45 sn penceresinin ucuncu kati) ayni eski token'la yeniden dener
        String hash = Hashing.sha256(old);
        String[] f = fake.values.get("rtused:" + hash).split(":");
        fake.values.put("rtused:" + hash, f[0] + ":" + (System.currentTimeMillis() - 240_000) + ":" + f[2] + ":" + f[3]);

        TokenResponse retry = auth.refresh(old);

        assertEquals(first, retry);
        verify(sessions, never()).revokeAll(any());
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

    private static final Duration RefreshTokenService_NEXT_TTL = Duration.ofMinutes(5);
}
