package edu.bingol.backend.config;

import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.ConstructorBinding;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * `app.mail.*` ayarlari. enabled=false iken e-postalar gonderilmez, kuyruk isleyicisi icerigi log'a yazar
 * (yalnizca gelistirme).
 *
 * @param from        gonderen adresi; "Ad <adres>" verilirse adres ayrilir (gorunen ad icin bkz. fromName)
 * @param fromName    gorunen gonderen adi (MAIL_FROM_NAME; bos ise MAIL_FROM icindeki ad, o da yoksa "BÜ Kampüs")
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
 * @param dailyLimit saglayici gunluk gonderim kotasi (Brevo ucretsiz ~300); 0 = sinirsiz (kota korumasi kapali)
 * @param dailyReserve gunluk kotanin islemsel postalara (kod/guvenlik) ayrilan kismi: duyuru/CUSTOM postalar yalniz
 *                    {@code dailyLimit - dailyReserve} altinda gonderilir
 * @param dailyResetHourUtc saglayicinin kota gununu sifirladigi UTC saati (0-23); varsayilan 21 = 00:00 Istanbul.
 *                         Brevo'nun sifirlama saati belgelenmemisse/degisirse buradan ayarlanir
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
        @DefaultValue("") String unsubscribeKey,
        @DefaultValue("0") int dailyLimit,
        @DefaultValue("60") int dailyReserve,
        @DefaultValue("21") int dailyResetHourUtc) {

    /** Baglama icin kanonik kurucu (birden fazla kurucu oldugundan acikca isaretlenir). */
    @ConstructorBinding
    public MailProperties {
        // MAIL_FROM "Ad <adres>" bicimde verilmis olabilir: adres ayrilir, gorunen ad iki kez uretilmez.
        // Oncelik: acik MAIL_FROM_NAME > MAIL_FROM icindeki ad > varsayilan marka adi.
        String embedded = null;
        if (from != null) {
            Matcher m = NAME_ADDR.matcher(from.trim());
            if (m.matches()) {
                embedded = m.group(1).trim().replaceAll("^\"|\"$", "").trim();
                from = m.group(2).trim();
            } else {
                from = from.trim();
            }
        }
        if (fromName == null || fromName.isBlank()) {
            fromName = embedded == null || embedded.isBlank() ? DEFAULT_FROM_NAME : embedded;
        }
        fromName = fromName.replaceAll("[\r\n]+", " ").trim();
    }

    /** Gorunen gonderen adi varsayilani (urun adi; MAIL_FROM_NAME ile degistirilir). */
    public static final String DEFAULT_FROM_NAME = "BÜ Kampüs";

    private static final Pattern NAME_ADDR = Pattern.compile("^(.*)<([^<>]+)>\s*$");

    /** "Ad <adres>" ya da yalnizca "adres" -> adres kismi (dogrulayici/yardimcilar icin). */
    public static String addressOf(String raw) {
        if (raw == null) {
            return "";
        }
        Matcher m = NAME_ADDR.matcher(raw.trim());
        return (m.matches() ? m.group(2) : raw).trim();
    }

    /** Eski 13 alanli kurucu (kota alanlari olmadan; geriye uyumluluk). */
    public MailProperties(boolean enabled, String from, String fromName, long queuePollMs, int maxAttempts,
                          int batchSize, boolean allowLogOnly, String replyTo, int maxPerMinute,
                          int recipientGapSeconds, String unsubscribeBaseUrl, int unsubscribeTtlDays,
                          String unsubscribeKey) {
        this(enabled, from, fromName, queuePollMs, maxAttempts, batchSize, allowLogOnly, replyTo, maxPerMinute,
                recipientGapSeconds, unsubscribeBaseUrl, unsubscribeTtlDays, unsubscribeKey, 0, 60, 21);
    }

    /** Eski 7 alanli kurucu (geriye uyumluluk: testler/diger moduller). */
    public MailProperties(boolean enabled, String from, String fromName, long queuePollMs, int maxAttempts,
                          int batchSize, boolean allowLogOnly) {
        this(enabled, from, fromName, queuePollMs, maxAttempts, batchSize, allowLogOnly, "", 30, 300, "", 180, "", 0, 60, 21);
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
