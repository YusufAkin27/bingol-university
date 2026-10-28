package edu.bingol.backend.accessban;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.contains;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.user.UserRepository;
import jakarta.servlet.FilterChain;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.context.support.ResourceBundleMessageSource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

/** Filtre, onbellek ve koruma katmaninin davranisi (depolar sahte; ag/DB yok). */
class AccessBanFilterTest {

    static final String PROXY = "10.0.0.5"; // guvenilir proxy (ClientIp varsayilan guvenilirleri)

    static class MutableClock extends Clock {
        Instant now = Instant.parse("2026-10-27T10:00:00Z");

        @Override
        public ZoneId getZone() {
            return ZoneId.of("UTC");
        }

        @Override
        public Clock withZone(ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return now;
        }
    }

    final MutableClock clock = new MutableClock();
    final AccessBanRepository bans = mock(AccessBanRepository.class);
    final AnonymizerRangeRepository anon = mock(AnonymizerRangeRepository.class);
    final JdbcTemplate jdbc = mock(JdbcTemplate.class);
    final List<AccessBan> stored = new ArrayList<>();
    final List<AnonymizerRange> anonStored = new ArrayList<>();
    final ClientIp clientIp = new ClientIp("127.0.0.0/8,::1/128,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,fc00::/7");
    final ClientContexts contexts = new ClientContexts(clientIp, "", "test-secret-test-secret-test-secret-1234");
    long nextId = 1;

    @BeforeEach
    void stubs() {
        when(bans.findLive(any())).thenAnswer(inv -> stored.stream().filter(b -> b.liveAt(inv.getArgument(0))).toList());
        when(anon.findAll()).thenAnswer(inv -> new ArrayList<>(anonStored));
    }

    AccessBan ban(String kind, String value, Instant expires) {
        AccessBan b = new AccessBan();
        b.setId(nextId++);
        b.setKind(kind);
        b.setBanValue(value);
        b.setExpiresAt(expires);
        stored.add(b);
        return b;
    }

    AccessBanCache cache(boolean blockAnon, String allow) {
        return new AccessBanCache(bans, anon, clock, 20, blockAnon, allow);
    }

    AccessBanFilter filter(AccessBanCache cache, AccessBanHits hits) {
        ResourceBundleMessageSource ms = new ResourceBundleMessageSource();
        ms.setBasenames("i18n/ops");
        ms.setDefaultEncoding("UTF-8");
        ms.setFallbackToSystemLocale(false);
        return new AccessBanFilter(contexts, new AccessGuard(cache, hits), new I18n(ms, mock(UserRepository.class)));
    }

    MockHttpServletRequest req(String method, String uri, String clientIp, String deviceId) {
        MockHttpServletRequest r = new MockHttpServletRequest(method, uri);
        r.setRemoteAddr(PROXY);
        if (clientIp != null) {
            r.addHeader("X-Forwarded-For", clientIp);
        }
        if (deviceId != null) {
            r.addHeader("X-Device-Id", deviceId);
        }
        return r;
    }

    /** Filtreyi calistirir; zincir cagrildiysa true. */
    boolean passes(AccessBanFilter f, MockHttpServletRequest r, MockHttpServletResponse res) throws Exception {
        boolean[] called = {false};
        FilterChain chain = (a, b) -> called[0] = true;
        f.doFilter(r, res, chain);
        return called[0];
    }

    AccessBanHits hits() {
        return new AccessBanHits(jdbc, clock);
    }

    @Test
    void bannedIpGets403WithCodeAndTurkishMessage() throws Exception {
        ban(AccessBan.IP, "203.0.113.9", null);
        MockHttpServletResponse res = new MockHttpServletResponse();
        assertFalse(passes(filter(cache(false, ""), hits()), req("POST", "/api/auth/login", "203.0.113.9", null), res));
        assertEquals(403, res.getStatus());
        assertTrue(res.getContentType().startsWith("application/json"));
        assertEquals("{\"code\":\"ACCESS_BLOCKED\",\"message\":\"Bu cihaza veya ağa erişim kapatıldı.\"}",
                res.getContentAsString(java.nio.charset.StandardCharsets.UTF_8));
    }

    @Test
    void messageFollowsAcceptLanguageAndNeverLeaksReason() throws Exception {
        AccessBan b = ban(AccessBan.IP, "203.0.113.9", null);
        b.setNote("gizli yonetici notu");
        b.setReasonCode("FRAUD");
        MockHttpServletRequest r = req("GET", "/api/news", "203.0.113.9", null);
        r.addHeader("Accept-Language", "en-US,en;q=0.9");
        MockHttpServletResponse res = new MockHttpServletResponse();
        passes(filter(cache(false, ""), hits()), r, res);
        String body = res.getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
        assertTrue(body.contains("Access from this device or network has been blocked."));
        assertFalse(body.contains("gizli") || body.contains("FRAUD"));
        MockHttpServletRequest ar = req("GET", "/api/news", "203.0.113.9", null);
        ar.addHeader("Accept-Language", "ar,en;q=0.8");
        MockHttpServletResponse res2 = new MockHttpServletResponse();
        passes(filter(cache(false, ""), hits()), ar, res2);
        assertTrue(res2.getContentAsString(java.nio.charset.StandardCharsets.UTF_8).contains("تم حظر"));
    }

