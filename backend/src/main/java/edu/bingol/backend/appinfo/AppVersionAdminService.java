package edu.bingol.backend.appinfo;

import edu.bingol.backend.appinfo.AppInfoService.PlatformVersions;
import java.time.Clock;
import java.time.Duration;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.function.Function;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

/**
 * Yonetici icin uygulama surum dagilimi ve cihaz sayilari. KAYNAK: `user_device_log` (giris yapmis kullanicilarin
 * cihaz+surum kaydi; mobil her istekte `X-Device-Id` ve `X-App-Version` gonderir). BIRIM: FIZIKSEL CIHAZ yaklasigi.
 * Tekillestirme anahtari cihaz kimligi ozeti (`device_hash`): ayni telefondaki birden cok hesap ya da ayni cihazin
 * farkli IP satirlari TEK cihaz sayilir. Kimlik basligi gelmeyen (eski surum) satirlarda anahtar (kullanici, platform)
 * olur ve "kimliksiz" olarak ayrica raporlanir. Silinmis hesaplar sayilmaz. Giris yapmamis cihazlar bu kaynakta yoktur;
 * Android'de uygulama silinip yuklenince yeni kimlik uretilir (eski kayit {@value #WINDOW_DAYS} gun sonra aktif
 * sayilmaz, {@value #RETENTION_DAYS} gun boyunca toplamda kalir). Push alabilen cihaz ayri kaynaktan (`device`, FCM
 * jetonu) sayilir; jeton ile cihaz kimligi bagli olmadigindan iki sayi birbirinden cikarilmaz.
 */
@Service
public class AppVersionAdminService {

    public static final int WINDOW_DAYS = 30;
    public static final int ACTIVE_SHORT_DAYS = 7;
    /** `user_device_log` saklama suresi (AccessBanRetentionJob): toplam tekil cihaz bu pencerede sayilir. */
    public static final int RETENTION_DAYS = 90;
    /** Push jetonu temizligi (`app.push.device-ttl-days`): bundan eski jeton gecerli sayilmaz. */
    public static final int PUSH_DAYS = 60;
    public static final String SOURCE = "USER_DEVICE_LOG";
    public static final String SOURCE_NOTE = "Birim: fiziksel cihaz (cihaz kimliği özetine göre tekil; aynı telefondaki birden çok hesap tek cihazdır). "
            + "Kaynak: giriş yapmış kullanıcıların sunucuya ulaşan istekleri (sürüm başlığından). Hiç giriş yapmamış cihazlar "
            + "ve silinmiş hesaplar sayılmaz; Android'de uygulama silinip yeniden kurulursa yeni cihaz görünebilir. "
            + "Sürüm tablosu son " + WINDOW_DAYS + " günde görülen cihazları sayar.";

    /**
     * Tekil cihaz bazinda son satir; `dkey` cihaz ozeti, kimlik yoksa (kullanici, platform). Sayilar tek geciste
     * (platform, surum) basina toplulastirilir (cikti satiri kucuk). ANSI pencere fonksiyonu: H2'de de calisir.
     */
    static final String DEVICES_SQL = "SELECT t.platform AS platform, t.app_version AS app_version, COUNT(*) AS n_all, "
            + "COUNT(CASE WHEN t.last_seen_at >= :since30 THEN 1 END) AS n30, "
            + "COUNT(CASE WHEN t.last_seen_at >= :since7 THEN 1 END) AS n7, "
            + "COUNT(CASE WHEN t.fb = 1 THEN 1 END) AS fb_all, "
            + "COUNT(CASE WHEN t.fb = 1 AND t.last_seen_at >= :since30 THEN 1 END) AS fb30 "
            + "FROM (SELECT k.platform, k.app_version, k.last_seen_at, k.fb, ROW_NUMBER() OVER (PARTITION BY k.dkey "
            + "ORDER BY k.last_seen_at DESC, k.id DESC) AS rn FROM (SELECT d.id, d.platform, d.app_version, d.last_seen_at, "
            + "CASE WHEN d.device_hash = '-' THEN 1 ELSE 0 END AS fb, "
            + "CASE WHEN d.device_hash = '-' THEN 'u:' || CAST(d.user_id AS VARCHAR(20)) || ':' || d.platform "
            + "ELSE 'd:' || d.device_hash END AS dkey FROM user_device_log d WHERE d.last_seen_at >= :since "
            + "AND NOT EXISTS (SELECT 1 FROM app_user u WHERE u.id = d.user_id "
            + "AND (u.deleted_at IS NOT NULL OR u.status = 'DELETED'))) k) t "
            + "WHERE t.rn = 1 GROUP BY t.platform, t.app_version";

    /** Gecerli FCM jetonu olan cihaz satirlari, platforma gore (jeton benzersiz; silinmis/askidaki hesaplar haric). */
    static final String PUSH_SQL = "SELECT UPPER(dv.platform) AS platform, COUNT(*) AS n FROM device dv "
            + "JOIN app_user u ON u.id = dv.user_id WHERE dv.last_seen_at >= :since AND u.deleted_at IS NULL "
            + "AND u.status = 'ACTIVE' GROUP BY UPPER(dv.platform)";

    private static final java.util.regex.Pattern NUMERIC = java.util.regex.Pattern.compile("\\d+(\\.\\d+){0,3}");

    public record AppVersionCount(String platform, String version, long devices) {}

    public record VersionPlatformSummary(String platform, String minVersion, String latestVersion, String state, long total,
                                  long unknownVersion, long belowMin, long belowLatest) {}

    /** Platform kirilimi: `platform` android | ios | other (web/bilinmeyen). */
    public record DevicePlatformCount(String platform, long total, long active30, long active7, long pushCapable) {}

