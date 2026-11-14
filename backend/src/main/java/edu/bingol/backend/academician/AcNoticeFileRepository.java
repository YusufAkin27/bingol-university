package edu.bingol.backend.academician;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface AcNoticeFileRepository extends JpaRepository<AcNoticeFile, Long> {

    @Query("SELECT f FROM AcNoticeFile f WHERE f.noticeId IN :ids ORDER BY f.id")
    List<AcNoticeFile> ofNotices(@Param("ids") Collection<Long> noticeIds, Pageable page);

    Optional<AcNoticeFile> findByIdAndNoticeId(Long id, Long noticeId);

    /** Bu ogretim elemaninin henuz bir duyuruya baglanmamis (bekleyen) dosyalari. */
    @Query("SELECT f FROM AcNoticeFile f WHERE f.courseId = :c AND f.uploadedBy = :u AND f.noticeId IS NULL ORDER BY f.id")
    List<AcNoticeFile> pendingOf(@Param("c") Long courseId, @Param("u") Long uploadedBy, Pageable page);

    @Query("SELECT f FROM AcNoticeFile f WHERE f.noticeId IS NULL AND f.createdAt < :before ORDER BY f.id")
    List<AcNoticeFile> stalePending(@Param("before") Instant before, Pageable page);

    @Query("SELECT COALESCE(SUM(f.sizeBytes), 0) FROM AcNoticeFile f WHERE f.courseId = :c")
    long totalBytes(@Param("c") Long courseId);

    /** Kosullu baglama: dosya hala bagsizsa 1 doner (iki duyuru ayni dosyayi alamaz). */
    @Modifying
    @Transactional
    @Query("UPDATE AcNoticeFile f SET f.noticeId = :n WHERE f.id = :id AND f.noticeId IS NULL")
    int attachIfFree(@Param("id") Long fileId, @Param("n") Long noticeId);

    /** Ogretim elemaninin TUM derslerindeki dosyalarin toplam boyutu (bekleyenler dahil). */
    @Query("SELECT COALESCE(SUM(f.sizeBytes), 0) FROM AcNoticeFile f WHERE f.courseId IN "
            + "(SELECT c.id FROM AcCourse c WHERE c.ownerId = :o)")
    long ownerBytes(@Param("o") Long ownerId);

    @Query("SELECT f FROM AcNoticeFile f WHERE f.id IN :ids")
    List<AcNoticeFile> byIds(@Param("ids") Collection<Long> ids);
}