    @Test
    void unlistedIpPassesAndCidrAndIpv6Match() throws Exception {
        ban(AccessBan.CIDR, "198.51.100.0/24", null);
        ban(AccessBan.CIDR, "2001:db8::/32", null);
        AccessBanFilter f = filter(cache(false, ""), hits());
        assertTrue(passes(f, req("GET", "/api/news", "203.0.113.9", null), new MockHttpServletResponse()));
        assertFalse(passes(f, req("GET", "/api/news", "198.51.100.77", null), new MockHttpServletResponse()));
        assertTrue(passes(f, req("GET", "/api/news", "198.51.101.1", null), new MockHttpServletResponse()));
        assertFalse(passes(f, req("GET", "/api/news", "2001:db8:1::5", null), new MockHttpServletResponse()));
        assertTrue(passes(f, req("GET", "/api/news", "2001:db9::5", null), new MockHttpServletResponse()));
    }

    @Test
    void adminApiHealthOptionsAndNonApiAreExempt() throws Exception {
        ban(AccessBan.IP, "203.0.113.9", null);
        AccessBanFilter f = filter(cache(false, ""), hits());
        assertTrue(passes(f, req("GET", "/api/admin/access-bans", "203.0.113.9", null), new MockHttpServletResponse()));
        assertTrue(passes(f, req("POST", "/api/admin/users/3/block-access", "203.0.113.9", null), new MockHttpServletResponse()));
        assertTrue(passes(f, req("GET", "/actuator/health", "203.0.113.9", null), new MockHttpServletResponse()));
        assertTrue(passes(f, req("OPTIONS", "/api/auth/login", "203.0.113.9", null), new MockHttpServletResponse()));
        assertTrue(passes(f, req("GET", "/files/avatar/x.png", "203.0.113.9", null), new MockHttpServletResponse()));
        assertFalse(passes(f, req("GET", "/ws", "203.0.113.9", null), new MockHttpServletResponse()));
    }

    @Test
    void privateNetworksAndAllowlistAreNeverBlockedByIp() throws Exception {
        ban(AccessBan.CIDR, "10.0.0.0/8", null);
        ban(AccessBan.IP, "127.0.0.1", null);
        ban(AccessBan.CIDR, "198.51.100.0/24", null);
        AccessBanFilter f = filter(cache(false, "198.51.100.10, 192.0.2.0/28"), hits());
        // dogrudan baglanti (XFF yok): istemci = uzak adres
        MockHttpServletRequest direct = new MockHttpServletRequest("GET", "/api/news");
        direct.setRemoteAddr("10.9.9.9");
        assertTrue(passes(f, direct, new MockHttpServletResponse()));
        MockHttpServletRequest loop = new MockHttpServletRequest("GET", "/api/news");
        loop.setRemoteAddr("127.0.0.1");
        assertTrue(passes(f, loop, new MockHttpServletResponse()));
        // allowlist, kapsayan CIDR engeline ragmen gecer; digerleri engellenir
        assertTrue(passes(f, req("GET", "/api/news", "198.51.100.10", null), new MockHttpServletResponse()));
        assertFalse(passes(f, req("GET", "/api/news", "198.51.100.11", null), new MockHttpServletResponse()));
    }

    @Test
    void deviceBanBlocksAnonymousRequestsRegardlessOfIp() throws Exception {
        ClientContext known = contexts.build("203.0.113.1", "android-id-0123456789", "ANDROID", "1.2.3");
        ban(AccessBan.DEVICE, known.deviceHash(), null);
        AccessBanFilter f = filter(cache(false, ""), hits());
        // farkli IP (VPN) ayni cihaz: engelli
        assertFalse(passes(f, req("POST", "/api/auth/register", "192.0.2.77", "android-id-0123456789"), new MockHttpServletResponse()));
        // baska cihaz: gecer; baslik yok: gecer; gecersiz (kisa) baslik yok sayilir
        assertTrue(passes(f, req("POST", "/api/auth/register", "192.0.2.77", "other-device-9876543210"), new MockHttpServletResponse()));
        assertTrue(passes(f, req("POST", "/api/auth/register", "192.0.2.77", null), new MockHttpServletResponse()));
        assertTrue(passes(f, req("POST", "/api/auth/register", "192.0.2.77", "short"), new MockHttpServletResponse()));
    }

