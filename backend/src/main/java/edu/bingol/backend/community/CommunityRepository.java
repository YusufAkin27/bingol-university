package edu.bingol.backend.community;

import edu.bingol.backend.user.User;
import jakarta.persistence.LockModeType;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CommunityRepository extends JpaRepository<Community, Long> {

    boolean existsBySlug(String slug);

    /** Hesap silme: kullanicinin sahibi oldugu topluluklar (verilen durumlarda). */
    List<Community> findByOwnerIdAndStatusIn(Long ownerId, Collection<Community.Status> statuses);

    /** Topluluk satirini kilitler: gunluk duyuru siniri gibi say-sonra-ekle kontrollerini seri hale getirir. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT c.id FROM Community c WHERE c.id = :id")
    Optional<Long> lockById(@Param("id") Long id);

    /** Kullanici satirini kilitler: ayni kullanicinin eszamanli olusturma isteklerini siraya dizer (3 kulup siniri yarisi). */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT u FROM User u WHERE u.id = :id")
    Optional<User> lockOwner(@Param("id") Long id);

    /** Kullanicinin sahibi oldugu ve hala "canli" sayilan (bekleyen + aktif) topluluklar. */
    long countByOwnerIdAndStatusIn(Long ownerId, Collection<Community.Status> statuses);

    /** Kesfet: yalnizca ACTIVE + PUBLIC. pattern/category bos string ise filtre uygulanmaz. id'ye gore azalan. */
    @Query("""
            SELECT c FROM Community c
            WHERE c.status = :status AND c.visibility = :visibility
              AND (:category = '' OR c.category = :category)
              AND (:pattern = '' OR lower(c.name) LIKE :pattern ESCAPE '!' OR lower(c.description) LIKE :pattern ESCAPE '!')
              AND c.id < :cursor
            ORDER BY c.id DESC
            """)
    List<Community> discover(@Param("status") Community.Status status,
                             @Param("visibility") Community.Visibility visibility,
                             @Param("category") String category, @Param("pattern") String pattern,
                             @Param("cursor") long cursor, Pageable page);

    /** Kesfetteki (ACTIVE + PUBLIC) kategori sayilari: [category, count], kalabaliktan aza. */
    @Query("""
            SELECT c.category, COUNT(c) FROM Community c
            WHERE c.status = :status AND c.visibility = :visibility AND c.category IS NOT NULL
            GROUP BY c.category ORDER BY COUNT(c) DESC, c.category
            """)
    List<Object[]> categoryCounts(@Param("status") Community.Status status,
                                  @Param("visibility") Community.Visibility visibility);

    @Query("SELECT c FROM Community c WHERE c.status = :status AND c.id < :cursor ORDER BY c.id DESC")
    List<Community> byStatus(@Param("status") Community.Status status, @Param("cursor") long cursor, Pageable page);

    /** Genel arama (SearchProvider): ILIKE, yalnizca ACTIVE + PUBLIC. */
    @Query(value = """
            SELECT * FROM community
            WHERE status = 'ACTIVE' AND visibility = 'PUBLIC'
              AND (name ILIKE :pattern ESCAPE '!' OR description ILIKE :pattern ESCAPE '!')
            ORDER BY id DESC
            LIMIT :lim
            """, nativeQuery = true)
    List<Community> search(@Param("pattern") String pattern, @Param("lim") int limit);
}
