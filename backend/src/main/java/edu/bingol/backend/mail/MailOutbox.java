package edu.bingol.backend.mail;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Gonderilecek e-posta kaydi (outbox). Durum gecisleri bu sinifin metotlariyla yapilir. */
@Entity
@Table(name = "mail_outbox")
@Getter
@Setter
public class MailOutbox {

    private static final int MAX_ERROR_LENGTH = 500;

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 254)
    private String toAddress;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 40)
    private MailTemplate template;

    @Column(nullable = false, length = 2)
    private String lang;

    @Column(nullable = false, length = 4000)
    private String varsJson;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 12)
    private MailStatus status = MailStatus.PENDING;

    @Column(nullable = false)
    private int attempts;

    @Column(nullable = false)
    private Instant nextAttemptAt;

    @Column(length = MAX_ERROR_LENGTH)
    private String lastError;

    @Column(nullable = false)
    private Instant createdAt;

    private Instant sentAt;

    /** 0 = islemsel, 1 = duyuru (bkz. {@link MailCategory#priority()}); V421. */
    @Column(nullable = false)
    private int priority;

    /** Bilerek gonderilmedi (bastirma listesi / kalici adres hatasi): SKIPPED, degiskenler temizlenir. */
    public void markSkipped(String reason) {
        status = MailStatus.SKIPPED;
        lastError = reason == null ? null : reason.substring(0, Math.min(reason.length(), MAX_ERROR_LENGTH));
        scrubVars();
    }

    public void markSent(Instant now) {
        status = MailStatus.SENT;
        sentAt = now;
        lastError = null;
        scrubVars();
    }

    /** Basarisiz deneme: sayaci artirir; limit asildiysa DEAD, degilse geri cekilmeyle yeniden planlar. */
    public void markFailed(String error, Instant now, int maxAttempts) {
        attempts++;
        lastError = error == null ? null : error.substring(0, Math.min(error.length(), MAX_ERROR_LENGTH));
        if (attempts >= maxAttempts) {
            status = MailStatus.DEAD;
            scrubVars();
        } else {
            status = MailStatus.FAILED;
            nextAttemptAt = now.plus(MailBackoff.delay(attempts));
        }
    }

    /** Gonderilmeden vazgecildi (ornegin kodun suresi doldu): DEAD yapilir, degiskenler temizlenir. */
    public void markExpired(String reason) {
        status = MailStatus.DEAD;
        lastError = reason;
        scrubVars();
    }

    /** Kod gibi hassas degiskenler isi bitince (gonderildi/olu) veritabaninda tutulmaz. */
    private void scrubVars() {
        varsJson = "{}";
    }
}
