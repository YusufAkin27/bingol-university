package edu.bingol.backend.crypto;

import edu.bingol.backend.crypto.ConversationKeyStore.StoredKey;
import edu.bingol.backend.crypto.CryptoException.Reason;
import java.nio.ByteBuffer;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.LongSupplier;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

/**
 * Konusma basina veri anahtari (DEK) yonetimi: uretir, ana anahtarla (KEK) sarar, onbellekler,
 * ana anahtar degisince yeniden sarar. Ham DEK yalnizca bellekte (TTL'li onbellek) bulunur.
 */
@Service
public class ConversationKeyService {

    private static final Logger log = LoggerFactory.getLogger(ConversationKeyService.class);
    private static final int REWRAP_BATCH = 200;

    /** Aktif DEK ve surumu. */
    public record DekRef(int version, SecretKey key) {}

    public record RewrapResult(int rewrapped, int failed) {}

    private record Cached(SecretKey key, long expiresAtMillis) {}

    private final ConversationKeyStore store;
    private final KeyProvider keys;
    private final CryptoService crypto;
    private final CryptoMetrics metrics;
    private final long ttlMillis;
    private final int maxEntries;
    private final LongSupplier clock;
    private final Map<String, Cached> cache = new ConcurrentHashMap<>();

    @Autowired
    public ConversationKeyService(ConversationKeyStore store, KeyProvider keys, CryptoService crypto,
                                  CryptoMetrics metrics, CryptoProperties props) {
        this(store, keys, crypto, metrics, props, System::currentTimeMillis);
    }

    ConversationKeyService(ConversationKeyStore store, KeyProvider keys, CryptoService crypto,
                           CryptoMetrics metrics, CryptoProperties props, LongSupplier clock) {
        this.store = store;
        this.keys = keys;
        this.crypto = crypto;
        this.metrics = metrics;
        this.ttlMillis = props.dekCacheTtlSeconds() * 1000L;
        this.maxEntries = Math.max(1, props.dekCacheMaxEntries());
        this.clock = clock;
    }

    /** Konusmanin aktif DEK'i; yoksa uretilip kaydedilir (yarista tek kazanan, digerleri onu okur). */
    public DekRef active(long conversationId) {
        StoredKey s = store.findActive(conversationId).orElse(null);
        if (s == null) {
            byte[] raw = crypto.newKeyBytes();
            String kid = keys.activeKeyId();
            StoredKey fresh = new StoredKey(conversationId, 1, wrap(kid, conversationId, 1, raw), kid, true);
            if (store.insert(fresh)) {
                SecretKey dek = new SecretKeySpec(raw, "AES");
                put(conversationId, 1, dek);
                return new DekRef(1, dek);
            }
            s = store.findActive(conversationId)
                    .orElseThrow(() -> new CryptoException(Reason.KEY_UNAVAILABLE, "Konusma anahtari olusturulamadi"));
        }
        return new DekRef(s.version(), resolve(s));
    }

    /** Belirli surumdeki DEK (eski mesajlari cozmek icin). */
    public SecretKey key(long conversationId, int version) {
        Cached c = cache.get(cacheKey(conversationId, version));
        if (c != null && c.expiresAtMillis() > clock.getAsLong()) {
            return c.key();
        }
        StoredKey s = store.find(conversationId, version)
                .orElseThrow(() -> new CryptoException(Reason.KEY_UNAVAILABLE, "Konusma anahtari yok"));
        return resolve(s);
    }

    private SecretKey resolve(StoredKey s) {
        Cached c = cache.get(cacheKey(s.conversationId(), s.version()));
        if (c != null && c.expiresAtMillis() > clock.getAsLong()) {
            return c.key();
        }
        SecretKey dek = unwrap(s);
        put(s.conversationId(), s.version(), dek);
        return dek;
    }

    private void put(long cid, int version, SecretKey dek) {
        if (ttlMillis <= 0) {
            return;
        }
        if (cache.size() >= maxEntries) {
            long now = clock.getAsLong();
            cache.entrySet().removeIf(e -> e.getValue().expiresAtMillis() <= now);
            if (cache.size() >= maxEntries) {
                cache.clear();
            }
        }
        cache.put(cacheKey(cid, version), new Cached(dek, clock.getAsLong() + ttlMillis));
    }

    public void clearCache() {
        cache.clear();
    }

    private static String cacheKey(long cid, int version) {
        return cid + ":" + version;
    }

    private static byte[] wrapAad(long cid, int version) {
        return Aad.of("dek-wrap", cid, ByteBuffer.allocate(4).putInt(version).array());
    }

    private byte[] wrap(String masterKeyId, long cid, int version, byte[] rawDek) {
        Sealed s = crypto.seal(keys.key(masterKeyId), wrapAad(cid, version), rawDek, version);
        return Aad.concat(s.nonce(), s.ciphertext());
    }

    private SecretKey unwrap(StoredKey s) {
        byte[] w = s.wrapped();
        if (w == null || w.length <= CryptoService.NONCE_BYTES) {
            throw new CryptoException(Reason.MALFORMED, "Sarili anahtar bicimi gecersiz");
        }
        byte[] nonce = Arrays.copyOfRange(w, 0, CryptoService.NONCE_BYTES);
        byte[] ct = Arrays.copyOfRange(w, CryptoService.NONCE_BYTES, w.length);
        byte[] raw = crypto.open(keys.key(s.masterKeyId()), wrapAad(s.conversationId(), s.version()), nonce, ct);
        return new SecretKeySpec(raw, "AES");
    }

    /**
     * Tum DEK'leri hedef ana anahtarla yeniden sarar (mesajlara dokunulmaz). Idempotent ve
     * kesilirse kaldigi yerden surer: sadece henuz hedefle sarili olmayanlar islenir.
     */
    public RewrapResult rewrapAll(String targetKeyId) {
        if (!keys.keyIds().contains(targetKeyId)) {
            throw new CryptoException(Reason.KEY_UNAVAILABLE, "Hedef ana anahtar tanimli degil: " + targetKeyId);
        }
        int ok = 0;
        int failed = 0;
        long afterCid = Long.MIN_VALUE;
        int afterVer = Integer.MIN_VALUE;
        while (true) {
            List<StoredKey> page = store.pageNotWrappedBy(targetKeyId, afterCid, afterVer, REWRAP_BATCH);
            if (page.isEmpty()) {
                break;
            }
            for (StoredKey s : page) {
                try {
                    SecretKey dek = unwrap(s);
                    Sealed n = crypto.seal(keys.key(targetKeyId), wrapAad(s.conversationId(), s.version()),
                            dek.getEncoded(), s.version());
                    if (store.rewrap(s.conversationId(), s.version(), s.masterKeyId(), targetKeyId,
                            Aad.concat(n.nonce(), n.ciphertext()))) {
                        ok++;
                    }
                } catch (CryptoException e) {
                    failed++;
                    metrics.failure("rewrap_" + e.reason().name().toLowerCase());
                    log.warn("DEK yeniden sarilamadi: konusma={} surum={} neden={}",
                            s.conversationId(), s.version(), e.reason());
                }
                afterCid = s.conversationId();
                afterVer = s.version();
            }
        }
        clearCache();
        log.info("DEK yeniden sarma: hedef={} basarili={} basarisiz={}", targetKeyId, ok, failed);
        return new RewrapResult(ok, failed);
    }

    public Map<String, Long> countsByMasterKey() {
        return store.countsByMasterKey();
    }
}
