package edu.bingol.backend.analytics;

import edu.bingol.backend.analytics.AnalyticsDtos.EventIn;
import edu.bingol.backend.common.ApiException;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Mobil kullanim olaylarinin dogrulanmasi ve kaydi. Kisisel veri tasimamasi icin kisitlar siki tutulur. */
@Service
public class AnalyticsService {

    public static final int MAX_EVENTS = 50;
    static final int MAX_PROPS = 5;
    static final int MAX_VALUE_LEN = 100;
    /** Cevrimdisi birikmis olaylar icin kabul edilen azami gecmis. */
    static final Duration MAX_AGE = Duration.ofDays(7);
    /** Saat sapmasi payi. */
    static final Duration MAX_FUTURE = Duration.ofMinutes(5);
    /** Gunluk acilis sayacini artiran olay adi. */
    public static final String OPEN_EVENT = "app_open";

    private static final Pattern NAME = Pattern.compile("[a-z0-9_]{1,40}");
    private static final Pattern PROP_KEY = Pattern.compile("[a-z0-9_]{1,40}");
    /** 10+ ardisik rakam telefon/TC kimlik no benzeri kisisel veri sayilir. */
    private static final Pattern LONG_DIGITS = Pattern.compile("\\d{10,}");
    private static final Pattern SCREEN = Pattern.compile("[A-Za-z0-9_./-]{1,60}");
    private static final Pattern APP_VERSION = Pattern.compile("[A-Za-z0-9._+\\-]{1,32}");

    /** Dogrulanmis, veritabanina yazilmaya hazir olay. */
    public record ValidEvent(String name, String screen, String propsJson, OffsetDateTime at,
                             String platform, String appVersion) {

        /** Istek basligindan gelen platform/surum eklenmis kopya. */
        ValidEvent withClient(String platform, String appVersion) {
            return new ValidEvent(name, screen, propsJson, at, platform, appVersion);
        }
    }

    private final ActivityRepository repo;
    private final Clock clock;

    private static final Logger log = LoggerFactory.getLogger(AnalyticsService.class);

    /** Kullanici basina gunluk olay ust siniri (veritabani sisirme korumasi); asan olaylar sessizce atilir. */
    @Value("${app.analytics.max-events-per-day:2000}")
    private int maxEventsPerDay = 2000;
    private StringRedisTemplate redis;
    private final java.util.concurrent.ConcurrentHashMap<String, java.util.concurrent.atomic.AtomicLong> localDaily =
            new java.util.concurrent.ConcurrentHashMap<>();

    public AnalyticsService(ActivityRepository repo, Clock clock) {
        this.repo = repo;
        this.clock = clock;
    }

    @Autowired(required = false)
    void setRedis(StringRedisTemplate redis) {
        this.redis = redis;
    }

    void setMaxEventsPerDay(int n) {
        this.maxEventsPerDay = n;
    }

    /** Bugunku olay sayacini `n` kadar artirir ve yeni toplami doner (Redis INCRBY; yoksa bellek ici). */
    private long addDaily(Long userId, int n) {
        String key = "an:day:" + userId + ":" + DateRange.today(clock);
        if (redis != null) {
            try {
                Long total = redis.opsForValue().increment(key, n);
                if (total != null) {
                    if (total == n) {
                        redis.expire(key, Duration.ofDays(2));
                    }
                    return total;
                }
            } catch (RuntimeException e) {
                log.debug("Analitik gunluk sayac Redis'e yazilamadi, bellek ici yedek: {}", e.toString());
            }
        }
        if (localDaily.size() > 20_000) {
            localDaily.clear();
        }
        return localDaily.computeIfAbsent(key, k -> new java.util.concurrent.atomic.AtomicLong()).addAndGet(n);
    }

    public void record(Long userId, List<EventIn> events) {
        record(userId, events, null, null);
    }

    /**
     * @param platform istek basligindan (X-App-Platform / X-Device-Platform); yoksa olayin `props.p` degeri
     * @param appVersion istek basligindan (X-App-Version); yoksa olayin `props.v` degeri
     */
    @Transactional
    public void record(Long userId, List<EventIn> events, String platform, String appVersion) {
        Instant now = clock.instant();
        List<ValidEvent> valid = withClient(validate(events, now), events, platform, appVersion);
        if (valid.isEmpty()) {
            return;
        }
        if (maxEventsPerDay > 0) {
            long total = addDaily(userId, valid.size());
            long remaining = maxEventsPerDay - (total - valid.size());
            if (remaining <= 0) {
                log.debug("Analitik gunluk olay siniri asildi (user {}), olaylar atildi", userId);
                return;
            }
            if (remaining < valid.size()) {
                valid = valid.subList(0, (int) remaining);
            }
        }
        repo.insertEvents(userId, valid);
        long opens = valid.stream().filter(e -> e.name().equals(OPEN_EVENT)).count();
        if (opens > 0) {
            repo.addOpens(userId, DateRange.today(clock), (int) opens);
        }
    }

