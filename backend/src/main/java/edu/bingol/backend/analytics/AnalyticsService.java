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
    private static final Pattern SCREEN = Pattern.compile("[A-Za-z0-9_./-]{1,60}");

    /** Dogrulanmis, veritabanina yazilmaya hazir olay. */
    public record ValidEvent(String name, String screen, String propsJson, OffsetDateTime at) {}

    private final ActivityRepository repo;
    private final Clock clock;

    public AnalyticsService(ActivityRepository repo, Clock clock) {
        this.repo = repo;
        this.clock = clock;
    }

    @Transactional
    public void record(Long userId, List<EventIn> events) {
        Instant now = clock.instant();
        List<ValidEvent> valid = validate(events, now);
        if (valid.isEmpty()) {
            return;
        }
        repo.insertEvents(userId, valid);
        long opens = valid.stream().filter(e -> e.name().equals(OPEN_EVENT)).count();
        if (opens > 0) {
            repo.addOpens(userId, DateRange.today(clock), (int) opens);
        }
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
            out.add(new ValidEvent(e.name(), screen, propsJson(e.props()), time(e.at(), now)));
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
            String text = String.valueOf(v);
            if (text.length() > MAX_VALUE_LEN || text.indexOf('@') >= 0) {
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
