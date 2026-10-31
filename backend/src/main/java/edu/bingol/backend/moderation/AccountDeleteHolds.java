package edu.bingol.backend.moderation;

import java.time.Duration;
import java.time.Instant;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Hesap silme bekletmesi kayitlari (T-058). Ayri bean: bekletme talebi, silmeyi reddeden istegin transaction'i geri
 * alinsa bile KALMALI (REQUIRES_NEW); self-invocation bunu calistirmazdi.
 */
@Service
public class AccountDeleteHolds {

    private final AccountDeleteHoldRepository repo;

    public AccountDeleteHolds(AccountDeleteHoldRepository repo) {
        this.repo = repo;
    }

    /** Bekletme yoksa olusturur (release = simdi + days); varsa mevcut serbest birakma anini doner. */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public Instant ensure(Long userId, int days) {
        return repo.findById(userId).map(AccountDeleteHold::getReleaseAt).orElseGet(() -> {
            AccountDeleteHold h = new AccountDeleteHold();
            h.setUserId(userId);
            h.setRequestedAt(Instant.now());
            h.setReleaseAt(Instant.now().plus(Duration.ofDays(days)));
            return repo.save(h).getReleaseAt();
        });
    }

    @Transactional
    public void clear(Long userId) {
        if (repo.existsById(userId)) {
            repo.deleteById(userId);
        }
    }
}
