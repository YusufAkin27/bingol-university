package edu.bingol.backend.forum.search;

import java.util.List;
import java.util.Set;

/** Arama sorgusu (PostgreSQL'e ozel; uretim uygulamasi {@link PgForumSearchRepository}). */
public interface ForumSearchRepository {

    /** @param matchedIn TITLE | BODY | COMMENT | CATEGORY; @param snippet BODY/COMMENT icin parca, yoksa null */
    record Hit(long topicId, String matchedIn, String snippet) {}

    /**
     * Gorunur konularda arama. {@code excludedAuthors}: bakanin engel/sessize aldigi yazarlar (bos olabilir);
     * silinmis/kaldirilmis konu ve yorum, pasif yazar, anonim yorum disarida kalir.
     *
     * @param categoryId null = tum kategoriler
     */
    List<Hit> search(String q, Long categoryId, ForumSearchSort sort, Set<Long> excludedAuthors, int offset, int limit);

    /** Son 7 gunun populer konulari (yorum agirlikli skor), en cok {@code limit}. */
    List<Long> popular(Set<Long> excludedAuthors, int limit);
}
