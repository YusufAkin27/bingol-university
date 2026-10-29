package edu.bingol.backend.news;

import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface NewsRepository extends JpaRepository<NewsItem, Long> {

    /** Saklı tsvector sütunu (V800 search_vec = to_tsvector(turkish, title || summary), GIN ld_news_search_vec): ts_rank yeniden hesap yapmaz. */
    String VEC = "n.search_vec";
    String MATCH = "(" + VEC + " @@ websearch_to_tsquery('turkish', :q) OR n.title ILIKE :like)";

    boolean existsByUrl(String url);

    /** Icerigi hic cekilememis ana-site kayitlari: deneme hakki kalmis ve son denemeden beri yeterli sure gecmis. */
    @Query("SELECT n FROM NewsItem n WHERE n.content IS NULL AND n.url LIKE 'https://www.bingol.edu.tr/%' "
            + "AND n.contentAttempts < :maxAttempts AND (n.contentAttemptedAt IS NULL OR n.contentAttemptedAt < :before) "
            + "ORDER BY n.id DESC")
    List<NewsItem> findContentRetryCandidates(@Param("maxAttempts") int maxAttempts,
                                              @Param("before") java.time.Instant before, Pageable pageable);

    /** Herkese acik gorunum: gizlenmis (hidden) kayitlar donmez. */
    boolean existsByIdAndHiddenFalse(Long id);

    Page<NewsItem> findByHiddenFalse(Pageable pageable);

    Page<NewsItem> findByTypeAndHiddenFalse(ContentType type, Pageable pageable);

    /** Liste ucu icin metin filtresi (PostgreSQL'e ozel). type null ise tum turler. Siralama sabit: en yeni once. */
    @Query(value = "SELECT n.* FROM news_item n WHERE (CAST(:type AS varchar) IS NULL OR n.type = :type) AND n.hidden = FALSE AND "
            + MATCH + " ORDER BY n.published_date DESC NULLS LAST, n.id DESC",
            countQuery = "SELECT count(*) FROM news_item n WHERE (CAST(:type AS varchar) IS NULL OR n.type = :type) AND n.hidden = FALSE AND "
                    + MATCH,
            nativeQuery = true)
    Page<NewsItem> searchPage(@Param("type") String type, @Param("q") String q, @Param("like") String like,
                              Pageable pageable);

    /** Genel arama icin hafif satir (icerik TEXT'i cekilmez). */
    interface HitRow {
        Long getId();
        String getTitle();
        String getSummary();
        String getImageUrl();
        String getPublishedDate();
    }

    /** Tek tur icin ts_rank sirali sonuclar; baslik ILIKE yedegi rank 0 ile sona duser. */
    @Query(value = "SELECT n.id AS id, n.title AS title, n.summary AS summary, n.image_url AS imageUrl, "
            + "CAST(n.published_date AS varchar) AS publishedDate FROM news_item n WHERE n.type = :type AND n.hidden = FALSE AND "
            + MATCH + " ORDER BY ts_rank(" + VEC + ", websearch_to_tsquery('turkish', :q)) DESC, "
            + "n.published_date DESC NULLS LAST, n.id DESC LIMIT :lim OFFSET :off", nativeQuery = true)
    List<HitRow> searchHits(@Param("type") String type, @Param("q") String q, @Param("like") String like,
                            @Param("lim") int limit, @Param("off") int offset);
}
