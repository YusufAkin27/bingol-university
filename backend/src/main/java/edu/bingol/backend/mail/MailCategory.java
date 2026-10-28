package edu.bingol.backend.mail;

import java.util.Set;

/**
 * E-posta turu. TRANSACTIONAL: kullanicinin kendi eyleminin sonucu (kod, guvenlik, hesap) — her zaman gonderilir,
 * abonelik basliklari eklenmez. ANNOUNCEMENT: duyuru/toplu — abonelikten cikma (List-Unsubscribe), bastirma listesi
 * ve hiz siniri uygulanir.
 */
public enum MailCategory {
    TRANSACTIONAL(0),
    ANNOUNCEMENT(1);

    /** Duyuru turu sablonlar (ad ile; mail/campaign'in CUSTOM sablonu da buradadir). Yeni toplu sablon = buraya ekle. */
    private static final Set<String> ANNOUNCEMENT_TEMPLATES = Set.of("ANNOUNCEMENT", "CUSTOM");

    private final int priority;

    MailCategory(int priority) {
        this.priority = priority;
    }

    /** Kuyruk onceligi (kucuk once). `mail_outbox.priority` ile ayni. */
    public int priority() {
        return priority;
    }

    public static MailCategory of(MailTemplate template) {
        return template != null && ANNOUNCEMENT_TEMPLATES.contains(template.name()) ? ANNOUNCEMENT : TRANSACTIONAL;
    }
}
