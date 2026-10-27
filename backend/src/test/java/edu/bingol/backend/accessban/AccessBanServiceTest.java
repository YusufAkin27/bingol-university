package edu.bingol.backend.accessban;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import edu.bingol.backend.accessban.AccessBanDtos.*;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.profile.AccountDataPurger;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.InOrder;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.jdbc.core.JdbcTemplate;

/** Servis + depolar + H2 uzerinde uctan uca davranis (oturum kapatma sahte; Redis gerekmez). */
@SpringBootTest
class AccessBanServiceTest {

    @Autowired AccessBanRepository bans;
    @Autowired AnonymizerRangeRepository anonymizers;
    @Autowired UserDeviceLogRepository deviceLogs;
    @Autowired BlockedAttemptLogRepository attempts;
    @Autowired UserRepository users;
    @Autowired ClientContexts contexts;
    @Autowired JdbcTemplate jdbc;

    final Clock clock = Clock.systemUTC();
    SessionService sessions;
    ApplicationEventPublisher events;
    AccessBanCache cache;
    AccessBanHits hits;
    AccessBanService service;
    ClientContext admin;
    User adminUser;

    @BeforeEach
    void setUp() {
        jdbc.update("DELETE FROM blocked_attempt_log");
        jdbc.update("DELETE FROM access_ban");
        jdbc.update("DELETE FROM user_device_log");
        jdbc.update("DELETE FROM ban280_anonymizer_range");
        sessions = mock(SessionService.class);
        events = mock(ApplicationEventPublisher.class);
        cache = new AccessBanCache(bans, anonymizers, clock, 20, false, "");
        hits = new AccessBanHits(jdbc, clock);
        service = new AccessBanService(bans, anonymizers, deviceLogs, attempts, users, cache, hits, contexts, sessions,
                events, jdbc, clock);
        admin = new ClientContext("203.0.113.9", contexts.hash("admin-device-0000001"), "WEB", null);
        adminUser = user("admin", Role.ADMIN);
    }

