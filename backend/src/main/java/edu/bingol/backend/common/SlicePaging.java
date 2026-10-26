package edu.bingol.backend.common;

import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Slice;
import org.springframework.http.ResponseEntity;

/**
 * Duz dizi donen liste uclarini istemciyi bozmadan sayfalar: govde ayni kalir, devam varsa
 * `X-Next-Cursor` basligi sonraki sayfa numarasini verir (`?cursor=<deger>&limit=<n>`).
 */
public final class SlicePaging {

    public static final String NEXT_CURSOR_HEADER = "X-Next-Cursor";
    public static final int MAX_LIMIT = 50;

    private SlicePaging() {}

    /** limit 1..50 araligina cekilir, bos ise 50. */
    public static int limit(Integer limit) {
        return limit == null ? MAX_LIMIT : Math.min(Math.max(limit, 1), MAX_LIMIT);
    }

    /** cursor sayfa numarasidir; bos/negatif ise 0. */
    public static PageRequest request(Long cursor, Integer limit) {
        int page = cursor == null ? 0 : (int) Math.min(Math.max(cursor, 0), 100_000L);
        return PageRequest.of(page, limit(limit));
    }

    public static <T> ResponseEntity<List<T>> respond(Slice<?> slice, List<T> items) {
        ResponseEntity.BodyBuilder ok = ResponseEntity.ok();
        if (slice.hasNext()) {
            ok.header(NEXT_CURSOR_HEADER, String.valueOf(slice.getNumber() + 1));
        }
        return ok.body(items);
    }
}
