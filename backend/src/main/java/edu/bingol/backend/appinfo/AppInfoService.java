package edu.bingol.backend.appinfo;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.cache.CacheService;
import edu.bingol.backend.common.cache.CacheTier;
import edu.bingol.backend.i18n.Lang;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import tools.jackson.core.type.TypeReference;

@Service
public class AppInfoService {

    public static final String FACULTIES_KEY = "faculties";

    private static final Pattern VERSION = Pattern.compile("\\d+(\\.\\d+){0,3}");
    private static final Pattern PLATFORM = Pattern.compile("android|ios", Pattern.CASE_INSENSITIVE);

    public record Banner(String text, String url) {}

    public record Maintenance(boolean enabled, String message) {}

    public record Social(String instagram, String twitter, String youtube) {}

    public record AppInfo(String appName, String website, String contactEmail, String supportEmail, String phone,
                          String address, Social social, Banner banner, Maintenance maintenance, List<String> languages,
                          String operatorName, String kvkkEmail) {}

    public record VersionCheck(boolean updateRequired, boolean updateAvailable, String latestVersion, String storeUrl) {}

    private static final TypeReference<Map<String, String>> SETTINGS = new TypeReference<>() { };

    private final AppSettingRepository repo;
    private CacheService cache = CacheService.passthrough();

    public AppInfoService(AppSettingRepository repo) {
        this.repo = repo;
    }

    /** Sunucu onbellegi `appinfo` ad alani; ayar yazmasi (AppSetting varlik olayi) gecersiz kilar. */
    @Autowired(required = false)
    void setCache(CacheService cache) {
        this.cache = cache;
    }

    /** Herkese acik okuma yollari icin (app/info, surum kontrolu): onbellekli ayar haritasi. Yonetici `all()` kullanir. */
    private Map<String, String> publicSettings() {
        return cache.get("appinfo", "all", CacheTier.STABLE, SETTINGS, this::all);
    }

    /** Herkese acik bilgi; banner ve bakim mesaji istenen dilde (yoksa tr). Bos degerler null doner. */
    public AppInfo info(Lang lang) {
        Map<String, String> s = publicSettings();
        return new AppInfo(
                nz(s.get("app_name")), nz(s.get("website")), nz(s.get("contact_email")), nz(s.get("support_email")),
                nz(s.get("phone")), nz(s.get("address")),
                new Social(nz(s.get("instagram")), nz(s.get("twitter")), nz(s.get("youtube"))),
                nz(localized(s, "banner_text", lang)) == null ? null
                        : new Banner(localized(s, "banner_text", lang), nz(s.get("banner_url"))),
                new Maintenance("true".equalsIgnoreCase(s.get("maintenance_mode")),
                        localized(s, "maintenance_message", lang)),
                List.of(Lang.TR.code(), Lang.EN.code(), Lang.AR.code()),
                // Uygulamayi isleten / veri sorumlusunun ADI ve KVKK e-postasi (sozlesmelerle ayni ayar); adres/kimlik YOK
                nz(s.get("legal.controller.name")), nz(s.get("legal.controller.email")));
    }

    /** Istemci surumu minimum surumun altindaysa updateRequired (zorunlu guncelleme). */
    public VersionCheck checkVersion(String platform, String version) {
        if (platform == null || !PLATFORM.matcher(platform).matches() || version == null
                || !VERSION.matcher(version).matches()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_VERSION", "Geçersiz sürüm numarası.");
        }
        String p = platform.toLowerCase();
        Map<String, String> s = publicSettings();
        String min = s.getOrDefault("min_version_" + p, "0");
        String latest = s.getOrDefault("latest_version_" + p, min);
        return new VersionCheck(compare(version, min) < 0, compare(version, latest) < 0, latest,
                nz(s.get("store_url_" + p)));
    }

    // --- yonetici ---

    /** `faculties` ayarindan (';' ile ayrilmis) temiz liste; ayar yoksa/bossa bos liste. */
    public List<String> faculties() {
        return repo.findById(FACULTIES_KEY).map(s -> splitFaculties(s.getValue())).orElseGet(List::of);
    }

    static List<String> splitFaculties(String raw) {
        if (raw == null || raw.isBlank()) {
            return List.of();
        }
        return java.util.Arrays.stream(raw.split(";")).map(String::trim).filter(s -> !s.isEmpty()).distinct().toList();
    }

    public Map<String, String> all() {
        return repo.findAll().stream().collect(Collectors.toMap(AppSetting::getKey, AppSetting::getValue, (a, b) -> a,
                TreeMap::new));
    }

    public void set(String key, String value) {
        AppSetting setting = repo.findById(key)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "SETTING_NOT_FOUND", "Ayar bulunamadı."));
        String v = value == null ? "" : value.trim();
        if ((key.startsWith("min_version_") || key.startsWith("latest_version_")) && !VERSION.matcher(v).matches()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_VERSION", "Geçersiz sürüm numarası.");
        }
        if (key.equals("maintenance_mode") && !v.equals("true") && !v.equals("false")) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Değer true veya false olmalıdır.");
        }
        if ((key.startsWith("store_url_") || key.equals("banner_url") || key.equals("website")) && !v.isEmpty()
                && !v.startsWith("https://")) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Bağlantı https:// ile başlamalıdır.");
        }
        if (key.equals(FACULTIES_KEY)) {
            // Her fakulte <=120 karakter, tekrarsiz; toplam <=1000 karakter
            List<String> list = splitFaculties(v);
            if (list.stream().anyMatch(s -> s.length() > 120)) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Her fakülte adı en fazla 120 karakter olabilir.");
            }
            v = String.join(";", list);
            if (v.length() > 1000) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Fakülte listesi en fazla 1000 karakter olabilir.");
            }
        }
        setting.setValue(v);
        setting.setUpdatedAt(Instant.now());
        repo.save(setting);
    }

    // --- yardimcilar ---

    /** Sayisal surum karsilastirma: "1.10.0" > "1.9.3". Eksik parcalar 0 sayilir. */
    static int compare(String a, String b) {
        String[] x = a.split("\\.");
        String[] y = b.split("\\.");
        for (int i = 0; i < Math.max(x.length, y.length); i++) {
            long xi = i < x.length ? Long.parseLong(x[i]) : 0;
            long yi = i < y.length ? Long.parseLong(y[i]) : 0;
            if (xi != yi) {
                return Long.compare(xi, yi);
            }
        }
        return 0;
    }

    private static String localized(Map<String, String> s, String base, Lang lang) {
        String v = s.get(base + "_" + lang.code());
        return v == null || v.isBlank() ? s.get(base + "_" + Lang.TR.code()) : v;
    }

    private static String nz(String v) {
        return v == null || v.isBlank() ? null : v;
    }
}
