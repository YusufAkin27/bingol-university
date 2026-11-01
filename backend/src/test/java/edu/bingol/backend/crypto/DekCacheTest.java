package edu.bingol.backend.crypto;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;

/** FIX-P03 (A02#11): aktif surum onbellegi + dolunca tum onbellegi bosaltmama + daha buyuk varsayilan sinir. */
class DekCacheTest {

    /** Cagri sayan sarmalayici. */
    static final class CountingStore implements ConversationKeyStore {
        final ConversationKeyStore delegate;
        final AtomicInteger findActive = new AtomicInteger();
        final AtomicInteger find = new AtomicInteger();

        CountingStore(ConversationKeyStore delegate) {
            this.delegate = delegate;
        }

        @Override
        public Optional<StoredKey> find(long conversationId, int version) {
            find.incrementAndGet();
            return delegate.find(conversationId, version);
        }

        @Override
        public Optional<StoredKey> findActive(long conversationId) {
            findActive.incrementAndGet();
            return delegate.findActive(conversationId);
        }

        @Override
        public boolean insert(StoredKey key) {
            return delegate.insert(key);
        }

        @Override
        public List<StoredKey> pageNotWrappedBy(String masterKeyId, long afterConversationId, int afterVersion, int limit) {
            return delegate.pageNotWrappedBy(masterKeyId, afterConversationId, afterVersion, limit);
        }

        @Override
        public boolean rewrap(long conversationId, int version, String oldKeyId, String newKeyId, byte[] newWrapped) {
            return delegate.rewrap(conversationId, version, oldKeyId, newKeyId, newWrapped);
        }

        @Override
        public Map<String, Long> countsByMasterKey() {
            return delegate.countsByMasterKey();
        }
    }

    private final CryptoTestSupport t = new CryptoTestSupport();
    private final KeyProvider kp = CryptoTestSupport.provider("k1:" + CryptoTestSupport.b64(3), "");

    @Test
    void defaultCacheSizeIsLargeEnoughForACampus() {
        CryptoProperties bound = new org.springframework.boot.context.properties.bind.Binder(
                new org.springframework.boot.context.properties.source.MapConfigurationPropertySource(
                        Map.of("app.crypto.master-keys", "x")))
                .bind("app.crypto", CryptoProperties.class).get();
        assertTrue(bound.dekCacheMaxEntries() >= 20_000, "kampuste 1024 aktif sohbet kolayca asilir");
    }

    @Test
    void activeVersionIsServedFromCacheAfterTheFirstLookup() {
        CountingStore store = new CountingStore(t.store);
        ConversationKeyService ks = new ConversationKeyService(store, kp, t.crypto, t.metrics,
                CryptoTestSupport.props("", ""));
        ks.active(5L); // olusturur
        int before = store.findActive.get();

        for (int i = 0; i < 50; i++) {
            ks.active(5L);
        }

        assertEquals(before, store.findActive.get(), "50 sifreleme: aktif surum icin ek sorgu yok");
    }

    @Test
    void clearCacheForcesReload() {
        CountingStore store = new CountingStore(t.store);
        ConversationKeyService ks = new ConversationKeyService(store, kp, t.crypto, t.metrics,
                CryptoTestSupport.props("", ""));
        ks.active(5L);
        ks.active(5L);
        int before = store.findActive.get();

        ks.clearCache();
        ks.active(5L);

        assertEquals(before + 1, store.findActive.get());
    }

    @Test
    void fullCacheEvictsOnlyAPartInsteadOfDroppingEverything() {
        CountingStore store = new CountingStore(t.store);
        ConversationKeyService ks = new ConversationKeyService(store, kp, t.crypto, t.metrics,
                new CryptoProperties("", "", "", false, true, 300, 50, 30, 200));
        for (long c = 1; c <= 50; c++) {
            ks.active(c); // 50 giris: tam dolu
        }
        ks.active(51L); // tasma: yalniz ~%10 atilir
        int finds = store.findActive.get();

        int hits = 0;
        for (long c = 1; c <= 51; c++) {
            int b = store.findActive.get();
            ks.active(c);
            if (store.findActive.get() == b) {
                hits++;
            }
        }

        assertTrue(hits >= 35, "onbelleklerin cogu korunmali, isabet=" + hits);
        assertTrue(finds > 0);
    }
}
