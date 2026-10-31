package edu.bingol.backend.common.cache;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.CacheProperties;
import io.micrometer.core.instrument.MeterRegistry;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.LongAdder;
import java.util.function.Supplier;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.json.JsonMapper;

/**
 * Sunucu tarafi okuma onbellegi: kisa omurlu JVM ici L1 + Redis uzerinde JSON (L2). YALNIZ "herkese ayni cevap"
 * veren servis sonuclari icin kullanin (kullaniciya ozel, engel/gizlilik filtreli veya mesaj/bildirim verisi ASLA).
 *
 * <ul>
 *   <li>Anahtar: {@code cache:<ad>:<surum>:<anahtar>} (Redis); her kayit TTL'li. Yazma yolu {@link #invalidate} ile
 *       ad alanini gecersiz kilar (surum sayaci artar; eski kayitlar erisilemez olur ve TTL ile silinir).</li>
 *   <li>Tek ucus (single-flight): ayni anahtar icin ayni anda tek yukleyici calisir, digerleri sonucu bekler.</li>
 *   <li>Stale-while-error: yukleyici sunucu hatasi (DB_TIMEOUT dahil) verirse suresi dolmus kayit {@code staleTtl}
 *       icinde sunulur. Gecersiz kilinmis kayit asla sunulmaz.</li>
 *   <li>Redis yoksa/hatadaysa yalniz L1 ile (ve yukleyiciyle) calisir; hicbir zaman istegi dusurmez.</li>
 *   <li>Cache poisoning: ad alani ve anahtar beyaz listeyle sinirlidir; cagiran anahtari dogrulanmis degerlerden
 *       (dil kodu, enum, sinirli sayi) uretmelidir. Uygun olmayan anahtar onbellegi atlar.</li>
 *   <li>Donen nesneler PAYLASILIR (L1): degistirmeyin (kayit/immutable DTO).</li>
 * </ul>
 */
@Component
public class CacheService {

    private static final Logger log = LoggerFactory.getLogger(CacheService.class);
    private static final Pattern NS = Pattern.compile("[a-z0-9-]{1,32}");
    private static final Pattern KEY = Pattern.compile("[A-Za-z0-9:_.,=@-]{1,160}");
    private static final String PREFIX = "cache:";
    /** Surum sayaci TTL'i: en uzun kayit omrunden (stable + stale) cok buyuk olmali. */
    private static final Duration VERSION_TTL = Duration.ofDays(7);

    /** Bilinen tum ad alanlari: her acilista gecersiz kilinir (Redis kayitlari yeniden dagitimdan sag cikar; migration ile degisen veri bayat kalmasin). */
    public static final java.util.List<String> NAMESPACES =
            java.util.List.of("news", "menu", "status", "appinfo", "legal", "faq", "categories");

    private record L1Entry(Object value, long l1FreshUntil, long freshUntil, long staleUntil, long localVer) {}

    private record Stale(Object value) {}

    private record Result(Object value, RuntimeException error) {}

    private final CacheProperties props;
    private final JsonMapper mapper;
    private final StringRedisTemplate redis;
    private final MeterRegistry metrics;
    private final Map<String, L1Entry> l1;
    private final ConcurrentHashMap<String, AtomicLong> localVersions = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, CompletableFuture<Result>> inflight = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, LongAdder> counters = new ConcurrentHashMap<>();
    private volatile long redisDownUntil;
    /**
     * T-075 (A2-15): Redis kesintisinde L2 surum sayacina yazilamayan gecersiz kilmalar. Redis donunce ilk okumada
     * INCR ile telafi edilir; yoksa eski surumun (stable 6 sa / daily 20 dk) anahtarlari yeniden erisilebilir olur.
     */
    private final java.util.Set<String> pendingInvalidate = ConcurrentHashMap.newKeySet();

    @Autowired
    public CacheService(CacheProperties props, JsonMapper mapper, ObjectProvider<StringRedisTemplate> redis,
                        ObjectProvider<MeterRegistry> metrics) {
        this(props, mapper, redis.getIfAvailable(), metrics.getIfAvailable());
    }

