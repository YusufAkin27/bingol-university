package edu.bingol.backend.academician;

import java.time.Instant;
import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AcSessionRepository extends JpaRepository<AcSession, Long> {

    /** Ders oturumlari: tarihe gore yeni -> eski. */
    @Query("SELECT s FROM AcSession s WHERE s.courseId = :c ORDER BY s.lessonDate DESC, s.id DESC")
    List<AcSession> ofCourseNewestFirst(@Param("c") Long courseId, Pageable page);

    /** Yoklama matrisi icin: eski -> yeni. */
    @Query("SELECT s FROM AcSession s WHERE s.courseId = :c ORDER BY s.lessonDate ASC, s.id ASC")
    List<AcSession> ofCourseOldestFirst(@Param("c") Long courseId, Pageable page);

    long countByCourseId(Long courseId);

    long countByCourseIdAndStatus(Long courseId, AcSession.Status status);

    /**
     * Kesinlestirme geciisi: yalniz hala OPEN ise CLOSED yapar; 1 donen cagri "kesinlestiren" cagridir (es zamanli
     * iki istek ayni oturumu kesinlestirse de uyari bir kez gider).
     */
    @Modifying
    @org.springframework.transaction.annotation.Transactional
    @Query("UPDATE AcSession s SET s.status = edu.bingol.backend.academician.AcSession.Status.CLOSED, s.closedAt = :at "
            + "WHERE s.id = :id AND s.status = edu.bingol.backend.academician.AcSession.Status.OPEN")
    int closeIfOpen(@Param("id") Long id, @Param("at") Instant closedAt);

    /** Hala acik (OPEN) oturumlar; canli olup olmadigi cagirandan bakilir. */
    @Query("SELECT s FROM AcSession s WHERE s.courseId = :c AND s.status = edu.bingol.backend.academician.AcSession.Status.OPEN "
            + "AND s.expiresAt > :now")
    List<AcSession> liveOf(@Param("c") Long courseId, @Param("now") Instant now, Pageable page);

    @Query("SELECT s FROM AcSession s WHERE s.courseId = :c AND s.lessonDate = :d AND s.slotId = :slot ORDER BY s.id")
    List<AcSession> sameDaySlot(@Param("c") Long courseId, @Param("d") LocalDate date, @Param("slot") Long slotId,
                                Pageable page);

    @Query("SELECT s FROM AcSession s WHERE s.courseId = :c AND s.lessonDate = :d AND s.slotId IS NULL ORDER BY s.id")
    List<AcSession> sameDayNoSlot(@Param("c") Long courseId, @Param("d") LocalDate date, Pageable page);

    @Query("SELECT s.courseId, COUNT(s) FROM AcSession s WHERE s.courseId IN :ids GROUP BY s.courseId")
    List<Object[]> countsByCourse(@Param("ids") Collection<Long> courseIds);

    @Query("SELECT s.id FROM AcSession s WHERE s.courseId = :c")
    List<Long> idsOfCourse(@Param("c") Long courseId, Pageable page);

    @Modifying
    @org.springframework.transaction.annotation.Transactional
    @Query("UPDATE AcSession s SET s.slotId = NULL WHERE s.courseId = :c")
    int clearSlots(@Param("c") Long courseId);

    default Optional<AcSession> findSameDay(Long courseId, LocalDate date, Long slotId) {
        List<AcSession> l = slotId == null ? sameDayNoSlot(courseId, date, Pageable.ofSize(1))
                : sameDaySlot(courseId, date, slotId, Pageable.ofSize(1));
        return l.stream().findFirst();
    }
}
