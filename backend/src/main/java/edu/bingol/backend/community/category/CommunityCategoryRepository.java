package edu.bingol.backend.community.category;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CommunityCategoryRepository extends JpaRepository<CommunityCategory, Long> {

    Optional<CommunityCategory> findByKey(String key);

    boolean existsByKey(String key);

    long countByActiveTrue();

    List<CommunityCategory> findByActiveTrueOrderBySortOrderAscIdAsc();

    List<CommunityCategory> findAllByOrderBySortOrderAscIdAsc();

    @Query("SELECT COALESCE(MAX(c.sortOrder), 0) FROM CommunityCategory c")
    int maxSortOrder();

    /** Sinir kontrolundeki yarisi kapatmak icin aktif satirlar yazmaya karsi kilitlenir. */
    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT c FROM CommunityCategory c WHERE c.active = true")
    List<CommunityCategory> lockActive();

    /** Kullanim sayilari: [category, count]; silinmis kulupler sayilmaz. */
    @Query("SELECT c.category, COUNT(c) FROM Community c WHERE c.category IS NOT NULL AND c.status <> "
            + "edu.bingol.backend.community.Community.Status.DELETED GROUP BY c.category")
    List<Object[]> usageCounts();

    @Query("SELECT COUNT(c) FROM Community c WHERE c.category = :key AND c.status <> "
            + "edu.bingol.backend.community.Community.Status.DELETED")
    long usage(@Param("key") String key);
}
