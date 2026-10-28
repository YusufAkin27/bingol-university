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

/** Duyuru gonderilmeyecek adres (yalniz SHA-256 ozeti saklanir; KVKK). Islemsel mailler etkilenmez. */
@Entity
@Table(name = "mail_suppression")
@Getter
@Setter
public class MailSuppression {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 64, unique = true)
    private String emailHash;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private SuppressionReason reason;

    @Column(nullable = false)
    private Instant createdAt;

    /** Bastirmanin kapsami (P13; bugun yalniz duyuru: islemsel postalar etkilenmez). */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private MailCategory category = MailCategory.ANNOUNCEMENT;

    /** Yonetici notu (elle eklemede zorunlu sebep). */
    @Column(length = 300)
    private String note;

    /** Maskeli gosterim ("a***@alan"); adres duz saklanmaz. Eski/abonelik kayitlarinda null. */
    @Column(length = 120)
    private String emailMasked;

    /** Elle ekleyen yonetici (yoksa null). */
    private Long createdBy;
}
