package edu.bingol.backend.profile;

import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Yedekten geri yuklemeden sonra silinmis hesaplari yeniden anonimlestirir (T-064, A8-17 / BACKUP_RESTORE adim 7).
 * {@link DeletionLedger} dosyasindaki her kimlik icin: kullanici hala DELETED degilse VE hesabin olusturulma
 * saniyesi defterdekiyle ayniysa {@link ProfileService#anonymizeAccount} cagrilir (ayni kimligi alan baska hesap
 * korunur). Acilista bir kez ve her gece calisir; defter kapaliysa (bos yol) hicbir sey yapmaz. Idempotenttir.
 */
@Component
public class DeletionLedgerReapplier {

    private static final Logger log = LoggerFactory.getLogger(DeletionLedgerReapplier.class);

    private final DeletionLedger ledger;
    private final UserRepository users;
    private final ProfileService profiles;

    public DeletionLedgerReapplier(DeletionLedger ledger, UserRepository users, ProfileService profiles) {
        this.ledger = ledger;
        this.users = users;
        this.profiles = profiles;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void onReady() {
        reapply();
    }

    @Scheduled(cron = "${app.privacy.deletion-ledger-cron:0 50 3 * * *}", zone = "Europe/Istanbul")
    public void nightly() {
        reapply();
    }

    /** @return yeniden anonimlestirilen hesap sayisi */
    public int reapply() {
        if (!ledger.enabled()) {
            return 0;
        }
        int n = 0;
        // FIX-P08 (A01#15/A07#13): kimlik basina findById yerine 500'luk parcalarla findAllById (N sorgu -> N/500)
        List<DeletionLedger.Entry> all = new ArrayList<>(ledger.read().values());
        for (int i = 0; i < all.size(); i += CHUNK) {
            List<DeletionLedger.Entry> chunk = all.subList(i, Math.min(i + CHUNK, all.size()));
            Map<Long, User> found = new HashMap<>();
            try {
                for (User u : users.findAllById(chunk.stream().map(DeletionLedger.Entry::userId).toList())) {
                    found.put(u.getId(), u);
                }
            } catch (RuntimeException ex) {
                log.warn("Silme defteri parcasi okunamadi: {}", ex.toString());
                continue;
            }
            for (DeletionLedger.Entry e : chunk) {
                try {
                    User u = found.get(e.userId());
                    if (u == null || u.getStatus() == UserStatus.DELETED || u.getDeletedAt() != null) {
                        continue;
                    }
                    Instant created = u.getCreatedAt();
                    if (e.createdEpochSec() > 0 && (created == null || created.getEpochSecond() != e.createdEpochSec())) {
                        log.warn("Silme defteri kaydi hesapla uyusmuyor, atlandi (kullanici {})", e.userId());
                        continue;
                    }
                    profiles.anonymizeAccount(e.userId());
                    n++;
                    log.warn("Silme defterinden yeniden anonimlestirildi (kullanici {})", e.userId());
                } catch (RuntimeException ex) {
                    log.warn("Silme defteri uygulanamadi (kullanici {}): {}", e.userId(), ex.toString());
                }
            }
        }
        return n;
    }

    private static final int CHUNK = 500;
}