    @Test
    void expiredBanNoLongerBlocksAndInactiveIsIgnored() throws Exception {
        ban(AccessBan.IP, "203.0.113.9", clock.now.plus(Duration.ofMinutes(5)));
        AccessBan off = ban(AccessBan.IP, "203.0.113.10", null);
        off.setActive(false);
        AccessBanFilter f = filter(cache(false, ""), hits());
        assertFalse(passes(f, req("GET", "/api/news", "203.0.113.9", null), new MockHttpServletResponse()));
        assertTrue(passes(f, req("GET", "/api/news", "203.0.113.10", null), new MockHttpServletResponse()));
        clock.now = clock.now.plus(Duration.ofMinutes(6)); // bitis: onbellek TTL beklemeden yenilenir
        assertTrue(passes(f, req("GET", "/api/news", "203.0.113.9", null), new MockHttpServletResponse()));
    }

    @Test
    void cacheServesFromMemoryUntilTtlOrInvalidate() throws Exception {
        AccessBanCache c = cache(false, "");
        AccessBanFilter f = filter(c, hits());
        assertTrue(passes(f, req("GET", "/api/news", "203.0.113.9", null), new MockHttpServletResponse()));
        ban(AccessBan.IP, "203.0.113.9", null);
        // TTL icinde eski goruntu
        assertTrue(passes(f, req("GET", "/api/news", "203.0.113.9", null), new MockHttpServletResponse()));
        verify(bans, times(1)).findLive(any());
        c.invalidate();
        assertFalse(passes(f, req("GET", "/api/news", "203.0.113.9", null), new MockHttpServletResponse()));
        // kaldirma + invalidate
        stored.clear();
        c.invalidate();
        assertTrue(passes(f, req("GET", "/api/news", "203.0.113.9", null), new MockHttpServletResponse()));
        // TTL gecince yeniden yuklenir
        ban(AccessBan.IP, "203.0.113.9", null);
        clock.now = clock.now.plusSeconds(21);
        assertFalse(passes(f, req("GET", "/api/news", "203.0.113.9", null), new MockHttpServletResponse()));
    }

    @Test
    void databaseFailureFailsOpenAndKeepsOldSnapshot() throws Exception {
        ban(AccessBan.IP, "203.0.113.9", null);
        AccessBanCache c = cache(false, "");
        AccessBanFilter f = filter(c, hits());
        assertFalse(passes(f, req("GET", "/api/news", "203.0.113.9", null), new MockHttpServletResponse()));
        when(bans.findLive(any())).thenThrow(new RuntimeException("db down"));
        clock.now = clock.now.plusSeconds(60);
        assertFalse(passes(f, req("GET", "/api/news", "203.0.113.9", null), new MockHttpServletResponse()),
                "eski goruntu korunmali");
        assertTrue(passes(f, req("GET", "/api/news", "203.0.113.50", null), new MockHttpServletResponse()));
    }

    @Test
    void anonymizerRangesBlockOnlyWhenEnabledAndNeverPrivate() throws Exception {
        AnonymizerRange r = new AnonymizerRange();
        r.setId(5L);
        r.setCidr("185.220.101.0/24");
        anonStored.add(r);
        assertFalse(passes(filter(cache(true, ""), hits()), req("GET", "/api/news", "185.220.101.7", null),
                new MockHttpServletResponse()));
        assertTrue(passes(filter(cache(false, ""), hits()), req("GET", "/api/news", "185.220.101.7", null),
                new MockHttpServletResponse()));
        assertTrue(passes(filter(cache(true, "185.220.101.7"), hits()), req("GET", "/api/news", "185.220.101.7", null),
                new MockHttpServletResponse()));
    }

    @Test
    void userBanAppliesViaGuardOnly() {
        ban(AccessBan.USER, "42", null);
        AccessBanCache c = cache(false, "");
        AccessGuard g = new AccessGuard(c, hits());
        ClientContext ctx = new ClientContext("203.0.113.1", null, "UNKNOWN", null);
        ApiException e = assertThrows(ApiException.class, () -> g.require(ctx, 42L, "/api/auth/login"));
        assertEquals("ACCESS_BLOCKED", e.code());
        assertEquals(403, e.status().value());
        g.require(ctx, 43L, "/api/auth/login"); // baska kullanici
        g.require(null, 42L, "/x"); // baglam yok (eski cagri): atlanir
        assertNull(c.match(ctx, null));
        assertNotNull(c.match(ctx, 42L));
    }

    @Test
    void hitsAreCountedInMemoryAndFlushedInBatch() throws Exception {
        AccessBan b = ban(AccessBan.IP, "203.0.113.9", null);
        AccessBanHits h = hits();
        AccessBanFilter f = filter(cache(false, ""), h);
        for (int i = 0; i < 3; i++) {
            passes(f, req("GET", "/api/news", "203.0.113.9", null), new MockHttpServletResponse());
        }
        verify(jdbc, times(0)).update(contains("UPDATE access_ban"), anyLong(), any(), eq(b.getId())); // istekte yazim yok
        h.flush();
        verify(jdbc, times(1)).update(contains("UPDATE access_ban"), eq(3L), any(), eq(b.getId()));
        verify(jdbc, times(1)).batchUpdate(contains("INSERT INTO blocked_attempt_log"), any(java.util.Collection.class),
                anyInt(), any());
    }

    static int anyInt() {
        return org.mockito.ArgumentMatchers.anyInt();
    }
}
