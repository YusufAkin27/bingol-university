package edu.bingol.backend.common;

import java.util.List;
import java.util.function.Function;

/** Imec tabanli sayfa: nextCursor null ise baska sayfa yok. Sonraki istek `?cursor=<nextCursor>`. */
public record CursorPage<T>(List<T> items, Long nextCursor) {

    /** `rows`, size+1 kayit cekilmis (id'ye gore sirali) liste olmali; fazla kayit varsa nextCursor doldurulur. */
    public static <E, T> CursorPage<T> of(List<E> rows, int size, Function<E, Long> idOf, Function<E, T> mapper) {
        boolean more = rows.size() > size;
        List<E> page = more ? rows.subList(0, size) : rows;
        Long next = more ? idOf.apply(page.get(page.size() - 1)) : null;
        return new CursorPage<>(page.stream().map(mapper).toList(), next);
    }

    public static int clampSize(int size) {
        return Math.min(Math.max(size, 1), 50);
    }
}
