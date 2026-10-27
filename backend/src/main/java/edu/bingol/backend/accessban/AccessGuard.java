package edu.bingol.backend.accessban;

import edu.bingol.backend.common.ApiException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/**
 * Erisim engeli kontrol noktasi (filtre, kimlik dogrulama uclari, WebSocket, kullanici ara katmani ortak kullanir).
 * Eslesme varsa vurus kaydedilir; sebep (hangi engel) istemciye ASLA soylenmez.
 */
@Component
public class AccessGuard {

    private final AccessBanCache cache;
    private final AccessBanHits hits;

    public AccessGuard(AccessBanCache cache, AccessBanHits hits) {
        this.cache = cache;
        this.hits = hits;
    }

    /** Engelliyse vurusu kaydedip eslesmeyi doner, degilse null. */
    public AccessBanCache.Hit blocked(ClientContext ctx, Long userId, String path) {
        AccessBanCache.Hit hit = cache.match(ctx, userId);
        if (hit != null) {
            hits.record(hit, ctx, userId, path);
        }
        return hit;
    }

    /** Engelliyse 403 ACCESS_BLOCKED firlatir; `ctx` null ise (eski cagrilar/testler) kontrol atlanir. */
    public void require(ClientContext ctx, Long userId, String path) {
        if (ctx != null && blocked(ctx, userId, path) != null) {
            throw accessBlocked();
        }
    }

    public static ApiException accessBlocked() {
        return new ApiException(HttpStatus.FORBIDDEN, "ACCESS_BLOCKED", "Bu cihaza veya ağa erişim kapatıldı.");
    }
}
