package edu.bingol.backend.appinfo;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.when;

import edu.bingol.backend.appinfo.AppInfoService.PlatformVersions;
import edu.bingol.backend.appinfo.AppVersionAdminService.DevicePlatformCount;
import edu.bingol.backend.appinfo.AppVersionAdminService.DeviceSummary;
import edu.bingol.backend.appinfo.AppVersionAdminService.PushRow;
import edu.bingol.backend.appinfo.AppVersionAdminService.RawRow;
import edu.bingol.backend.appinfo.AppVersionAdminService.VersionDistribution;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

/**
 * Cihaz sayimi: tekillestirme (ayni cihaz kimligi birden cok hesap/IP), silinmis hesap, kimliksiz satir, bayat satir,
 * surum normalizasyonu, push jetonu. Tekillestirme SQL'i H2'de gercekten kosar (ANSI pencere fonksiyonu); saf hesap
 * ({@code build}) ayrica SQL'siz test edilir.
 */
@SpringBootTest
class AppVersionDeviceCountTest {

    @Autowired AppVersionAdminService service;
    @Autowired UserRepository users;
    @Autowired AppSettingRepository settings;
    @Autowired JdbcTemplate jdbc;
    @MockitoBean StringRedisTemplate redis;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        ValueOperations<String, String> ops = org.mockito.Mockito.mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(ops);
        seed("min_version_android", "1.0.0");
        seed("latest_version_android", "2.5.3");
        seed("min_version_ios", "1.0.0");
        seed("latest_version_ios", "2.5.3");
    }

    private void seed(String key, String value) {
        AppSetting s = settings.findById(key).orElseGet(() -> {
            AppSetting n = new AppSetting();
            n.setKey(key);
            return n;
        });
        s.setValue(value);
        settings.save(s);
    }

    private User user(UserStatus st, boolean deleted) {
        User u = new User();
        u.setEmail("dc." + UUID.randomUUID().toString().substring(0, 8) + "@example.com");
        u.setPasswordHash("x");
        u.setDisplayName("dc");
        u.setEmailVerified(true);
        u.setRole(Role.USER);
        u.setStatus(st);
        if (deleted) {
            u.setDeletedAt(Instant.now());
        }
        return users.save(u);
    }

    private void log(long uid, String hash, String platform, String version, String ip, Instant seen) {
        jdbc.update("INSERT INTO user_device_log (user_id, device_hash, platform, app_version, ip, ip_family, "
                        + "first_seen_at, last_seen_at, last_event, seen_count) VALUES (?,?,?,?,?,4,?,?,'REQUEST',1)",
                uid, hash, platform, version, ip, Timestamp.from(seen), Timestamp.from(seen));
    }

    private static DevicePlatformCount plat(DeviceSummary d, String p) {
        return d.platforms().stream().filter(x -> x.platform().equals(p)).findFirst().orElseThrow();
    }

    @Test
    void uniqueDevicesDedupeAcrossAccountsIpsAndHandleStaleDeletedAndUnidentified() {
        DeviceSummary b = service.distribution().devices();
        long bPix = plat(b, "android").total();
        Instant now = Instant.now();
        String tag = UUID.randomUUID().toString().substring(0, 6);
        User a = user(UserStatus.ACTIVE, false);
        User c = user(UserStatus.ACTIVE, false);
        User gone = user(UserStatus.DELETED, true);

        // 1) AYNI telefon, iki hesap + iki IP -> 3 satir, TEK cihaz (son satir: 2.5.3)
        log(a.getId(), "h1" + tag, "ANDROID", "2.5.2", "10.1.0.1", now.minus(3, ChronoUnit.DAYS));
        log(a.getId(), "h1" + tag, "ANDROID", "2.5.3+23029", "10.1.0.2", now.minus(1, ChronoUnit.DAYS));
        log(c.getId(), "h1" + tag, "ANDROID", "2.5.3", "10.1.0.1", now.minus(2, ChronoUnit.DAYS));
        // 2) silinmis hesabin cihazi sayilmaz
        log(gone.getId(), "h2" + tag, "ANDROID", "2.5.3", "10.1.0.3", now.minus(1, ChronoUnit.DAYS));
        // 3) kimliksiz (eski surum) iki satir ayni kullanici/platform -> tek cihaz, "kimliksiz"
        log(a.getId(), "-", "IOS", "2.4.0", "10.1.0.4", now.minus(4, ChronoUnit.DAYS));
        log(a.getId(), "-", "IOS", "2.4.0", "10.1.0.5", now.minus(5, ChronoUnit.DAYS));
        // 4) bayat: 45 gun -> toplam icinde, aktif degil; 100 gun -> hic sayilmaz
        log(c.getId(), "h4" + tag, "ANDROID", "2.0.0", "10.1.0.6", now.minus(45, ChronoUnit.DAYS));
        log(c.getId(), "h5" + tag, "ANDROID", "2.0.0", "10.1.0.7", now.minus(100, ChronoUnit.DAYS));
        // 5) web -> 'other'; surumsuz android -> bilinmeyen
        log(c.getId(), "h6" + tag, "WEB", "2.5.3", "10.1.0.8", now.minus(1, ChronoUnit.DAYS));
        log(c.getId(), "h7" + tag, "ANDROID", null, "10.1.0.9", now.minus(1, ChronoUnit.HOURS));

        VersionDistribution after = service.distribution();
        DeviceSummary d = after.devices();
        assertEquals(5, d.totalUnique() - b.totalUnique(), "h1, kimliksiz ios, h4(bayat), web, surumsuz");
        assertEquals(3, plat(d, "android").total() - bPix, "h1 + h4 + h7");
        assertEquals(1, plat(d, "ios").total() - plat(b, "ios").total());
        assertEquals(1, plat(d, "other").total() - plat(b, "other").total());
        assertEquals(4, d.active30() - b.active30(), "h4 bayat degil: h1, ios, web, h7");
        assertEquals(4, d.active7() - b.active7());
        assertEquals(1, d.unidentified30() - b.unidentified30());
        // surum dagilimi: yalniz son 30 gun, 2.5.3 (yapi ekli ve eksiz birlesir)
        long v253 = after.distribution().stream()
                .filter(r -> r.platform().equals("android") && "2.5.3".equals(r.version())).mapToLong(r -> r.devices()).sum();
        long v253b = service.distribution().distribution().stream()
                .filter(r -> r.platform().equals("android") && "2.5.3".equals(r.version())).mapToLong(r -> r.devices()).sum();
        assertTrue(v253 >= 1);
        assertEquals(v253, v253b);
        assertTrue(d.unknownVersion30() - b.unknownVersion30() >= 1);
        assertTrue(d.latestPercent() >= 0 && d.latestPercent() <= 100);
    }

    @Test
    void pushCapableCountsValidTokensOfLiveUsersOnly() {
        DeviceSummary b = service.distribution().devices();
        User live = user(UserStatus.ACTIVE, false);
        User gone = user(UserStatus.DELETED, true);
        Instant now = Instant.now();
        String tag = UUID.randomUUID().toString().substring(0, 8);
        push(live.getId(), "tok1" + tag, "ANDROID", now.minus(2, ChronoUnit.DAYS));
        push(live.getId(), "tok2" + tag, "IOS", now.minus(10, ChronoUnit.DAYS));
        push(live.getId(), "tok3" + tag, "ANDROID", now.minus(90, ChronoUnit.DAYS)); // bayat
        push(gone.getId(), "tok4" + tag, "ANDROID", now.minus(1, ChronoUnit.DAYS)); // silinmis
        DeviceSummary d = service.distribution().devices();
        assertEquals(2, d.pushCapable() - b.pushCapable());
        assertEquals(1, plat(d, "android").pushCapable() - plat(b, "android").pushCapable());
        assertEquals(1, plat(d, "ios").pushCapable() - plat(b, "ios").pushCapable());
    }

    private void push(long uid, String token, String platform, Instant seen) {
        jdbc.update("INSERT INTO device (user_id, fcm_token, platform, created_at, updated_at, last_seen_at, "
                        + "rich_notifications) VALUES (?,?,?,?,?,?,FALSE)",
                uid, token, platform, Timestamp.from(seen), Timestamp.from(seen), Timestamp.from(seen));
    }

    @Test
    void pureBuildNormalizesVersionsAndComputesLatestShare() {
        List<RawRow> raw = List.of(
                new RawRow("ANDROID", "2.5.3+23029", 5, 4, 3, 1, 1),
                new RawRow("ANDROID", "2.5.3", 2, 2, 1, 0, 0),
                new RawRow("ANDROID", "2.4.0", 3, 1, 0, 0, 0),
                new RawRow("ANDROID", null, 1, 1, 1, 0, 0),
                new RawRow("IOS", "garip", 1, 1, 0, 0, 0),
                new RawRow("UNKNOWN", "2.5.3", 4, 0, 0, 0, 0));
        VersionDistribution v = AppVersionAdminService.build(raw, List.of(new PushRow("ANDROID", 6), new PushRow("IOS", 1)),
                p -> new PlatformVersions(p, "1.0.0", "2.5.3"));
        DeviceSummary d = v.devices();
        assertEquals(16, d.totalUnique());
        assertEquals(9, d.active30());
        assertEquals(5, d.active7());
        assertEquals(7, d.pushCapable());
        assertEquals(4, plat(d, "other").total());
        // son 30 gun android: 2.5.3 -> 6 (birlesir), 2.4.0 -> 1, bilinmeyen -> 1; ios bilinmeyen -> 1
        assertEquals(6, v.distribution().stream().filter(r -> "2.5.3".equals(r.version())).mapToLong(r -> r.devices()).sum());
        assertEquals(9, v.total());
        assertEquals(2, d.unknownVersion30());
        assertEquals(6, d.onLatest30());
        assertEquals(66.7, d.latestPercent(), 0.01);
    }
}
