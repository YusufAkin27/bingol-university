package edu.bingol.backend.auth.token;

import edu.bingol.backend.config.AuthProperties;
import java.time.Duration;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
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
    private static final String TMP_PREFIX = "regtmp:";
    /** Liste dizini (ZSET, skor 0 -> sozluk sirasi), bitis dizini (ZSET, skor = bitis sn) ve kurulum isareti. */
    static final String IDX = "regidx";
    static final String IDX_EXP = "regidxexp";
    static final String IDX_READY = "regidx:ready";
    private static final int BATCH = 200;

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
        long nowSec = System.currentTimeMillis() / 1000;
        m.put("ca", String.valueOf(nowSec));
        m.put("rc", "0");
        // Yeni kayit ESKISINI BIRLESTIRMEZ (FIX-P02/A01#8): HSET eski `fa/de/gr` alanlarini birakirdi (baskasinin
        // onceden actigi kaydin fakulte/bolumu e-posta sahibinin hesabina gecerdi). Gecici anahtara yaz, RENAME ile
        // ATOMIK degistir: okuyan hicbir an bos ya da yarim kayit gormez, TTL de birlikte tasinir.
        String tmp = TMP_PREFIX + email;
        redis.delete(tmp);
        redis.opsForHash().putAll(tmp, m);
        // Sure yalnizca burada verilir; yeniden gonderim/giris TTL'i uzatmaz.
        redis.expire(tmp, ttl);
        redis.rename(tmp, key(email));
        indexAdd(email, nowSec + ttl.toSeconds());
    }

    /** Listeleme dizini: e-posta (sozluk sirasi icin skor 0) + bitis zamani (suresi dolan girdileri temizlemek icin). */
    private void indexAdd(String email, long expiresAtSec) {
        try {
            redis.opsForZSet().add(IDX, email, 0);
            redis.opsForZSet().add(IDX_EXP, email, expiresAtSec);
            // Suresi dolmus (Redis anahtari TTL ile gitmis) girdileri kucuk parcalarla ayikla
            Set<String> stale = redis.opsForZSet().rangeByScore(IDX_EXP, 0, System.currentTimeMillis() / 1000, 0, 50);
            if (stale != null && !stale.isEmpty()) {
                redis.opsForZSet().remove(IDX, stale.toArray());
                redis.opsForZSet().remove(IDX_EXP, stale.toArray());
            }
        } catch (RuntimeException e) {
            // Dizin en-iyi-caba: kayit yazildi; liste bu e-postayi gormeyebilir ama dogrulama/giris etkilenmez
        }
    }

    private void indexRemove(String email) {
        try {
            redis.opsForZSet().remove(IDX, email);
            redis.opsForZSet().remove(IDX_EXP, email);
        } catch (RuntimeException e) {
            // en-iyi-caba; suresi dolunca ayiklanir
        }
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
        ensureIndex();
        List<Entry> items = new ArrayList<>();
        String last = null;
        boolean more = false;
        String after = cursor == null || cursor.isBlank() ? null : cursor;
        outer:
        while (true) {
            // Dizinden sozluk sirasiyla parca parca oku (Redis'in tum anahtar uzayi taranmaz)
            org.springframework.data.domain.Range<String> range = after == null
                    ? org.springframework.data.domain.Range.unbounded()
                    : org.springframework.data.domain.Range.rightUnbounded(
                            org.springframework.data.domain.Range.Bound.exclusive(after));
            Set<String> batch = redis.opsForZSet().rangeByLex(IDX, range,
                    org.springframework.data.redis.connection.Limit.limit().count(BATCH));
            if (batch == null || batch.isEmpty()) {
                break;
            }
            for (String e : batch) {
                after = e;
                Entry entry = entry(e);
                if (entry == null) {
                    indexRemove(e); // Redis anahtari TTL ile gitmis
                    continue;
                }
                if (needle != null && !matches(entry, needle)) {
                    continue;
                }
                if (items.size() == size) {
                    more = true;
                    break outer;
                }
                items.add(entry);
                last = e;
            }
            if (batch.size() < BATCH) {
                break;
            }
        }
        return new EntryPage(items, more ? last : null);
    }

    /**
     * Dizin yoksa (bu surumden onceki bekleyen kayitlar) BIR KEZ mevcut `reg:*` anahtarlarindan kurulur; isaret
     * anahtari konur ve bir daha SCAN yapilmaz.
     */
    private void ensureIndex() {
        if (Boolean.TRUE.equals(redis.hasKey(IDX_READY))) {
            return;
        }
        ScanOptions opts = ScanOptions.scanOptions().match(PREFIX + "*").count(500).build();
        try (Cursor<String> c = redis.scan(opts)) {
            while (c.hasNext()) {
                String email = c.next().substring(PREFIX.length());
                Long ttlSec = redis.getExpire(key(email));
                indexAdd(email, System.currentTimeMillis() / 1000 + (ttlSec == null || ttlSec < 0 ? ttl.toSeconds() : ttlSec));
            }
        }
        redis.opsForValue().set(IDX_READY, "1");
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
        boolean had = Boolean.TRUE.equals(redis.delete(key(email)));
        indexRemove(email);
        return had;
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
        indexRemove(email);
    }

    private static String key(String email) {
        return PREFIX + email;
    }
}
