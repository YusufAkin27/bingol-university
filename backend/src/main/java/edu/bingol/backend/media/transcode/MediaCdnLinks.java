package edu.bingol.backend.media.transcode;

import edu.bingol.backend.media.MediaUrlSigner;
import java.time.Duration;
import org.springframework.stereotype.Component;

/**
 * Gonderi medyasi icin imzali, kisa omurlu CDN URL'si: {@code <cdn>/files/cdn/post/<id>?t=<0|1>&exp=..&sig=..}.
 * Imza {@link MediaUrlSigner} ile (kova "postcdn", anahtar "<id>v|t") hesaplanir; origin ucu
 * ({@link PostMediaCdnController}) ayni imzayi dogrular. URL YALNIZ yetkisi dogrulanmis kullaniciya uretilmelidir.
 */
@Component
public class MediaCdnLinks {

    static final String BUCKET = "postcdn";

    private final MediaCdnProperties props;
    private final MediaUrlSigner signer;

    public MediaCdnLinks(MediaCdnProperties props, MediaUrlSigner signer) {
        this.props = props;
        this.signer = signer;
    }

    public boolean redirectEnabled() {
        return props.enabled() && props.redirect();
    }

    /** CDN kapaliysa null. */
    public String url(long mediaId, boolean thumb) {
        if (!props.enabled()) {
            return null;
        }
        String signed = signer.sign(BUCKET, key(mediaId, thumb), Duration.ofSeconds(Math.max(30, props.ttlSeconds())));
        String query = signed.substring(signed.indexOf('?') + 1);
        String base = props.baseUrl().endsWith("/") ? props.baseUrl().substring(0, props.baseUrl().length() - 1)
                : props.baseUrl();
        return base + "/files/cdn/post/" + mediaId + "?t=" + (thumb ? 1 : 0) + "&" + query;
    }

    public boolean verify(long mediaId, boolean thumb, long exp, String sig) {
        return props.enabled() && signer.verify(BUCKET, key(mediaId, thumb), exp, sig);
    }

    /** CDN'in onbellek suresi: imza bitmeden once dolmali. */
    public long maxAgeSeconds(long exp) {
        long left = exp - java.time.Instant.now().getEpochSecond();
        return Math.max(0, Math.min(left, props.ttlSeconds()));
    }

    static String key(long mediaId, boolean thumb) {
        return mediaId + (thumb ? "t" : "v");
    }
}
