package edu.bingol.backend.mail.campaign;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Sablonun degismez bir surumu: konu + (guvenli hale getirilmis) HTML + duz metin, uc dil icin. */
@Entity
@Table(name = "mail_template_custom_version")
@Getter
@Setter
public class MailCustomTemplateVersion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long templateId;

    @Column(nullable = false)
    private int version;

    @Column(length = 200)
    private String subjectTr;
    @Column(columnDefinition = "TEXT")
    private String htmlTr;
    @Column(columnDefinition = "TEXT")
    private String textTr;

    @Column(length = 200)
    private String subjectEn;
    @Column(columnDefinition = "TEXT")
    private String htmlEn;
    @Column(columnDefinition = "TEXT")
    private String textEn;

    @Column(length = 200)
    private String subjectAr;
    @Column(columnDefinition = "TEXT")
    private String htmlAr;
    @Column(columnDefinition = "TEXT")
    private String textAr;

    private Long createdBy;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
