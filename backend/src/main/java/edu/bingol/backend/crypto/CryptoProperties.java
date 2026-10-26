package edu.bingol.backend.crypto;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * `app.crypto.*`: sifreli saklama ayarlari.
 *
 * @param masterKeys          "id:base64(32 bayt)" listesi (virgul/bosluk/noktalivirgul ile ayrilir); repoda ASLA
 * @param masterKeysFile      masterKeys bos ise ayni bicimde okunacak dosya (Docker secret)
 * @param activeKeyId         yeni DEK'leri saran ana anahtar; bos ise listedeki SON anahtar
 * @param requireKeys         true ise anahtar yokken uygulama acilmaz (prod profili de bunu zorlar)
 * @param adminDecryptEnabled yonetici cozme ucu acik mi
 * @param dekCacheTtlSeconds  bellek ici DEK onbellegi omru (0 = kapali)
 * @param dekCacheMaxEntries  onbellek ust siniri
 * @param adminDecryptPerHour yonetici basina saatlik cozme istegi siniri
 * @param adminDecryptMaxMessages tek istekte cozulebilecek mesaj sayisi
 */
@ConfigurationProperties("app.crypto")
public record CryptoProperties(
        @DefaultValue("") String masterKeys,
        @DefaultValue("") String masterKeysFile,
        @DefaultValue("") String activeKeyId,
        @DefaultValue("false") boolean requireKeys,
        @DefaultValue("true") boolean adminDecryptEnabled,
        @DefaultValue("300") int dekCacheTtlSeconds,
        @DefaultValue("1024") int dekCacheMaxEntries,
        @DefaultValue("30") int adminDecryptPerHour,
        @DefaultValue("200") int adminDecryptMaxMessages) {
}
