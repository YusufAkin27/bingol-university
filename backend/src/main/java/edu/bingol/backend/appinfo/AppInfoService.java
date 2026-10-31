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

    private static final Pattern VERSION = Pattern.compile("\\d{1,9}(\\.\\d{1,9}){0,3}"); // 9 hane: Long.parseLong tasmaz (QA: uzun surum 500 veriyordu)
    /** Tek e-posta adresi: bosluk, satir sonu, virgul/noktalivirgul ve < > yok. */
    private static final Pattern EMAIL = Pattern.compile("[A-Za-z0-9._%+-]{1,64}@[A-Za-z0-9.-]{1,190}\\.[A-Za-z]{2,24}");
    private static final Pattern PLATFORM = Pattern.compile("android|ios", Pattern.CASE_INSENSITIVE);

    public record Banner(String text, String url) {}

    public record Maintenance(boolean enabled, String message) {}

    public record Social(String instagram, String twitter, String youtube) {}

    public record AppInfo(String appName, String website, String contactEmail, String supportEmail, String phone,
                          String address, Social social, Banner banner, Maintenance maintenance, List<String> languages,
                          String operatorName, String kvkkEmail) {}

    /**
     * Surum kontrolu yaniti. `storeUrl` (https): yoneticinin yazdigi adres ya da paket/uygulama kimliginden TURETILMIS
     * adres (turetilemiyorsa null); `marketUrl`: mobilin once denedigi dogrudan magaza semasi (market:// / itms-apps://);
     * `message`: istek dilindeki istege bagli guncelleme metni (bos = null, istemci varsayilani gosterir).
     */
    public record VersionCheck(boolean updateRequired, boolean updateAvailable, String latestVersion, String storeUrl,
                               String message, String marketUrl) {}

    /** Android uygulama kimligi varsayilani; `store_package_android` bossa/gecersizse kullanilir. */
    public static final String DEFAULT_ANDROID_PACKAGE = "tr.com.bukampus.app";
    /** "Zorunluluk kapali" icin zorunlu en dusuk surum (V5 tohum degeri). */
    static final String MIN_VERSION_OFF = "1.0.0";
    static final int MAX_UPDATE_MESSAGE = 280;
    private static final Pattern ANDROID_PACKAGE = Pattern.compile("[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)+");
    private static final Pattern APPLE_ID = Pattern.compile("\\d{5,15}");

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

    /** Istemci surumu minimum surumun altindaysa updateRequired (zorunlu guncelleme); mesaj varsayilan dilde (tr). */
    public VersionCheck checkVersion(String platform, String version) {
        return checkVersion(platform, version, Lang.TR);
    }

    public VersionCheck checkVersion(String platform, String version, Lang lang) {
        if (platform == null || !PLATFORM.matcher(platform).matches() || version == null
                || !VERSION.matcher(version).matches()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_VERSION", "Geçersiz sürüm numarası.");
        }
        String p = platform.toLowerCase(java.util.Locale.ROOT);
        Map<String, String> s = publicSettings();
        String min = s.getOrDefault("min_version_" + p, "0");
        String latest = s.getOrDefault("latest_version_" + p, min);
        boolean android = p.equals("android");
        String pkg = androidPackage(s);
        String appleId = appleAppId(s);
        String market = android ? "market://details?id=" + pkg
                : appleId == null ? null : "itms-apps://apps.apple.com/app/id" + appleId;
        String derived = android ? "https://play.google.com/store/apps/details?id=" + pkg
                : appleId == null ? null : "https://apps.apple.com/app/id" + appleId;
        String store = nz(s.get("store_url_" + p));
        return new VersionCheck(compare(version, min) < 0, compare(version, latest) < 0, latest,
                store != null ? store : derived, nz(localized(s, "update_message", lang)), market);
    }

    /** `store_package_android` gecerliyse o, degilse/bossa varsayilan paket. */
    static String androidPackage(Map<String, String> s) {
        String v = s.get("store_package_android");
        return v != null && ANDROID_PACKAGE.matcher(v.trim()).matches() ? v.trim() : DEFAULT_ANDROID_PACKAGE;
    }

    /** `apple_app_id_ios` yalniz rakamsa o, degilse null (uydurma adres uretilmez). */
    static String appleAppId(Map<String, String> s) {
        String v = s.get("apple_app_id_ios");
        return v != null && APPLE_ID.matcher(v.trim()).matches() ? v.trim() : null;
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
        validateContactAndLinks(key, v);
        validateUpdateSettings(key, v);
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

    /**
     * E-posta ve baglanti ayarlari (T-017): e-posta anahtarlari (`support_email`, `contact_email`, `*.email`) gecerli tek
     * adres olmali ve satir sonu/bosluk icermemeli (Reply-To baslik enjeksiyonu); baglanti anahtarlari (`store_url_*`,
     * `banner_url`, `website`, `instagram`, `twitter`, `youtube`) `https://` ile baslamali ve kontrol/bosluk karakteri icermemeli.
     * Bos deger serbest (ayar temizleme). Gecersiz = 400 SETTING_INVALID.
     */
    static void validateContactAndLinks(String key, String v) {
        if (v.isEmpty()) {
            return;
        }
        if (isEmailKey(key)) {
            if (!EMAIL.matcher(v).matches()) {
                throw settingInvalid(key);
            }
        } else if (isLinkKey(key)) {
            if (!v.startsWith("https://") || v.length() < 9 || hasWhitespaceOrControl(v) || v.indexOf('<') >= 0
                    || v.indexOf('>') >= 0 || v.indexOf('"') >= 0) {
                throw settingInvalid(key);
            }
        }
    }

    /**
     * Guncelleme ekrani ayarlari: `update_message_*` en cok 280 karakter, HTML/baglanti/kontrol karakteri yok;
     * `store_package_android` gecerli paket adi; `apple_app_id_ios` yalniz rakam (5-15). Bos deger serbest.
     */
    static void validateUpdateSettings(String key, String v) {
        if (v.isEmpty()) {
            return;
        }
        if (key.startsWith("update_message_")) {
            String lower = v.toLowerCase(java.util.Locale.ROOT);
            if (v.length() > MAX_UPDATE_MESSAGE || v.indexOf('<') >= 0 || v.indexOf('>') >= 0 || v.indexOf('&') >= 0
                    || lower.contains("://") || lower.contains("www.") || lower.contains("javascript:")
                    || hasControl(v)) {
                throw settingInvalid(key);
            }
        } else if (key.equals("store_package_android") && !ANDROID_PACKAGE.matcher(v).matches()) {
            throw settingInvalid(key);
        } else if (key.equals("apple_app_id_ios") && !APPLE_ID.matcher(v).matches()) {
            throw settingInvalid(key);
        }
    }

    private static boolean hasControl(String s) {
        for (int i = 0; i < s.length(); i++) {
            if (Character.isISOControl(s.charAt(i))) {
                return true;
            }
        }
        return false;
    }

    // --- surum zorlama (yonetici tek tik) ---

    /** Zorlama kipi: FORCE = latest ve min bu surum; SOFT = yalniz latest; OFF = min varsayilana doner. */
    public enum EnforceMode { FORCE, SOFT, OFF }

    /** Zorlamadan once/sonra platform ayarlari (denetim ozeti ve yanit icin). */
    public record EnforceChange(String platform, EnforceMode mode, String previousMin, String previousLatest,
                                String min, String latest) {}

    /** Platformun zorlama ayarlari ve turetilmis durumu. */
    public record PlatformVersions(String platform, String min, String latest) {
        /** FORCE: zorunlu en dusuk surum varsayilanin ustunde; SOFT: yalniz oneri (latest > min); OFF: ikisi de yok. */
        public String state() {
            if (compare(min, MIN_VERSION_OFF) > 0) {
                return "FORCE";
            }
            return compare(latest, min) > 0 ? "SOFT" : "OFF";
        }
    }

    /**
     * Atomik surum zorlama. FORCE: `version` mevcut yayindaki surumun altindaysa 400 VERSION_BELOW_LATEST;
     * SOFT: `version` zorunlu en dusuk surumun altindaysa 400 VERSION_BELOW_MIN; OFF: surum aranmaz, zorunlu en dusuk
     * surum varsayilana ({@value #MIN_VERSION_OFF}) alinir. Onbellek commit'ten sonra gecersiz kilinir
     * (AppSetting varlik olayi + acik cagri): sonraki surum kontrolu ANINDA yeni sonucu verir.
     */
    @org.springframework.transaction.annotation.Transactional
    public EnforceChange enforce(String platform, String version, EnforceMode mode) {
        if (platform == null || !PLATFORM.matcher(platform).matches() || mode == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_VERSION", "Geçersiz sürüm numarası.");
        }
        String p = platform.toLowerCase(java.util.Locale.ROOT);
        AppSetting min = requireSetting("min_version_" + p);
        AppSetting latest = requireSetting("latest_version_" + p);
        String prevMin = min.getValue();
        String prevLatest = latest.getValue();
        if (mode == EnforceMode.OFF) {
            min.setValue(MIN_VERSION_OFF);
        } else {
            if (version == null || !VERSION.matcher(version.trim()).matches()) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_VERSION", "Geçersiz sürüm numarası.");
            }
            String v = version.trim();
            if (mode == EnforceMode.FORCE && compare(v, prevLatest) < 0) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "VERSION_BELOW_LATEST",
                        "Zorunlu sürüm yayındaki sürümden düşük olamaz.", prevLatest);
            }
            if (mode == EnforceMode.SOFT && compare(v, prevMin) < 0) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "VERSION_BELOW_MIN",
                        "Önerilen sürüm zorunlu en düşük sürümün altında olamaz.", prevMin);
            }
            latest.setValue(v);
            if (mode == EnforceMode.FORCE) {
                min.setValue(v);
            }
        }
        Instant now = Instant.now();
        min.setUpdatedAt(now);
        latest.setUpdatedAt(now);
        repo.save(min);
        repo.save(latest);
        cache.invalidate("appinfo");
        return new EnforceChange(p, mode, prevMin, prevLatest, min.getValue(), latest.getValue());
    }

    /** Yonetici ekrani icin platformun guncel ayarlari (onbellek yok, taze okuma). */
    public PlatformVersions platformVersions(String platform) {
        String p = platform.toLowerCase(java.util.Locale.ROOT);
        String min = repo.findById("min_version_" + p).map(AppSetting::getValue).orElse(MIN_VERSION_OFF);
        String latest = repo.findById("latest_version_" + p).map(AppSetting::getValue).orElse(min);
        return new PlatformVersions(p, min, latest);
    }

    private AppSetting requireSetting(String key) {
        return repo.findById(key)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "SETTING_NOT_FOUND", "Ayar bulunamadı."));
    }

    static boolean isEmailKey(String key) {
        return key.equals("support_email") || key.equals("contact_email") || key.endsWith("_email") || key.endsWith(".email");
    }

    static boolean isLinkKey(String key) {
        return key.startsWith("store_url_") || key.equals("banner_url") || key.equals("website")
                || key.equals("instagram") || key.equals("twitter") || key.equals("youtube");
    }

    private static boolean hasWhitespaceOrControl(String s) {
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (Character.isISOControl(c) || Character.isWhitespace(c)) {
                return true;
            }
        }
        return false;
    }

    private static ApiException settingInvalid(String key) {
        return new ApiException(HttpStatus.BAD_REQUEST, "SETTING_INVALID", "Ayar değeri geçersiz: " + key + ".", key);
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
