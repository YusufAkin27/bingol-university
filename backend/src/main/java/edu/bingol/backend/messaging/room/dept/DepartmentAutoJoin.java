package edu.bingol.backend.messaging.room.dept;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/**
 * Bolum atamasi yapan akislar (kayit, onboarding, profil guncelleme) icin tek giris: kullaniciyi kendi bolum kanalina
 * otomatik ekler. Acik bir islem varsa COMMIT SONRASI calisir (yeni bolum gorunur olsun); hata cagiran akisi bozmaz.
 * Bagimlilik tembeldir (dongusel bagimlilik yok).
 */
@Component
public class DepartmentAutoJoin {

    private static final Logger log = LoggerFactory.getLogger(DepartmentAutoJoin.class);

    private final ObjectProvider<DepartmentChatService> service;

    public DepartmentAutoJoin(ObjectProvider<DepartmentChatService> service) {
        this.service = service;
    }

    public void schedule(Long userId) {
        if (userId == null) {
            return;
        }
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    run(userId);
                }
            });
        } else {
            run(userId);
        }
    }

    private void run(Long userId) {
        try {
            service.getObject().autoJoinOwn(userId);
        } catch (RuntimeException e) {
            log.warn("Bolum kanali otomatik katilim atlandi: user={} ({})", userId, e.getClass().getSimpleName());
        }
    }
}