    public CacheService(CacheProperties props, JsonMapper mapper, StringRedisTemplate redis, MeterRegistry metrics) {
        this.props = props;
        this.mapper = mapper;
        this.redis = redis;
        this.metrics = metrics;
        int max = Math.max(10, props.l1MaxEntries());
        this.l1 = Collections.synchronizedMap(new LinkedHashMap<>(64, 0.75f, true) {
            @Override
            protected boolean removeEldestEntry(Map.Entry<String, L1Entry> eldest) {
                return size() > max;
            }
        });
    }

    @org.springframework.context.event.EventListener(org.springframework.boot.context.event.ApplicationReadyEvent.class)
    void onReady() {
        if (props.enabled()) {
            invalidateNow(NAMESPACES.toArray(new String[0]));
        }
    }

    /** Onbellegi atlayan ornek (birim testleri ve onbellek bean'i olmayan kurulumlar): yukleyiciyi dogrudan cagirir. */
    public static CacheService passthrough() {
        return new CacheService(CacheProperties.defaults().withEnabled(false), null, (StringRedisTemplate) null, null);
    }

    // ---- okuma ----

    /** Onbellekten okur, yoksa yukleyiciyle doldurur. null sonucu da (kisa sure) onbelleklenir: anahtar SINIRLI olmali. */
    public <T> T get(String ns, String key, CacheTier tier, TypeReference<T> type, Supplier<T> loader) {
        return fetch(ns, key, tier, type, loader, true);
    }

    /** {@link #get} gibi ama null sonucu onbelleklemez (sinirsiz anahtar uzayi: ornegin kayit kimligi). */
    public <T> T getPositive(String ns, String key, CacheTier tier, TypeReference<T> type, Supplier<T> loader) {
        return fetch(ns, key, tier, type, loader, false);
    }

    @SuppressWarnings("unchecked")
    private <T> T fetch(String ns, String key, CacheTier tier, TypeReference<T> type, Supplier<T> loader,
                        boolean cacheNull) {
        if (!props.enabled() || !NS.matcher(ns).matches() || !KEY.matcher(key).matches()) {
            count(ns, "bypass");
            return loader.get();
        }
        long now = System.currentTimeMillis();
        String fullKey = ns + ":" + key;
        long lv = localVersion(ns).get();

        L1Entry e = l1.get(fullKey);
        if (e != null && e.localVer() != lv) {
            e = null;
        }
        if (e != null && now < e.l1FreshUntil()) {
            count(ns, "hit_l1");
            return (T) e.value();
        }
        Stale stale = e != null && now < e.staleUntil() ? new Stale(e.value()) : null;

        // L2 (Redis)
        String redisVer = null;
        if (redisUsable()) {
            try {
                flushPendingInvalidations();
                redisVer = redisVersion(ns);
                String raw = redis.opsForValue().get(redisKey(ns, redisVer, key));
                if (raw != null) {
                    int bar = raw.indexOf('|');
                    long freshUntil = Long.parseLong(raw.substring(0, bar));
                    if (now < freshUntil + props.staleTtl().toMillis()) {
                        T v = mapper.readValue(raw.substring(bar + 1), type);
                        if (now < freshUntil) {
                            l1Put(fullKey, new L1Entry(v, Math.min(now + props.l1Ttl().toMillis(), freshUntil),
                                    freshUntil, freshUntil + props.staleTtl().toMillis(), lv));
                            count(ns, "hit_l2");
                            return v;
                        }
                        if (stale == null) {
                            stale = new Stale(v);
                        }
                    }
                }
            } catch (RuntimeException ex) {
                // Redis hatasi veya bozuk kayit: yukleyiciye dus
                if (ex instanceof tools.jackson.core.JacksonException || ex instanceof NumberFormatException
                        || ex instanceof StringIndexOutOfBoundsException) {
                    count(ns, "l2_corrupt");
                    log.warn("Onbellek kaydi okunamadi (atlandi): {} {}", fullKey, ex.getClass().getSimpleName());
                } else {
                    redisFailed(ex);
                    redisVer = null;
                }
            }
        }

        // Yukleme: tek ucus
        String flightKey = fullKey + "@" + lv;
        CompletableFuture<Result> mine = new CompletableFuture<>();
        CompletableFuture<Result> existing = inflight.putIfAbsent(flightKey, mine);
        if (existing == null) {
            boolean done = false;
            try {
                T v = loader.get();
                store(ns, key, fullKey, tier, v, cacheNull, lv, redisVer);
                count(ns, "miss");
                mine.complete(new Result(v, null));
                done = true;
                return v;
            } catch (RuntimeException ex) {
                mine.complete(new Result(null, ex));
                done = true;
                return onLoadError(ns, fullKey, ex, stale);
            } finally {
                if (!done) {
                    mine.complete(new Result(null, new IllegalStateException("onbellek yuklemesi yarida kesildi")));
                }
                inflight.remove(flightKey, mine);
            }
        }
        try {
            Result r = existing.get(props.loadWait().toMillis(), TimeUnit.MILLISECONDS);
            if (r.error() == null) {
                count(ns, "hit_wait");
                return (T) r.value();
            }
            return onLoadError(ns, fullKey, r.error(), stale);
        } catch (TimeoutException | java.util.concurrent.ExecutionException ex) {
            count(ns, "wait_fallback");
        } catch (InterruptedException ex) {
            Thread.currentThread().interrupt();
        }
        try {
            return loader.get();
        } catch (RuntimeException ex) {
            return onLoadError(ns, fullKey, ex, stale);
        }
    }

