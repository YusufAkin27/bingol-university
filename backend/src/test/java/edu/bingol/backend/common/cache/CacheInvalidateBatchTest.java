package edu.bingol.backend.common.cache;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/**
 * P07-B10: toplu yazimda (62 gun x 60 yemek = binlerce varlik olayi) ayni ad alani islem basina TEK kez gecersiz kilinir.
 */
class CacheInvalidateBatchTest {

    private final CacheService cache = TestCaches.create();

    @AfterEach
    void cleanup() {
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.clearSynchronization();
        }
        TransactionSynchronizationManager.setActualTransactionActive(false);
    }

    private void commit() {
        for (TransactionSynchronization s : TransactionSynchronizationManager.getSynchronizations()) {
            s.afterCommit();
        }
        for (TransactionSynchronization s : TransactionSynchronizationManager.getSynchronizations()) {
            s.afterCompletion(TransactionSynchronization.STATUS_COMMITTED);
        }
    }

    @Test
    void thousandsOfEntityEventsInOneTransactionInvalidateEachNamespaceOnce() {
        TransactionSynchronizationManager.initSynchronization();
        TransactionSynchronizationManager.setActualTransactionActive(true);
        for (int i = 0; i < 3720; i++) {
            cache.invalidate("menu");
        }
        cache.invalidate("menu", "status");
        assertEquals(1, TransactionSynchronizationManager.getSynchronizations().size(), "tek senkronizasyon kaydi");
        assertEquals(0, cache.stat("menu", "invalidate"), "commit oncesi hicbir sey silinmez");

        commit();

        assertEquals(1, cache.stat("menu", "invalidate"));
        assertEquals(1, cache.stat("status", "invalidate"));
    }

    @Test
    void rollbackNeverInvalidatesAndNextTransactionStartsClean() {
        TransactionSynchronizationManager.initSynchronization();
        TransactionSynchronizationManager.setActualTransactionActive(true);
        cache.invalidate("menu");
        for (TransactionSynchronization s : TransactionSynchronizationManager.getSynchronizations()) {
            s.afterCompletion(TransactionSynchronization.STATUS_ROLLED_BACK);
        }
        assertEquals(0, cache.stat("menu", "invalidate"));

        TransactionSynchronizationManager.clearSynchronization();
        TransactionSynchronizationManager.initSynchronization();
        cache.invalidate("faq");
        commit();
        assertEquals(1, cache.stat("faq", "invalidate"));
        assertEquals(0, cache.stat("menu", "invalidate"));
    }

    @Test
    void suspendedOuterTransactionDoesNotSwallowInnerTransactionsInvalidation() {
        // dis islem ad alanini biriktirdi; ic (REQUIRES_NEW benzeri) islem askiya alinan senkronizasyonlari gormez
        TransactionSynchronizationManager.initSynchronization();
        TransactionSynchronizationManager.setActualTransactionActive(true);
        cache.invalidate("menu");
        java.util.List<TransactionSynchronization> outer = TransactionSynchronizationManager.getSynchronizations();
        TransactionSynchronizationManager.clearSynchronization();

        TransactionSynchronizationManager.initSynchronization();
        cache.invalidate("menu");
        commit(); // ic islem commit: kendi gecersiz kilmasi calisir
        assertEquals(1, cache.stat("menu", "invalidate"));
        TransactionSynchronizationManager.clearSynchronization();

        for (TransactionSynchronization s : outer) {
            s.afterCommit();
        }
        assertEquals(2, cache.stat("menu", "invalidate"), "dis islem de kendi commit'inde gecersiz kilar");
    }

    @Test
    void outsideTransactionInvalidatesImmediately() {
        cache.invalidate("news");
        cache.invalidate("news");
        assertEquals(2, cache.stat("news", "invalidate"));
    }
}
