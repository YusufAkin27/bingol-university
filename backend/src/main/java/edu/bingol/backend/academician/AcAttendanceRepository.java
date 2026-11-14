package edu.bingol.backend.academician;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AcAttendanceRepository extends JpaRepository<AcAttendance, Long> {

    boolean existsBySessionIdAndStudentId(Long sessionId, Long studentId);

    Optional<AcAttendance> findBySessionIdAndStudentId(Long sessionId, Long studentId);

    /** Gecerli (kaldirilmamis) yoklama sayisi. */
    @Query("SELECT COUNT(a) FROM AcAttendance a WHERE a.sessionId = :s AND a.revokedAt IS NULL")
    long countActive(@Param("s") Long sessionId);

    /** Canli ekran: oturumun TUM satirlari (kaldirilanlar dahil; id artan). Imec yok: guncelleme kacmaz. */
    @Query("SELECT a FROM AcAttendance a WHERE a.sessionId = :s ORDER BY a.id")
    List<AcAttendance> allOf(@Param("s") Long sessionId, Pageable page);

    /** Devamsizlik matrisi: [oturum, ogrenci, yontem, kaldirildi mi]. */
    @Query("SELECT a.sessionId, a.studentId, a.method, a.revokedAt FROM AcAttendance a WHERE a.sessionId IN :sessions")
    List<Object[]> pairsOf(@Param("sessions") Collection<Long> sessionIds, Pageable page);

    /** Ogrencinin ders basina yoklama sayisi: [courseId, count]. */
    @Query("SELECT s.courseId, COUNT(a) FROM AcAttendance a JOIN AcSession s ON s.id = a.sessionId "
            + "WHERE a.studentId = :st AND a.revokedAt IS NULL AND s.courseId IN :courses GROUP BY s.courseId")
    List<Object[]> presentByCourse(@Param("st") Long studentId, @Param("courses") Collection<Long> courseIds);

    /** Kesinlesmis (kapali) oturumlardaki gecerli yoklamalar: [ogrenci, sayi]. Uyari hesabi icin. */
    @Query("SELECT a.studentId, COUNT(a) FROM AcAttendance a JOIN AcSession s ON s.id = a.sessionId "
            + "WHERE s.courseId = :c AND s.status = edu.bingol.backend.academician.AcSession.Status.CLOSED "
            + "AND a.revokedAt IS NULL GROUP BY a.studentId")
    List<Object[]> presentInFinal(@Param("c") Long courseId, Pageable page);

    /** KVKK disa aktarim: ogrencinin kendi yoklama satirlari. */
    @Query("SELECT a FROM AcAttendance a WHERE a.studentId = :st ORDER BY a.id")
    List<AcAttendance> ofStudent(@Param("st") Long studentId, Pageable page);
}
