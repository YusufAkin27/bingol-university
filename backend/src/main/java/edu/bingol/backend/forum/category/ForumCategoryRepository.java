package edu.bingol.backend.forum.category;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface ForumCategoryRepository extends JpaRepository<ForumCategory, Long> {

    boolean existsBySlug(String slug);

    boolean existsBySlugAndIdNot(String slug, Long id);

    Optional<ForumCategory> findBySlug(String slug);

    /** Kategori sayisi yonetici tanimli ve kucuktur (sabit 8 + eklenenler); yine de ust sinirli okunur. */
    @Query("SELECT c FROM ForumCategory c WHERE c.active = TRUE ORDER BY c.sortOrder, c.id")
    List<ForumCategory> activeOrdered(org.springframework.data.domain.Pageable page);

    @Query("SELECT c FROM ForumCategory c ORDER BY c.sortOrder, c.id")
    List<ForumCategory> allOrdered(org.springframework.data.domain.Pageable page);

    @Query("SELECT COALESCE(MAX(c.sortOrder), 0) FROM ForumCategory c")
    int maxSortOrder();
}
