package edu.bingol.backend.community;

import edu.bingol.backend.common.CursorPage;
import java.util.List;
import java.util.function.BiFunction;
import java.util.function.Consumer;
import java.util.function.Function;

/** Imec sayfasi icin ortak yardimci: size+1 satirlik listeyi sayfalayip tum sayfayi tek seferde (toplu sorguyla) eslestirir. */
public final class Paging {

    private Paging() {}

    public static <E, T> CursorPage<T> map(List<E> rows, int size, Function<E, Long> idOf,
                                           Function<List<E>, List<T>> mapper) {
        CursorPage<E> p = CursorPage.of(rows, size, idOf, e -> e);
        return new CursorPage<>(mapper.apply(p.items()), p.nextCursor());
    }

    /** Bos/yok imec: en buyuk id (azalan sirada ilk sayfa). */
    public static long descStart(Long cursor) {
        return cursor == null ? Long.MAX_VALUE : cursor;
    }

    /** Bos/yok imec: 0 (artan sirada ilk sayfa). */
    public static long ascStart(Long cursor) {
        return cursor == null ? 0L : cursor;
    }

    /** Toplu bildirim donguleri icin guvenlik tavani (kontrolsuz sonsuz dongu olmasin); asilirsa truncated=true. */
    public static final int FANOUT_CAP = 50_000;
    public static final int FANOUT_CHUNK = 500;

    /**
     * Kimlik imecli sayfali dongu (T-051): ilk 500'de sessizce kesmek yerine tum alicilari sirayla verir.
     * page(afterId, chunk) artan kimlik dondurmelidir. Tavan asilirsa true (kesildi) doner.
     */
    public static boolean forEachChunk(BiFunction<Long, Integer, List<Long>> page, Consumer<List<Long>> each) {
        long after = 0L;
        int seen = 0;
        while (true) {
            List<Long> ids = page.apply(after, FANOUT_CHUNK);
            if (ids.isEmpty()) {
                return false;
            }
            each.accept(ids);
            seen += ids.size();
            after = ids.get(ids.size() - 1);
            if (ids.size() < FANOUT_CHUNK) {
                return false;
            }
            if (seen >= FANOUT_CAP) {
                return true;
            }
        }
    }
}