    @SuppressWarnings("unchecked")
    private <T> T onLoadError(String ns, String fullKey, RuntimeException ex, Stale stale) {
        if (stale != null && serverSide(ex)) {
            count(ns, "stale");
            log.warn("Onbellek: yukleme basarisiz, bayat kayit sunuldu: {} ({})", fullKey, ex.getClass().getSimpleName());
            return (T) stale.value();
        }
        count(ns, "error");
        throw ex;
    }

    /** Istemci hatasi (4xx ApiException) bayat kayitla maskelenmez; geri kalan her sey sunucu/altyapi hatasidir. */
    private static boolean serverSide(RuntimeException ex) {
        return !(ex instanceof ApiException a && a.status().is4xxClientError());
    }

    private void store(String ns, String key, String fullKey, CacheTier tier, Object value, boolean cacheNull,
                       long lv, String redisVer) {
        if (value == null && !cacheNull) {
            return;
        }
        Duration ttl = tier.ttl(props);
        if (value == null && ttl.compareTo(props.negativeTtl()) > 0) {
            ttl = props.negativeTtl();
        }
        String json;
        try {
            json = value == null ? "null" : mapper.writeValueAsString(value);
        } catch (RuntimeException ex) {
            count(ns, "serialize_error");
            log.warn("Onbellek: serilestirilemedi {} ({})", fullKey, ex.getClass().getSimpleName());
            return;
        }
        if (json.length() > props.maxEntryBytes()
                || (json.length() > props.maxEntryBytes() / 3
                && json.getBytes(StandardCharsets.UTF_8).length > props.maxEntryBytes())) {
            count(ns, "oversize");
            return;
        }
        long now = System.currentTimeMillis();
        long freshUntil = now + ttl.toMillis();
        long staleMs = props.staleTtl().toMillis();
        l1Put(fullKey, new L1Entry(value, Math.min(now + props.l1Ttl().toMillis(), freshUntil), freshUntil,
                freshUntil + staleMs, lv));
        if (redisVer != null && redisUsable()) {
            try {
                redis.opsForValue().set(redisKey(ns, redisVer, key), freshUntil + "|" + json,
                        ttl.plusMillis(staleMs));
            } catch (RuntimeException ex) {
                redisFailed(ex);
            }
        }
    }

    // ---- gecersiz kilma ----