    /** Platform: android|ios|web (kucuk harf), baska deger null. */
    static String cleanPlatform(Object raw) {
        if (raw == null) {
            return null;
        }
        String v = String.valueOf(raw).trim().toLowerCase(java.util.Locale.ROOT);
        return v.equals("android") || v.equals("ios") || v.equals("web") ? v : null;
    }

    /** Surum: ASCII 1-32 karakter, baska bicim null. */
    static String cleanVersion(Object raw) {
        if (raw == null) {
            return null;
        }
        String v = String.valueOf(raw).trim();
        return APP_VERSION.matcher(v).matches() ? v : null;
    }

    /** Baslik degeri oncelikli; yoksa olayin kendi `p`/`v` ozelligi (baslik gondermeyen istemciler). */
    private static List<ValidEvent> withClient(List<ValidEvent> valid, List<EventIn> in, String platform,
                                               String appVersion) {
        String hp = cleanPlatform(platform);
        String hv = cleanVersion(appVersion);
        List<ValidEvent> out = new ArrayList<>(valid.size());
        for (int i = 0; i < valid.size(); i++) {
            Map<String, Object> props = in.get(i).props();
            String p = hp != null ? hp : cleanPlatform(props == null ? null : props.get("p"));
            String v = hv != null ? hv : cleanVersion(props == null ? null : props.get("v"));
            out.add(valid.get(i).withClient(p, v));
        }
        return out;
    }

    /** Tum olaylar gecerli degilse hicbiri kaydedilmez (400 INVALID_EVENT). */
    static List<ValidEvent> validate(List<EventIn> events, Instant now) {
        if (events == null || events.size() > MAX_EVENTS) {
            throw invalid();
        }
        List<ValidEvent> out = new ArrayList<>(events.size());
        for (EventIn e : events) {
            if (e == null || e.name() == null || !NAME.matcher(e.name()).matches()) {
                throw invalid();
            }
            String screen = e.screen() == null || e.screen().isBlank() ? null : e.screen().trim();
            if (screen != null && !SCREEN.matcher(screen).matches()) {
                throw invalid();
            }
            out.add(new ValidEvent(e.name(), screen, propsJson(e.props()), time(e.at(), now), null, null));
        }
        return out;
    }

    /** Sahte/yanlis saatler sunucu saatine cekilir (reddedilmez: cihaz saati bozuk olabilir). */
    static OffsetDateTime time(Instant at, Instant now) {
        Instant t = at == null || at.isBefore(now.minus(MAX_AGE)) || at.isAfter(now.plus(MAX_FUTURE)) ? now : at;
        return t.atOffset(ZoneOffset.UTC);
    }

    /** props: en cok 5 anahtar, anahtar [a-z0-9_]{1,40}, deger skaler ve <=100 karakter, e-posta benzeri ('@') yasak. */
    static String propsJson(Map<String, Object> props) {
        if (props == null || props.isEmpty()) {
            return null;
        }
        if (props.size() > MAX_PROPS) {
            throw invalid();
        }
        StringBuilder sb = new StringBuilder("{");
        boolean first = true;
        for (Map.Entry<String, Object> p : props.entrySet()) {
            Object v = p.getValue();
            if (p.getKey() == null || !PROP_KEY.matcher(p.getKey()).matches()
                    || !(v instanceof String || v instanceof Number || v instanceof Boolean)) {
                throw invalid();
            }
            String text = v instanceof Double || v instanceof Float ? plainNumber(((Number) v).doubleValue())
                    : String.valueOf(v);
            if (text.length() > MAX_VALUE_LEN || text.indexOf('@') >= 0
                    || LONG_DIGITS.matcher(text).find()) {
                throw invalid();
            }
            if (!first) {
                sb.append(',');
            }
            first = false;
            sb.append(quote(p.getKey())).append(':');
            if (v instanceof String) {
                sb.append(quote(text));
            } else {
                sb.append(text);
            }
        }
        return sb.append('}').toString();
    }

    /** 1500.0 -> "1500" (tamsayi gibi gonderilen ondalik; sonsuz/NaN gecersiz). */
    private static String plainNumber(double d) {
        if (Double.isNaN(d) || Double.isInfinite(d)) {
            throw invalid();
        }
        return d == Math.rint(d) && Math.abs(d) < 1e15 ? String.valueOf((long) d) : String.valueOf(d);
    }

    /** JSON dizgesi (RFC 8259) kacirma. */
    static String quote(String s) {
        StringBuilder sb = new StringBuilder("\"");
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '"' -> sb.append("\\\"");
                case '\\' -> sb.append("\\\\");
                case '\n' -> sb.append("\\n");
                case '\r' -> sb.append("\\r");
                case '\t' -> sb.append("\\t");
                default -> {
                    if (c < 0x20) {
                        sb.append(String.format("\\u%04x", (int) c));
                    } else {
                        sb.append(c);
                    }
                }
            }
        }
        return sb.append('"').toString();
    }

    private static ApiException invalid() {
        return new ApiException(HttpStatus.BAD_REQUEST, "INVALID_EVENT", "Geçersiz olay.");
    }
}
