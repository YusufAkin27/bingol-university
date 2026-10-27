package edu.bingol.backend.media.transcode;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * `app.media.cdn.*`: CDN arkasi sunum ("signed redirect"). {@code baseUrl} bos ise TAMAMEN KAPALI (varsayilan).
 *
 * @param baseUrl    CDN kok adresi (https://cdn.ornek.edu.tr); CDN'in origin'i bu uygulamadir
 * @param redirect   true ise yetkili istemciye medya yerine 302 + imzali CDN URL'si doner (varsayilan false:
 *                   istemciler Authorization basligini yonlendirmede tasimayabilir/yanlis aktarabilir; yalniz
 *                   bunu bilerek acin ve mobil istemciyi test edin)
 * @param ttlSeconds imzali URL omru (en fazla 3600; MediaUrlSigner siniri)
 */
@ConfigurationProperties("app.media.cdn")
public record MediaCdnProperties(
        @DefaultValue("") String baseUrl,
        @DefaultValue("false") boolean redirect,
        @DefaultValue("300") int ttlSeconds) {

    public boolean enabled() {
        return baseUrl != null && baseUrl.startsWith("https://");
    }
}
