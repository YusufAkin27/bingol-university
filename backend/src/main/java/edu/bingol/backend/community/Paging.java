package edu.bingol.backend.community;

import edu.bingol.backend.common.CursorPage;
import java.util.List;
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
}
