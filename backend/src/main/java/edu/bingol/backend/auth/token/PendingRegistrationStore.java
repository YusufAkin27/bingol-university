package edu.bingol.backend.auth.token;

import edu.bingol.backend.config.AuthProperties;
import java.time.Duration;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeSet;
import org.springframework.data.redis.core.Cursor;
import org.springframework.data.redis.core.ScanOptions;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/**
 * Dogrulanmamis kayit verisi (sifre ozeti, ad, dil) e-posta dogrulanana kadar Redis'te tutulur; veritabaninda
 * hesap satiri olusmaz. Boylece baskasinin e-postasiyla onceden kayit acip sifreyi "on ele gecirme" mumkun olmaz.
 */
@Component
public class PendingRegistrationStore {

    public record Pending(String passwordHash, String displayName, String language, String faculty,
                          String department, String grade) {
        public Pending(String passwordHash, String displayName, String language) {
            this(passwordHash, displayName, language, null, null, null);
        }
    }

    /** Yonetici listesi satiri: kalan sure Redis TTL'inden, olusturma/yeniden gonderim sayaclari kayittan gelir. */
    public record Entry(String email, String displayName, String faculty, String department, String grade,
                        long createdAtEpochSec, long remainingSeconds, int resendCount) {}

    /** Yonetici listesi sayfasi: nextCursor null ise son sayfa (imlec = son e-posta, sirali). */
    public record EntryPage(List<Entry> items, String nextCursor) {}

    private static final String PREFIX = "reg:";

    private final StringRedisTemplate redis;
    private final Duration ttl;

    public PendingRegistrationStore(StringRedisTemplate redis, AuthProperties props) {
        this.redis = redis;
        this.ttl = props.pendingRegistrationTtl();
    }

    public void save(String email, Pending p) {
        Map<String, String> m = new HashMap<>(Map.of("ph", p.passwordHash(), "dn", p.displayName(), "lg", p.language()));
        if (p.faculty() != null) {
            m.put("fa", p.faculty());
        }
        if (p.department() != null) {
            m.put("de", p.department());
        }
        if (p.grade() != null) {
            m.put("gr", p.grade());
        }
        m.put("ca", String.valueOf(System.currentTimeMillis() / 1000));
        m.put("rc", "0");
        redis.opsForHash().putAll(key(email), m);
        // Sure yalnizca burada verilir; yeniden gonderim/giris TTL'i uzatmaz.
        redis.expire(key(email), ttl);
    }

    /** Yeni kod gonderildiginde sayaci artirir (kayit yoksa bir sey yapmaz; TTL'e dokunmaz). */
    public void markResend(String email) {
        if (Boolean.TRUE.equals(redis.hasKey(key(email)))) {
            redis.opsForHash().increment(key(email), "rc", 1);
        }
    }

    /** Yonetici: bekleyen kayitlari e-postaya gore sirali, imlec tabanli listeler (Redis SCAN). */
    public EntryPage list(String cursor, int size) {
        return list(cursor, size, null);
    }

    /** `q` doluysa e-posta (okul numarasi dahil) ya da ad icinde gecenler (buyuk/kucuk harf duyarsiz). */
    public EntryPage list(String cursor, int size, String q) {
        String needle = q == null || q.isBlank() ? null : q.trim().toLowerCase(java.util.Locale.ROOT);
        TreeSet<String> emails = new TreeSet<>();
        ScanOptions opts = ScanOptions.scanOptions().match(PREFIX + "*").count(500).build();
        try (Cursor<String> c = redis.scan(opts)) {
            while (c.hasNext()) {
                emails.add(c.next().substring(PREFIX.length()));
            }
        }
        List<Entry> items = new ArrayList<>();
        String last = null;
        boolean more = false;
        for (String e : (cursor == null || cursor.isBlank()) ? emails : emails.tailSet(cursor, false)) {
            if (items.size() == size) {
                more = true;
                break;
            }
            Entry entry = entry(e);
            if (entry != null && (needle == null || matches(entry, needle))) {
                items.add(entry);
                last = e;
            }
        }
        return new EntryPage(items, more ? last : null);
    }

    private static boolean matches(Entry e, String needle) {
        return e.email().toLowerCase(java.util.Locale.ROOT).contains(needle)
                || (e.displayName() != null && e.displayName().toLowerCase(java.util.Locale.ROOT).contains(needle));
    }

    private Entry entry(String email) {
        Map<Object, Object> m = redis.opsForHash().entries(key(email));
        if (m.isEmpty()) {
            return null; // tarama ile okuma arasinda suresi doldu
        }
        Long ttlSec = redis.getExpire(key(email));
        return new Entry(email, (String) m.get("dn"), (String) m.get("fa"), (String) m.get("de"),
                (String) m.get("gr"), parseLong((String) m.get("ca")), ttlSec == null ? 0 : Math.max(ttlSec, 0),
                (int) parseLong((String) m.get("rc")));
    }

    private static long parseLong(String v) {
        try {
            return v == null ? 0 : Long.parseLong(v);
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    /** Kaydi siler; vardiysa true. */
    public boolean remove(String email) {
        return Boolean.TRUE.equals(redis.delete(key(email)));
    }

    /** Kaydi okur (silmez); yoksa null. */
    public Pending find(String email) {
        Map<Object, Object> m = redis.opsForHash().entries(key(email));
        if (m.isEmpty()) {
            return null;
        }
        return new Pending((String) m.get("ph"), (String) m.get("dn"), (String) m.get("lg"),
                (String) m.get("fa"), (String) m.get("de"), (String) m.get("gr"));
    }

    public void delete(String email) {
        redis.delete(key(email));
    }

    private static String key(String email) {
        return PREFIX + email;
    }
}
