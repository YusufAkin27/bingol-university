package edu.bingol.backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.ConstructorBinding;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * `app.mail.*` ayarlari. enabled=false iken e-postalar gonderilmez, kuyruk isleyicisi icerigi log'a yazar
 * (yalnizca gelistirme).
 *
 * @param queuePollMs kuyruk isleyicisinin calisma araligi (ms)
 * @param maxAttempts bu kadar basarisiz denemeden sonra e-posta DEAD olur
 * @param batchSize   bir turda alinan en fazla e-posta
 * @param allowLogOnly prod profilinde enabled=false ile acilisa izin verir (kodlar yalnizca log'a yazilir);
 *                    bilincli kapali ortamlar icindir, varsayilan false
 * @param replyTo     Reply-To adresi (bos = baslik eklenmez; From genelde no-reply'dir)
 * @param maxPerMinute duyuru (toplu) maillerinde dakikada en fazla gonderim (isinma dostu; 0 veya eksi = sinirsiz).
 *                    Islemsel mailler bu sinira tabi degildir
 * @param recipientGapSeconds ayni adrese iki DUYURU arasindaki en kisa sure (sn); 0 = kapali
 * @param unsubscribeBaseUrl abonelikten cikma baglantisinin kok adresi (PUBLIC_WEB_URL; /api istekleri backend'e vekillenir)
 * @param unsubscribeTtlDays abonelik jetonunun gecerlilik suresi (gun)
 * @param unsubscribeKey abonelik jetonu HMAC anahtari (bos = JWT sirrindan turetilir)
 */
@ConfigurationProperties("app.mail")
public record MailProperties(
        @DefaultValue("false") boolean enabled,
        @DefaultValue("no-reply@bingol.edu.tr") String from,
        @DefaultValue("BÜ Kampüs") String fromName,
        @DefaultValue("5000") long queuePollMs,
        @DefaultValue("5") int maxAttempts,
        @DefaultValue("20") int batchSize,
        @DefaultValue("false") boolean allowLogOnly,
        @DefaultValue("") String replyTo,
        @DefaultValue("30") int maxPerMinute,
        @DefaultValue("300") int recipientGapSeconds,
        @DefaultValue("") String unsubscribeBaseUrl,
        @DefaultValue("180") int unsubscribeTtlDays,
        @DefaultValue("") String unsubscribeKey) {

    /** Baglama icin kanonik kurucu (birden fazla kurucu oldugundan acikca isaretlenir). */
    @ConstructorBinding
    public MailProperties {
    }

    /** Eski 7 alanli kurucu (geriye uyumluluk: testler/diger moduller). */
    public MailProperties(boolean enabled, String from, String fromName, long queuePollMs, int maxAttempts,
                          int batchSize, boolean allowLogOnly) {
        this(enabled, from, fromName, queuePollMs, maxAttempts, batchSize, allowLogOnly, "", 30, 300, "", 180, "");
    }

    /** `from` adresinin alan adi (kucuk harf); yoksa bos. */
    public String fromDomain() {
        if (from == null) {
            return "";
        }
        int at = from.lastIndexOf('@');
        return at < 0 ? "" : from.substring(at + 1).trim().toLowerCase(java.util.Locale.ROOT);
    }
}