    /**
     * Ad alanlarini gecersiz kilar. Etkin bir islem varsa COMMIT'ten SONRA calisir (commit oncesi silmek, okuyucunun
     * eski veriyi yeniden doldurmasina yol acar); geri alinan islemde hic calismaz.
     */
    public void invalidate(String... namespaces) {
        if (namespaces == null || namespaces.length == 0) {
            return;
        }
        String[] copy = namespaces.clone();
        if (TransactionSynchronizationManager.isSynchronizationActive()
                && TransactionSynchronizationManager.isActualTransactionActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    invalidateNow(copy);
                }
            });
        } else {
            invalidateNow(copy);
        }
    }

    /** Hemen gecersiz kilar (islem senkronizasyonu gozetilmez). */
    public void invalidateNow(String... namespaces) {
        for (String ns : namespaces) {
            if (!NS.matcher(ns).matches()) {
                continue;
            }
            localVersion(ns).incrementAndGet();
            String prefix = ns + ":";
            synchronized (l1) {
                l1.keySet().removeIf(k -> k.startsWith(prefix));
            }
            count(ns, "invalidate");
            if (redis == null || !props.redisEnabled()) {
                continue;
            }
            if (redisUsable()) {
                try {
                    bumpRedisVersion(ns);
                } catch (RuntimeException ex) {
                    redisFailed(ex);
                    pendingInvalidate.add(ns);
                    log.warn("Onbellek gecersiz kilma Redis'e yazilamadi (L1 temizlendi, telafi icin isaretlendi): {}", ns);
                }
            } else {
                pendingInvalidate.add(ns); // Redis geri atlama penceresinde: donunce telafi
            }
        }
    }

    private void bumpRedisVersion(String ns) {
        String vk = PREFIX + ns + ":v";
        redis.opsForValue().increment(vk);
        redis.expire(vk, VERSION_TTL);
    }

    /** Kesinti sirasinda kacirilan gecersiz kilmalari L2 surum sayacina yazar; basarisizsa isaret kalir. */
    private void flushPendingInvalidations() {
        if (pendingInvalidate.isEmpty()) {
            return;
        }
        for (String ns : java.util.List.copyOf(pendingInvalidate)) {
            bumpRedisVersion(ns); // hata yukari: cagiran redisFailed ile devreye alir, isaret kalir
            pendingInvalidate.remove(ns);
            count(ns, "invalidate_compensated");
        }
    }

    /** Test/tanilama: Redis'e henuz yazilamamis gecersiz kilma sayisi. */
    int pendingInvalidationCount() {
        return pendingInvalidate.size();
    }

    // ---- gozlem ----

    /** Sayac okuma (test/tanilama): sonuc = hit_l1, hit_l2, hit_wait, miss, stale, error, bypass, invalidate... */
    public long stat(String ns, String result) {
        LongAdder a = counters.get(ns + "." + result);
        return a == null ? 0 : a.sum();
    }

    private void count(String ns, String result) {
        counters.computeIfAbsent(ns + "." + result, k -> new LongAdder()).increment();
        if (metrics != null) {
            try {
                metrics.counter("bu.cache.requests", "ns", ns, "result", result).increment();
            } catch (RuntimeException ignored) {
                // metrik hatasi istegi etkilemez
            }
        }
        if (log.isDebugEnabled()) {
            log.debug("cache {} {}", ns, result);
        }
    }

    // ---- ic ----

    private AtomicLong localVersion(String ns) {
        return localVersions.computeIfAbsent(ns, k -> new AtomicLong());
    }

    private void l1Put(String k, L1Entry e) {
        l1.put(k, e);
    }

    private boolean redisUsable() {
        return redis != null && props.redisEnabled() && System.currentTimeMillis() >= redisDownUntil;
    }

    private void redisFailed(RuntimeException ex) {
        redisDownUntil = System.currentTimeMillis() + props.redisRetryAfter().toMillis();
        log.warn("Onbellek: Redis (L2) {} sn atlandi: {}", props.redisRetryAfter().toSeconds(), ex.getClass().getSimpleName());
    }

    private String redisVersion(String ns) {
        String v = redis.opsForValue().get(PREFIX + ns + ":v");
        return v == null ? "0" : v;
    }

    private static String redisKey(String ns, String ver, String key) {
        return PREFIX + ns + ":" + ver + ":" + key;
    }
}