    User user(String prefix, Role role) {
        User u = new User();
        u.setEmail(prefix + "-" + UUID.randomUUID() + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName(prefix);
        u.setEmailVerified(true);
        u.setRole(role);
        return users.save(u);
    }

    UserDeviceLog log(long uid, String hash, String ip, Instant seen) {
        UserDeviceLog l = new UserDeviceLog();
        l.setUserId(uid);
        l.setDeviceHash(hash);
        l.setIp(ip);
        l.setIpFamily((short) (ip.contains(":") ? 6 : 4));
        l.setPlatform("ANDROID");
        l.setLastEvent("LOGIN");
        l.setFirstSeenAt(seen.minusSeconds(60));
        l.setLastSeenAt(seen);
        return deviceLogs.save(l);
    }

    static CreateBanRequest req(String kind, String value) {
        return new CreateBanRequest(kind, value, null, null, null, null, null, null);
    }

    static ApiException fail(org.junit.jupiter.api.function.Executable e) {
        return assertThrows(ApiException.class, e);
    }

    @Test
    void ipAndCidrBansAreStoredCanonicalAndActivateImmediately() {
        BlockAccessResult r = service.create(adminUser.getId(), req("CIDR", "198.51.100.77/24"), admin);
        assertEquals(1, r.bans().size());
        assertEquals("198.51.100.0/24", r.bans().get(0).value());
        assertEquals("CIDR", r.bans().get(0).kind());
        assertTrue(r.bans().get(0).effective());
        assertNotNull(cache.match(new ClientContext("198.51.100.200", null, null, null), null));
        // tek adres "IP" olarak saklanir
        assertEquals("IP", service.create(adminUser.getId(), req("CIDR", "192.0.2.5"), admin).bans().get(0).kind());
    }

    @Test
    void duplicateBanIsIdempotent() {
        service.create(adminUser.getId(), req("IP", "192.0.2.5"), admin);
        BlockAccessResult again = service.create(adminUser.getId(), req("IP", "192.0.2.5"), admin);
        assertTrue(again.bans().isEmpty());
        assertTrue(again.warnings().contains("ALREADY_BANNED"));
        assertEquals(1, bans.count());
    }

    @Test
    void selfLockoutAndPrivateNetworksAreRejected() {
        assertEquals("BAN_SELF_LOCKOUT", fail(() -> service.create(1L, req("IP", "203.0.113.9"), admin)).code());
        assertEquals("BAN_SELF_LOCKOUT", fail(() -> service.create(1L, req("CIDR", "203.0.113.0/24"), admin)).code());
        assertEquals("BAN_SELF_LOCKOUT", fail(() -> service.create(1L, req("CIDR", "10.0.0.0/8"), admin)).code());
        assertEquals("BAN_SELF_LOCKOUT", fail(() -> service.create(1L, req("IP", "127.0.0.1"), admin)).code());
        assertEquals(0, bans.count());
        // force: kendi IP'si icin bilincli onay
        CreateBanRequest forced = new CreateBanRequest("IP", "203.0.113.9", null, null, null, null, null, true);
        assertEquals(1, service.create(1L, forced, admin).bans().size());
    }

    @Test
    void ownDeviceCannotBeBannedWithoutForce() {
        String raw = "admin-device-0000001";
        assertEquals("BAN_SELF_LOCKOUT", fail(() -> service.create(1L, req("DEVICE", raw), admin)).code());
    }

    @Test
    void adminAccountsCannotBeUserBanned() {
        assertEquals("BAN_SELF_LOCKOUT",
                fail(() -> service.create(999L, req("USER", String.valueOf(adminUser.getId())), admin)).code());
        User other = user("baska-admin", Role.ADMIN);
        assertEquals("BAN_SELF_LOCKOUT",
                fail(() -> service.create(adminUser.getId(), req("USER", String.valueOf(other.getId())), admin)).code());
    }

    @Test
    void rawDeviceIdIsHashedAndNeverStored() {
        String raw = "iPhone-IDFV-1234-ABCD-5678";
        BlockAccessResult r = service.create(adminUser.getId(), req("DEVICE", raw), admin);
        String stored = r.bans().get(0).value();
        assertEquals(contexts.hash(raw), stored);
        assertEquals(64, stored.length());
        assertNotEquals(raw, stored);
        assertEquals(8, r.bans().get(0).valueShort().length());
        List<String> all = jdbc.queryForList("SELECT ban_value FROM access_ban", String.class);
        assertFalse(all.stream().anyMatch(v -> v.contains(raw)));
        // bu cihazdan gelen istek artik eslesir (baska IP, VPN gibi)
        assertNotNull(cache.match(contexts.build("192.0.2.50", raw, "IOS", null), null));
        // ham degerin ozet hali de kabul edilir
        assertTrue(service.create(adminUser.getId(), req("DEVICE", stored), admin).bans().isEmpty());
    }

    @Test
    void invalidValuesAreRejected() {
        for (CreateBanRequest bad : List.of(req("IP", "abc"), req("IP", ""), req("CIDR", "1.2.3.4/40"),
                req("DEVICE", "short"), req("DEVICE", "bosluk iceren kimlik 123"), req("USER", "abc"), req("USER", "-4"),
                req("NOPE", "1.2.3.4"), req(null, "1.2.3.4"),
                new CreateBanRequest("IP", "192.0.2.7", "NOT_A_REASON", null, null, null, null, null),
                new CreateBanRequest("IP", "192.0.2.7", null, null, Instant.now().minusSeconds(5), null, null, null))) {
            assertEquals("BAN_INVALID_VALUE", fail(() -> service.create(adminUser.getId(), bad, admin)).code());
        }
        assertEquals("USER_NOT_FOUND", fail(() -> service.create(adminUser.getId(), req("USER", "9999999"), admin)).code());
        assertEquals(0, bans.count());
    }

    @Test
    void newIpBanClosesSessionsOfMatchingUsersButNotAdmins() {
        User a = user("a", Role.USER);
        User b = user("b", Role.USER);
        User adm = user("adm2", Role.ADMIN);
        User far = user("far", Role.USER);
        Instant now = Instant.now();
        log(a.getId(), "-", "198.51.100.10", now);
        log(b.getId(), "-", "198.51.100.200", now);
        log(adm.getId(), "-", "198.51.100.30", now);
        log(far.getId(), "-", "203.0.114.1", now);

        BlockAccessResult r = service.create(adminUser.getId(), req("CIDR", "198.51.100.0/24"), admin);

        assertEquals(2, r.sessionsClosedUsers());
        verify(sessions).revokeAll(a.getId());
        verify(sessions).revokeAll(b.getId());
        verify(sessions, never()).revokeAll(adm.getId());
        verify(sessions, never()).revokeAll(far.getId());
        InOrder order = inOrder(events, sessions);
        order.verify(events).publishEvent(new AccessBlockedEvent(a.getId()));
        order.verify(sessions).revokeAll(a.getId());
    }

    @Test
    void deviceBanClosesSessionsOfEveryAccountSharingTheDevice() {
        User a = user("a", Role.USER);
        User b = user("b", Role.USER);
        String h = contexts.hash("shared-device-000001");
        log(a.getId(), h, "198.51.100.10", Instant.now());
        log(b.getId(), h, "198.51.100.11", Instant.now());

        BlockAccessResult r = service.create(adminUser.getId(), req("DEVICE", "shared-device-000001"), admin);

        assertEquals(2, r.sessionsClosedUsers());
        verify(sessions).revokeAll(a.getId());
        verify(sessions).revokeAll(b.getId());
    }

    @Test
    void blockUserBansUserDevicesAndRecentIpsTogether() {
        User target = user("hedef", Role.USER);
        User roommate = user("oda-arkadasi", Role.USER);
        Instant now = Instant.now();
        String d1 = contexts.hash("device-aaaaaaaa-0001");
        String d2 = contexts.hash("device-bbbbbbbb-0002");
        String old = contexts.hash("device-cccccccc-0003");
        log(target.getId(), d1, "198.51.100.10", now);
        log(target.getId(), d2, "198.51.100.11", now.minus(Duration.ofDays(10)));
        log(target.getId(), old, "198.51.100.12", now.minus(Duration.ofDays(60))); // cihaz penceresinde, IP disinda
        log(target.getId(), "-", "10.1.2.3", now); // ozel ag: IP engeli yok
        log(target.getId(), "-", "2001:db8::77", now);
        log(roommate.getId(), d1, "192.0.2.1", now); // ayni cihaz

        BlockAccessResult r = service.blockUser(adminUser.getId(), target.getId(),
                new BlockAccessRequest(true, true, true, "ABUSE", "tekrarlayan ihlal", null, null), admin);

        assertEquals(3, r.devicesBlocked());
        assertEquals(3, r.ipsBlocked()); // 198.51.100.10, 198.51.100.11 ve 2001:db8::77 (60 gunluk IP disarida)
        assertTrue(r.warnings().contains("SHARED_IP_RISK"));
        assertTrue(r.bans().stream().anyMatch(b -> b.kind().equals("USER") && b.userId().equals(target.getId())
                && b.userDisplayName().equals("hedef")));
        assertNotNull(cache.match(contexts.build("203.0.113.1", "device-aaaaaaaa-0001", null, null), null));
        assertNotNull(cache.match(new ClientContext("198.51.100.10", null, null, null), null));
        assertNull(cache.match(new ClientContext("198.51.100.12", null, null, null), null));
        assertNull(cache.match(new ClientContext("10.1.2.3", null, null, null), null));
        // hedef + cihazi paylasan hesap oturumdan atilir
        verify(sessions).revokeAll(target.getId());
        verify(sessions).revokeAll(roommate.getId());
    }

    @Test
    void blockUserWithoutOptionsOnlyBansTheAccount() {
        User target = user("hedef", Role.USER);
        log(target.getId(), contexts.hash("device-aaaaaaaa-0001"), "198.51.100.10", Instant.now());

        BlockAccessResult r = service.blockUser(adminUser.getId(), target.getId(),
                new BlockAccessRequest(false, false, true, null, null, null, null), admin);

        assertEquals(1, r.bans().size());
        assertEquals("USER", r.bans().get(0).kind());
        assertEquals(0, r.devicesBlocked());
        assertEquals(0, r.ipsBlocked());
        assertEquals(1, bans.count());
    }

    @Test
    void blockUserSkipsAdminsOwnDeviceAndIpWithWarning() {
        User target = user("hedef", Role.USER);
        log(target.getId(), admin.deviceHash(), "203.0.113.9", Instant.now()); // yonetici de ayni cihaz/IP'de

        BlockAccessResult r = service.blockUser(adminUser.getId(), target.getId(),
                new BlockAccessRequest(true, true, true, null, null, null, null), admin);

        assertEquals(0, r.devicesBlocked());
        assertEquals(0, r.ipsBlocked());
        assertTrue(r.warnings().contains("OWN_DEVICE_SKIPPED"));
        assertTrue(r.warnings().contains("OWN_IP_SKIPPED"));
        assertNull(cache.match(admin, null));
    }

    @Test
    void createUserBanWithAlsoFlagsDelegatesToBlockUser() {
        User target = user("hedef", Role.USER);
        log(target.getId(), contexts.hash("device-aaaaaaaa-0001"), "198.51.100.10", Instant.now());

        BlockAccessResult r = service.create(adminUser.getId(),
                new CreateBanRequest("USER", String.valueOf(target.getId()), "FRAUD", "n", null, true, true, null), admin);

        assertEquals(1, r.devicesBlocked());
        assertEquals(1, r.ipsBlocked());
        assertTrue(r.bans().stream().allMatch(b -> "FRAUD".equals(b.reasonCode())));
    }

    @Test
    void bulkUploadReportsInvalidLinesDuplicatesAndExemptions() {
        service.create(adminUser.getId(), req("CIDR", "198.51.100.0/24"), admin);
        String text = "# vpn saglayici\n198.51.100.0/24 zaten var\n192.0.2.0/24 saglayici-A\n\nbozuk-satir\n"
                + "10.0.0.0/8\n203.0.113.0/24 yonetici\n2001:db8::/32\n192.0.2.0/24 tekrar\n203.0.114.7";
        BulkResult r = service.bulk(adminUser.getId(), new BulkRequest(text, "SPAM", "toplu", null, null), admin);

        assertEquals(3, r.created()); // 192.0.2.0/24, 2001:db8::/32, 203.0.114.7
        assertEquals(2, r.alreadyBanned()); // 198.51.100.0/24 ve tekrar eden 192.0.2.0/24
        assertEquals(3, r.rejected().size());
        assertEquals(5, r.rejected().get(0).line());
        assertEquals("BAN_INVALID_VALUE", r.rejected().get(0).error());
        assertEquals("BAN_SELF_LOCKOUT", r.rejected().get(1).error()); // 10.0.0.0/8
        assertEquals("BAN_SELF_LOCKOUT", r.rejected().get(2).error()); // kendi agi
        assertEquals("saglayici-A", jdbc.queryForObject(
                "SELECT note FROM access_ban WHERE ban_value = '192.0.2.0/24'", String.class));
        assertEquals("SPAM", jdbc.queryForObject(
                "SELECT reason_code FROM access_ban WHERE ban_value = '2001:db8:0:0:0:0:0:0/32'", String.class));
    }

    @Test
    void bulkLimitIs5000LinesAndEmptyInputIsRejected() {
        StringBuilder ok = new StringBuilder();
        for (int i = 0; i < 5000; i++) {
            ok.append("# yorum satirlari sayilmaz\n");
        }
        ok.append("192.0.2.1\n");
        assertEquals(1, service.bulk(adminUser.getId(), new BulkRequest(ok.toString(), null, null, null, null), admin).created());
        StringBuilder big = new StringBuilder();
        for (int i = 0; i < 5001; i++) {
            big.append("192.0.").append(i / 250).append('.').append(i % 250 + 1).append('\n');
        }
        assertEquals("BAN_BULK_TOO_LARGE",
                fail(() -> service.bulk(adminUser.getId(), new BulkRequest(big.toString(), null, null, null, null), admin)).code());
        assertEquals("BAN_INVALID_VALUE",
                fail(() -> service.bulk(adminUser.getId(), new BulkRequest("  \n# sadece yorum", null, null, null, null), admin)).code());
    }

    @Test
    void patchRemoveAndListWithFiltersAndCursor() {
        for (int i = 1; i <= 5; i++) {
            service.create(adminUser.getId(), new CreateBanRequest("IP", "192.0.2." + i, null, "not " + i, null, null, null, null), admin);
        }
        service.create(adminUser.getId(), req("DEVICE", "device-listtest-0001"), admin);
        CursorPage<BanView> p1 = service.list(null, null, null, null, 4);
        assertEquals(4, p1.items().size());
        assertNotNull(p1.nextCursor());
        CursorPage<BanView> p2 = service.list(null, null, null, p1.nextCursor(), 4);
        assertEquals(2, p2.items().size());
        assertNull(p2.nextCursor());
        assertEquals(1, service.list("DEVICE", null, null, null, 50).items().size());
        assertEquals(1, service.list(null, null, "192.0.2.3", null, 50).items().size());
        assertEquals(1, service.list(null, null, "NOT 4", null, 50).items().size());
        assertEquals(0, service.list(null, null, "100%", null, 50).items().size()); // joker karakter kacirilir

        Long id = p1.items().get(0).id();
        service.remove(id);
        assertFalse(service.list(null, true, null, null, 50).items().stream().anyMatch(b -> b.id().equals(id)));
        assertEquals(1, service.list(null, false, null, null, 50).items().size());
        BanView off = service.list(null, false, null, null, 50).items().get(0);
        assertFalse(off.active());
        assertFalse(off.effective());

        BanView patched = service.patch(id, new PatchBanRequest("yeni not", Instant.now().plus(Duration.ofDays(1)), null, true));
        assertTrue(patched.effective());
        assertEquals("yeni not", patched.note());
        assertNotNull(patched.expiresAt());
        assertNull(service.patch(id, new PatchBanRequest(null, null, true, null)).expiresAt());
        assertEquals("BAN_INVALID_VALUE", fail(() -> service.patch(id,
                new PatchBanRequest(null, Instant.now().minusSeconds(10), null, null))).code());
        assertEquals("BAN_NOT_FOUND", fail(() -> service.remove(987654L)).code());
    }

    @Test
    void removedAndExpiredBansStopMatching() {
        BanView v = service.create(adminUser.getId(), req("IP", "192.0.2.77"), admin).bans().get(0);
        ClientContext c = new ClientContext("192.0.2.77", null, null, null);
        assertNotNull(cache.match(c, null));
        service.remove(v.id());
        assertNull(cache.match(c, null)); // yerel invalidate: TTL beklemeden
        BanView timed = service.create(adminUser.getId(), new CreateBanRequest("IP", "192.0.2.78", null, null,
                Instant.now().plusSeconds(1), null, null, null), admin).bans().get(0);
        jdbc.update("UPDATE access_ban SET expires_at = ? WHERE id = ?",
                java.sql.Timestamp.from(Instant.now().minusSeconds(5)), timed.id());
        cache.invalidate();
        assertNull(cache.match(new ClientContext("192.0.2.78", null, null, null), null));
    }

    @Test
    void hitsAndAttemptsAreRecordedAndSurfacedInStatsAndAttemptList() {
        BanView v = service.create(adminUser.getId(), req("IP", "192.0.2.90"), admin).bans().get(0);
        ClientContext c = new ClientContext("192.0.2.90", null, "ANDROID", null);
        AccessGuard guard = new AccessGuard(cache, hits);
        for (int i = 0; i < 4; i++) {
            assertNotNull(guard.blocked(c, null, "/api/auth/login"));
        }
        Stats s = service.stats();
        assertEquals(1L, s.activeBans().get("IP"));
        assertEquals(0L, s.activeBans().get("DEVICE"));
        assertEquals(1L, s.blockedAttemptsLast24h()); // ayni (engel, ip) dakikada bir gunluk satiri
        assertEquals(v.id(), s.topBans().get(0).id());
        assertEquals(4L, s.topBans().get(0).hitCount());
        assertEquals(4L, service.list(null, null, "192.0.2.90", null, 5).items().get(0).hitCount());
        CursorPage<AttemptView> a = service.attempts(v.id(), null, 10);
        assertEquals(1, a.items().size());
        assertEquals("192.0.2.90", a.items().get(0).ip());
        assertEquals("/api/auth/login", a.items().get(0).path());
        assertEquals("BAN_NOT_FOUND", fail(() -> service.attempts(424242L, null, 10)).code());
    }

    @Test
    void userDevicesShowsSharedAccountsBlockedStateAndShortHashOnly() {
        User me = user("ben", Role.USER);
        User other = user("diger-hesap", Role.USER);
        String shared = contexts.hash("shared-device-000009");
        String solo = contexts.hash("solo-device-0000010");
        Instant now = Instant.now();
        log(me.getId(), shared, "198.51.100.1", now.minus(Duration.ofDays(2)));
        log(me.getId(), shared, "198.51.100.2", now);
        log(me.getId(), solo, "198.51.100.3", now.minus(Duration.ofDays(1)));
        log(me.getId(), "-", "198.51.100.4", now);
        log(other.getId(), shared, "192.0.2.50", now);
        service.create(adminUser.getId(), req("DEVICE", solo), admin);

        UserDevices d = service.userDevices(me.getId());

        assertEquals(2, d.devices().size());
        DeviceView sharedView = d.devices().stream().filter(x -> x.deviceHash().equals(shared)).findFirst().orElseThrow();
        assertEquals(shared.substring(0, 8), sharedView.deviceShort());
        assertEquals(1, sharedView.sharedWithUsers().size());
        assertEquals("diger-hesap", sharedView.sharedWithUsers().get(0).displayName());
        assertEquals(2, sharedView.ips().size());
        assertEquals("198.51.100.1", sharedView.firstIp());
        assertEquals("198.51.100.2", sharedView.lastIp());
        assertFalse(sharedView.blocked());
        DeviceView soloView = d.devices().stream().filter(x -> x.deviceHash().equals(solo)).findFirst().orElseThrow();
        assertTrue(soloView.blocked());
        assertNotNull(soloView.banId());
        assertTrue(soloView.sharedWithUsers().isEmpty());
        assertEquals(1, d.unidentifiedIps().size());
        assertEquals("USER_NOT_FOUND", fail(() -> service.userDevices(99999999L)).code());
    }

    @Test
    void anonymizerListUploadDeleteAndLimits() {
        AnonymizerUploadResult r = service.uploadAnonymizers(new AnonymizerUpload(
                "# tor cikis\n185.220.101.0/24\n185.220.102.5 ozel-etiket\nbozuk\n185.220.101.0/24\n10.0.0.0/8\n2a0b:f4c0::/32", "tor-exit"));

        assertEquals(3, r.added());
        assertEquals(1, r.duplicates());
        assertEquals(2, r.rejected().size());
        AnonymizerList l = service.listAnonymizers(null, 50);
        assertFalse(l.enforced());
        assertEquals(3, l.total());
        assertEquals(2L, l.bySource().get("tor-exit"));
        assertEquals(1L, l.bySource().get("ozel-etiket"));
        service.deleteAnonymizer(l.items().get(0).id());
        assertEquals(2, service.listAnonymizers(null, 50).total());
        assertEquals(1, service.deleteAnonymizersBySource("tor-exit"));
        assertEquals("BAN_NOT_FOUND", fail(() -> service.deleteAnonymizer(31337L)).code());
        assertEquals(1L, service.stats().anonymizerRanges());
        StringBuilder big = new StringBuilder();
        for (int i = 0; i < 5001; i++) {
            big.append("185.1.").append(i / 250).append('.').append(i % 250 + 1).append('\n');
        }
        assertEquals("BAN_BULK_TOO_LARGE", fail(() -> service.uploadAnonymizers(new AnonymizerUpload(big.toString(), null))).code());
    }

    @Test
    void anonymizerBlockingNeedsFlagAndSkipsPrivateAddresses() {
        service.uploadAnonymizers(new AnonymizerUpload("185.220.101.0/24", "tor"));
        AccessBanCache on = new AccessBanCache(bans, anonymizers, clock, 20, true, "");
        assertNotNull(on.match(new ClientContext("185.220.101.9", null, null, null), null));
        assertNull(on.match(new ClientContext("185.220.102.9", null, null, null), null));
        assertNull(cache.match(new ClientContext("185.220.101.9", null, null, null), null)); // bayrak kapali
    }

    // ---------------------------------------------------------------- cihaz gunlugu / KVKK

    @Test
    void deviceLogUpsertsPerUserDeviceIpAndNeverStoresRawId() {
        DeviceLogService svc = new DeviceLogService(deviceLogs, clock);
        User u = user("u", Role.USER);
        String raw = "RAW-DEVICE-ID-XYZ-001";
        ClientContext c1 = contexts.build("198.51.100.5", raw, "android", "2.1.0");
        svc.record(u.getId(), c1, "LOGIN");
        svc.record(u.getId(), c1, "REFRESH");
        svc.record(u.getId(), contexts.build("198.51.100.6", raw, "android", "2.1.0"), "REFRESH"); // yeni ip = yeni satir
        svc.record(u.getId(), contexts.build("2001:db8::5", null, null, null), "REQUEST"); // cihaz yok
        svc.record(u.getId(), contexts.build("unknown", raw, null, null), "REQUEST"); // cozumlenemeyen ip atlanir

        List<UserDeviceLog> rows = deviceLogs.findByUserIdOrderByLastSeenAtDesc(u.getId());
        assertEquals(3, rows.size());
        UserDeviceLog first = rows.stream().filter(x -> x.getIp().equals("198.51.100.5")).findFirst().orElseThrow();
        assertEquals(2, first.getSeenCount());
        assertEquals("REFRESH", first.getLastEvent());
        assertEquals("ANDROID", first.getPlatform());
        assertEquals("2.1.0", first.getAppVersion());
        assertEquals(contexts.hash(raw), first.getDeviceHash());
        UserDeviceLog v6 = rows.stream().filter(x -> x.getIp().startsWith("2001")).findFirst().orElseThrow();
        assertEquals("-", v6.getDeviceHash());
        assertEquals(6, v6.getIpFamily());
        // tabloda hicbir yerde ham kimlik yok
        List<String> hashes = jdbc.queryForList("SELECT device_hash FROM user_device_log", String.class);
        assertFalse(hashes.stream().anyMatch(h -> h.contains(raw)));
    }

    @Test
    void retentionJobDeletesOldDeviceAndAttemptRowsOnly() {
        User u = user("u", Role.USER);
        Instant now = Instant.now();
        log(u.getId(), contexts.hash("device-old-00000001"), "198.51.100.1", now.minus(Duration.ofDays(91)));
        log(u.getId(), contexts.hash("device-new-00000001"), "198.51.100.2", now.minus(Duration.ofDays(89)));
        jdbc.update("INSERT INTO blocked_attempt_log (kind, ip, attempted_at) VALUES ('IP', '192.0.2.1', ?)",
                java.sql.Timestamp.from(now.minus(Duration.ofDays(95))));
        jdbc.update("INSERT INTO blocked_attempt_log (kind, ip, attempted_at) VALUES ('IP', '192.0.2.2', ?)",
                java.sql.Timestamp.from(now.minus(Duration.ofDays(1))));

        int n = new AccessBanRetentionJob(deviceLogs, attempts, mock(edu.bingol.backend.config.SchedulerLock.class), clock, 90)
                .run(now);

        assertEquals(2, n);
        assertEquals(1, deviceLogs.findByUserIdOrderByLastSeenAtDesc(u.getId()).size());
        assertEquals(1L, jdbc.queryForObject("SELECT COUNT(*) FROM blocked_attempt_log", Long.class));
    }

    @Test
    void accountDeletionPurgesDeviceHistory() throws Exception {
        User u = user("silinecek", Role.USER);
        User keep = user("kalan", Role.USER);
        log(u.getId(), contexts.hash("device-del-00000001"), "198.51.100.1", Instant.now());
        log(keep.getId(), contexts.hash("device-keep-0000001"), "198.51.100.2", Instant.now());

        // Silme SQL'i AccountDataPurger.DELETES listesinde; H2'de bulunmayan diger tablolar yuzunden yalniz bu satir calistirilir
        java.lang.reflect.Field f = AccountDataPurger.class.getDeclaredField("DELETES");
        f.setAccessible(true);
        @SuppressWarnings("unchecked")
        List<String> deletes = (List<String>) f.get(null);
        String sql = deletes.stream().filter(x -> x.contains("user_device_log")).findFirst().orElseThrow();
        jdbc.update(sql, u.getId());

        assertTrue(deviceLogs.findByUserIdOrderByLastSeenAtDesc(u.getId()).isEmpty());
        assertEquals(1, deviceLogs.findByUserIdOrderByLastSeenAtDesc(keep.getId()).size());
    }

    @Test
    void dataExportIncludesOwnHistoryWithShortSummaryOnly() {
        User u = user("u", Role.USER);
        String full = contexts.hash("device-exp-00000001");
        log(u.getId(), full, "198.51.100.1", Instant.now());
        log(u.getId(), "-", "198.51.100.2", Instant.now());

        Object out = new AccessBanExporters().accessHistoryExporter(deviceLogs).export(u.getId());

        @SuppressWarnings("unchecked")
        java.util.Map<String, Object> m = (java.util.Map<String, Object>) out;
        assertEquals(2, m.get("count"));
        assertEquals(90, m.get("retentionDays"));
        String json = m.toString();
        assertFalse(json.contains(full));
        assertTrue(json.contains(full.substring(0, 8)));
        assertEquals("accessHistory", new AccessBanExporters().accessHistoryExporter(deviceLogs).section());
    }

    @Test
    void hmacIsKeyedAndDeterministic() {
        ClientContexts a = new ClientContexts(new edu.bingol.backend.common.ClientIp("127.0.0.0/8"), "key-one-key-one-key-one-key-one-1", "j");
        ClientContexts b = new ClientContexts(new edu.bingol.backend.common.ClientIp("127.0.0.0/8"), "key-two-key-two-key-two-key-two-2", "j");
        assertEquals(a.hash("device-0123456789"), a.hash("device-0123456789"));
        assertNotEquals(a.hash("device-0123456789"), b.hash("device-0123456789"));
        assertNotEquals(a.hash("device-0123456789"), a.hash("device-0123456780"));
        assertEquals(64, a.hash("x").length());
    }
}