    /**
     * Cihaz ozeti. `totalUnique`: son {@value #RETENTION_DAYS} gunde gorulen tekil cihaz; `active30/7`: son 30/7 gunde
     * gorulen; `unidentified30`: cihaz kimligi gondermeyen (eski surum) ve kullanici basina sayilan aktif cihaz;
     * `onLatest30`/`latestPercent`: aktif android+ios cihazlarin en guncel surumde olani (yuzde, bir ondalik);
     * `unknownVersion30`: aktif cihazlardan surumu bilinmeyen; `pushCapable`: gecerli push jetonu olan.
     */
    public record DeviceSummary(long totalUnique, long active30, long active7, long unidentified30, long onLatest30,
                                double latestPercent, long unknownVersion30, long pushCapable,
                                List<DevicePlatformCount> platforms, int retentionDays, int active30Days,
                                int active7Days, int pushDays) {}

    public record VersionDistribution(List<AppVersionCount> distribution, List<VersionPlatformSummary> platforms, long total, long belowMin,
                               long belowLatest, String source, String sourceNote, int windowDays, DeviceSummary devices) {}

    /** SQL'den (platform, surum) basina toplulastirilmis satir. */
    record RawRow(String platform, String version, long all, long n30, long n7, long fbAll, long fb30) {}

    /** Platform bazinda push jetonu sayisi. */
    record PushRow(String platform, long n) {}

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

    static String platformKey(String raw) {
        String p = raw == null ? "" : raw.toLowerCase(Locale.ROOT);
        return p.equals("android") || p.equals("ios") ? p : "other";
    }

    public VersionDistribution distribution() {
        java.time.Instant now = clock.instant();
        MapSqlParameterSource ps = new MapSqlParameterSource()
                .addValue("since", java.sql.Timestamp.from(now.minus(Duration.ofDays(RETENTION_DAYS))))
                .addValue("since30", java.sql.Timestamp.from(now.minus(Duration.ofDays(WINDOW_DAYS))))
                .addValue("since7", java.sql.Timestamp.from(now.minus(Duration.ofDays(ACTIVE_SHORT_DAYS))));
        List<RawRow> raw = jdbc.query(DEVICES_SQL, ps, (rs, i) -> new RawRow(rs.getString("platform"),
                rs.getString("app_version"), rs.getLong("n_all"), rs.getLong("n30"), rs.getLong("n7"),
                rs.getLong("fb_all"), rs.getLong("fb30")));
        List<PushRow> push = jdbc.query(PUSH_SQL,
                new MapSqlParameterSource("since", java.sql.Timestamp.from(now.minus(Duration.ofDays(PUSH_DAYS)))),
                (rs, i) -> new PushRow(rs.getString("platform"), rs.getLong("n")));
        return build(raw, push, appInfo::platformVersions);
    }

    /** Saf hesap (SQL'siz): toplulastirilmis satirlardan dagilim + cihaz ozeti. Birim testi dogrudan bunu cagirir. */
    static VersionDistribution build(List<RawRow> raw, List<PushRow> push, Function<String, PlatformVersions> versions) {
        // "2.0.4+20004" gibi yapi surumu ekleri atilir; ayni sayisal surum tek satirda toplanir (yalniz son 30 gun)
        Map<String, Long> merged = new LinkedHashMap<>();
        for (RawRow r : raw) {
            String p = platformKey(r.platform());
            if (p.equals("other") || r.n30() <= 0) {
                continue;
            }
            String v = cleanVersion(r.version());
            merged.merge(p + "|" + (v == null ? "" : v), r.n30(), Long::sum);
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
        long unknownAll = 0;
        for (String p : List.of("android", "ios")) {
            PlatformVersions pv = versions.apply(p);
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
            unknownAll += unknown;
        }

        // Cihaz ozeti: tum platformlar (web/bilinmeyen "other")
        Map<String, long[]> byPlatform = new LinkedHashMap<>(); // [all, n30, n7, push]
        for (String p : List.of("android", "ios", "other")) {
            byPlatform.put(p, new long[4]);
        }
        long fb30 = 0;
        for (RawRow r : raw) {
            long[] a = byPlatform.get(platformKey(r.platform()));
            a[0] += r.all();
            a[1] += r.n30();
            a[2] += r.n7();
            fb30 += r.fb30();
        }
        long pushTotal = 0;
        for (PushRow pr : push) {
            long[] a = byPlatform.get(platformKey(pr.platform()));
            a[3] += pr.n();
            pushTotal += pr.n();
        }
        List<DevicePlatformCount> dp = new ArrayList<>();
        long all = 0;
        long a30 = 0;
        long a7 = 0;
        for (Map.Entry<String, long[]> e : byPlatform.entrySet()) {
            long[] a = e.getValue();
            dp.add(new DevicePlatformCount(e.getKey(), a[0], a[1], a[2], a[3]));
            all += a[0];
            a30 += a[1];
            a7 += a[2];
        }
        long onLatest = 0;
        for (VersionPlatformSummary s : platforms) {
            onLatest += Math.max(0, s.total() - s.belowLatest() - s.unknownVersion());
        }
        double pct = total > 0 ? Math.round((onLatest * 1000.0) / total) / 10.0 : 0.0;
        DeviceSummary ds = new DeviceSummary(all, a30, a7, fb30, onLatest, pct, unknownAll, pushTotal, dp, RETENTION_DAYS,
                WINDOW_DAYS, ACTIVE_SHORT_DAYS, PUSH_DAYS);
        return new VersionDistribution(rows, platforms, total, belowMin, belowLatest, SOURCE, SOURCE_NOTE, WINDOW_DAYS, ds);
    }
}
