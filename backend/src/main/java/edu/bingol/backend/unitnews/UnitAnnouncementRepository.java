package edu.bingol.backend.unitnews;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface UnitAnnouncementRepository extends JpaRepository<UnitAnnouncement, Long> {

    boolean existsByUrl(String url);

    /** Verilen adreslerden zaten kayitli olanlar (tek sorguda yenileri ayirmak icin). */
    java.util.List<UnitAnnouncement> findByUrlIn(Collection<String> urls);

    long countBySourceCode(String sourceCode);

    /** Bildirimi bekleyen, gizlenmemis yeni kayitlar (en yeni once; sayfa siniri sart). */
    @Query("SELECT a FROM UnitAnnouncement a WHERE a.notifiedAt IS NULL AND a.hidden = false AND a.fetchedAt >= :since "
            + "AND a.publishedDate >= :published ORDER BY a.publishedDate DESC, a.id DESC")
    List<UnitAnnouncement> pendingNotify(@Param("since") Instant since, @Param("published") java.time.LocalDate published,
                                         Pageable page);

    /** Tek kayit icin sahiplenme: yalniz ilk cagiran 1 alir (cift gonderim olmaz). */
    @Transactional
    @Modifying
    @Query("UPDATE UnitAnnouncement a SET a.notifiedAt = :now WHERE a.id = :id AND a.notifiedAt IS NULL")
    int claimNotify(@Param("id") Long id, @Param("now") Instant now);

    /** Eski (gonderilemeyecek kadar gecmis) ya da gizlenmis bekleyenleri sessizce gonderilmis sayar. */
    @Transactional
    @Modifying
    @Query("UPDATE UnitAnnouncement a SET a.notifiedAt = :now WHERE a.notifiedAt IS NULL "
            + "AND (a.fetchedAt < :since OR a.hidden = true OR a.publishedDate < :published)")
    int expirePending(@Param("since") Instant since, @Param("published") java.time.LocalDate published,
                      @Param("now") Instant now);
}
