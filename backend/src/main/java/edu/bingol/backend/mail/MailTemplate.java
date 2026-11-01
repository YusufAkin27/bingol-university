package edu.bingol.backend.mail;

/**
 * E-posta sablonlari. `key`, i18n/mail*.properties icindeki `mail.tpl.<key>.*` anahtarlarinin on ekidir:
 * subject, title, body (paragraflar \n ile ayrilir), code.label (yalnizca kodlu sablonlar).
 * Yeni sablon = buraya bir deger + uc dil dosyasina anahtarlar (bkz. docs/changes/mail.md).
 */
public enum MailTemplate {
    VERIFICATION_CODE("verification"),
    PASSWORD_RESET_CODE("reset"),
    /** Iki faktorlu giris kodu (tanimadik cihazdan giris / 2FA acma); kod 10 dk gecerli, degiskeni gece silinir. */
    TWO_FACTOR_CODE("twofactor"),
    ACCOUNT_DELETED("deleted"),
    SECURITY_NEW_LOGIN("newlogin"),
    SECURITY_PASSWORD_CHANGED("pwchanged"),
    /** Iki faktorlu dogrulama guvenlik bildirimi (acildi/kapandi/yanlis kod); metin cagirandan, alicinin dilinde gelir. */
    SECURITY_TWO_FACTOR_NOTICE("tfnotice"),
    ANNOUNCEMENT("announcement"),
    /** Yonetici sablonu (mail/campaign): icerik gonderim aninda {@link CustomMailContent} ile veritabanindan cozulur. */
    CUSTOM("custom");

    private final String key;

    MailTemplate(String key) {
        this.key = key;
    }

    public String key() {
        return key;
    }
}
