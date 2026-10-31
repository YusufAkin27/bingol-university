package edu.bingol.backend.common;

import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/**
 * Islem COMMIT olduktan sonra calisir (islem yoksa hemen). Redis isaretleri (askiya alma, oturum iptali) erken
 * yazilirsa islem geri alindiginda kullanici hatali yere kilitli kalir; gec yazilirsa pencere milisaniyedir.
 */
public final class AfterCommit {

    private AfterCommit() {
    }

    public static void run(Runnable task) {
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    task.run();
                }
            });
        } else {
            task.run();
        }
    }
}
