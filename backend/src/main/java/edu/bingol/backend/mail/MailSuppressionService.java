package edu.bingol.backend.mail;

import edu.bingol.backend.common.Hashing;
import java.time.Instant;
import java.util.Locale;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;

/** Bastirma listesi: duyuru maili gonderilmeyecek adresler. Sozlesme: istisna sizdirmaz (yazma hatasi loglanir). */
@Service
public class MailSuppressionService {

    private static final Logger log = LoggerFactory.getLogger(MailSuppressionService.class);

    private final MailSuppressionRepository repo;

    public MailSuppressionService(MailSuppressionRepository repo) {
        this.repo = repo;
    }

    /** Adresin kucuk harfli SHA-256 ozeti (users.email_sha256 ile ayni bicim). */
    public static String hash(String email) {
        return Hashing.sha256(email == null ? "" : email.trim().toLowerCase(Locale.ROOT));
    }

    public boolean isSuppressed(String email) {
        return isSuppressedHash(hash(email));
    }

    public boolean isSuppressedHash(String emailHash) {
        return repo.existsByEmailHash(emailHash);
    }

    /** Idempotent: ayni adres zaten listedeyse ilk kayit korunur. */
    public void suppress(String email, SuppressionReason reason) {
        suppressHash(hash(email), reason);
    }

    public void suppressHash(String emailHash, SuppressionReason reason) {
        try {
            if (repo.existsByEmailHash(emailHash)) {
                return;
            }
            MailSuppression s = new MailSuppression();
            s.setEmailHash(emailHash);
            s.setReason(reason);
            s.setCreatedAt(Instant.now());
            repo.save(s);
        } catch (DataIntegrityViolationException e) {
            // es zamanli ayni kayit: sorun degil
        } catch (RuntimeException e) {
            log.error("Bastirma listesine yazilamadi: {}", e.toString());
        }
    }

    /** Listeden cikarir (yonetici/destek; kullanici yeniden abone olursa). */
    public void remove(String email) {
        repo.deleteByHash(hash(email));
    }
}
