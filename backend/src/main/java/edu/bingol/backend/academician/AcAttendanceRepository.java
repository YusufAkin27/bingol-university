package edu.bingol.backend.academician;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface AcAttendanceRepository extends JpaRepository<AcAttendance, Long> {

    boolean existsBySessionIdAndStudentId(Long sessionId, Long studentId);

    Optional<AcAttendance> findBySessionIdAndStudentId(Long sessionId, Long studentId);

    /** Gecerli (kaldirilmamis) yoklama sayisi. */
    @Query("SELECT COUNT(a) FROM AcAttendance a WHERE a.sessionId = :s AND a.revokedAt IS NULL")
    long countActive(@Param("s") Long sessionId);

    /** Gecerli (kaldirilmamis, izinli olmayan) yoklama sayisi; YALNIZ su an derse kayitli ogrenciler (eski satirlar tabloda kalir). */
    @Query("SELECT COUNT(a) FROM AcAttendance a WHERE a.sessionId = :s AND a.revokedAt IS NULL AND a.excused = FALSE "
            + "AND a.studentId IN (SELECT e.studentId FROM AcEnrollment e WHERE e.courseId = :c)")
    long countPresentEnrolled(@Param("s") Long sessionId, @Param("c") Long courseId);

    /** Canli ekran: oturumun TUM satirlari (kaldirilanlar/izinliler dahil; id artan), yalniz kayitli ogrenciler. Imec yok: guncelleme kacmaz. */
    @Query("SELECT a FROM AcAttendance a WHERE a.sessionId = :s AND a.studentId IN "
            + "(SELECT e.studentId FROM AcEnrollment e WHERE e.courseId = :c) ORDER BY a.id")
    List<AcAttendance> allEnrolledOf(@Param("s") Long sessionId, @Param("c") Long courseId, Pageable page);

    /** Devamsizlik hesabi: [oturum, ogrenci, yontem, kaldirma zamani, izinli mi]. */
    @Query("SELECT a.sessionId, a.studentId, a.method, a.revokedAt, a.excused FROM AcAttendance a WHERE a.sessionId IN :sessions")
    List<Object[]> pairsOf(@Param("sessions") Collection<Long> sessionIds, Pageable page);

    @Query("SELECT a.sessionId, a.studentId, a.method, a.revokedAt, a.excused FROM AcAttendance a "
            + "WHERE a.sessionId IN :sessions AND a.studentId IN :students")
    List<Object[]> pairsOfStudents(@Param("sessions") Collection<Long> sessionIds, @Param("students") Collection<Long> studentIds,
                                   Pageable page);

    @Modifying
    @Transactional
    @Query("DELETE FROM AcAttendance a WHERE a.sessionId = :s")
    int deleteOfSession(@Param("s") Long sessionId);

    /** KVKK disa aktarim: ogrencinin kendi yoklama satirlari. */
    @Query("SELECT a FROM AcAttendance a WHERE a.studentId = :st ORDER BY a.id")
    List<AcAttendance> ofStudent(@Param("st") Long studentId, Pageable page);
}
