package edu.bingol.backend.appinfo;

import edu.bingol.backend.appinfo.AppInfoService.PlatformVersions;
import java.time.Clock;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

/**
 * Yonetici icin uygulama surum dagilimi. KAYNAK: `user_device_log` (giris yapmis kullanicilarin cihaz+surum kaydi; mobil
 * her istekte `X-App-Version` gonderir). Her (kullanici, cihaz) cifti icin SON gorulen satir sayilir; son {@value #WINDOW_DAYS}
 * gunde hic gorulmeyen cihazlar ve hic giris yapmamis cihazlar SAYILMAZ (bildirim izni olup olmamasindan bagimsiz).
 * Birim: kullanici-cihaz cifti.
 */
@Service
public class AppVersionAdminService {

    public static final int WINDOW_DAYS = 30;
    public static final String SOURCE = "USER_DEVICE_LOG";
    public static final String SOURCE_NOTE = "Giriş yapmış kullanıcıların son " + WINDOW_DAYS
            + " günde sunucuya ulaşan istekleri (sürüm başlığından). Hiç giriş yapmamış ya da " + WINDOW_DAYS
            + " gündür uygulamayı açmamış cihazlar sayılmaz; bir kişinin iki cihazı iki kez sayılır.";

    private static final String DISTRIBUTION_SQL = "SELECT t.platform AS platform, t.app_version AS app_version, "
            + "COUNT(*) AS n FROM (SELECT d.platform, d.app_version, ROW_NUMBER() OVER (PARTITION BY d.user_id, "
            + "d.device_hash ORDER BY d.last_seen_at DESC, d.id DESC) AS rn FROM user_device_log d "
            + "WHERE d.last_seen_at >= :since AND d.platform IN ('ANDROID','IOS')) t WHERE t.rn = 1 "
            + "GROUP BY t.platform, t.app_version";

    private static final java.util.regex.Pattern NUMERIC = java.util.regex.Pattern.compile("\\d+(\\.\\d+){0,3}");

    public record AppVersionCount(String platform, String version, long devices) {}

    public record VersionPlatformSummary(String platform, String minVersion, String latestVersion, String state, long total,
                                  long unknownVersion, long belowMin, long belowLatest) {}

    public record VersionDistribution(List<AppVersionCount> distribution, List<VersionPlatformSummary> platforms, long total, long belowMin,
                               long belowLatest, String source, String sourceNote, int windowDays) {}

    private final NamedParameterJdbcTemplate jdbc;
    private final AppInfoService appInfo;
    private final Clock clock;

    public AppVersionAdminService(NamedParameterJdbcTemplate jdbc, AppInfoService appInfo, Clock clock) {
        this.jdbc = jdbc;
        this.appInfo = appInfo;
        this.clock = clock;
    }

    /** Gunluk sayisal surum ("2.0.4"); arkasindaki yapi eki atilir, sayisal baslangic yoksa null (bilinmiyor). */
    static String cleanVersion(String raw) {
        if (raw == null) {
            return null;
        }
        java.util.regex.Matcher m = NUMERIC.matcher(raw.trim());
        return m.lookingAt() ? m.group() : null;
    }

    public VersionDistribution distribution() {
        List<AppVersionCount> raw = jdbc.query(DISTRIBUTION_SQL,
                new MapSqlParameterSource("since", java.sql.Timestamp.from(clock.instant().minus(Duration.ofDays(WINDOW_DAYS)))),
                (rs, i) -> new AppVersionCount(rs.getString("platform").toLowerCase(Locale.ROOT), cleanVersion(rs.getString("app_version")),
                        rs.getLong("n")));
        // "2.0.4+20004" gibi yapi surumu ekleri atilir; ayni sayisal surum tek satirda toplanir
        Map<String, Long> merged = new LinkedHashMap<>();
        for (AppVersionCount r : raw) {
            merged.merge(r.platform() + "|" + (r.version() == null ? "" : r.version()), r.devices(), Long::sum);
        }
        List<AppVersionCount> rows = new ArrayList<>();
        merged.forEach((k, n) -> {
            int bar = k.indexOf('|');
            String v = k.substring(bar + 1);
            rows.add(new AppVersionCount(k.substring(0, bar), v.isEmpty() ? null : v, n));
        });
        rows.sort((a, b) -> {
            int c = a.platform().compareTo(b.platform());
            if (c != 0) {
                return c;
            }
            if (a.version() == null || b.version() == null) {
                return a.version() == null ? (b.version() == null ? 0 : 1) : -1;
            }
            return -AppInfoService.compare(a.version(), b.version());
        });
        List<VersionPlatformSummary> platforms = new ArrayList<>();
        long total = 0;
        long belowMin = 0;
        long belowLatest = 0;
        for (String p : List.of("android", "ios")) {
            PlatformVersions pv = appInfo.platformVersions(p);
            long t = 0;
            long unknown = 0;
            long bMin = 0;
            long bLatest = 0;
            for (AppVersionCount r : rows) {
                if (!r.platform().equals(p)) {
                    continue;
                }
                t += r.devices();
                if (r.version() == null) {
                    unknown += r.devices();
                    continue;
                }
                if (AppInfoService.compare(r.version(), pv.min()) < 0) {
                    bMin += r.devices();
                }
                if (AppInfoService.compare(r.version(), pv.latest()) < 0) {
                    bLatest += r.devices();
                }
            }
            platforms.add(new VersionPlatformSummary(p, pv.min(), pv.latest(), pv.state(), t, unknown, bMin, bLatest));
            total += t;
            belowMin += bMin;
            belowLatest += bLatest;
        }
        return new VersionDistribution(rows, platforms, total, belowMin, belowLatest, SOURCE, SOURCE_NOTE, WINDOW_DAYS);
    }
}
