package edu.bingol.backend.academician;

import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AcEnrollmentRepository extends JpaRepository<AcEnrollment, Long> {

    boolean existsByCourseIdAndStudentId(Long courseId, Long studentId);

    java.util.Optional<AcEnrollment> findByCourseIdAndStudentId(Long courseId, Long studentId);

    long countByCourseId(Long courseId);

    /** Kayitli ogrenci kimlikleri (kimlige gore artan imec). */
    @Query("SELECT e.studentId FROM AcEnrollment e WHERE e.courseId = :c AND e.studentId > :after ORDER BY e.studentId")
    List<Long> studentIdsAfter(@Param("c") Long courseId, @Param("after") Long after, Pageable page);

    /** Verilen adaylardan zaten kayitli olanlar. */
    @Query("SELECT e.studentId FROM AcEnrollment e WHERE e.courseId = :c AND e.studentId IN :ids")
    List<Long> alreadyEnrolled(@Param("c") Long courseId, @Param("ids") Collection<Long> ids);

    @Query("SELECT e FROM AcEnrollment e WHERE e.courseId = :c ORDER BY e.studentId")
    List<AcEnrollment> ofCourse(@Param("c") Long courseId, Pageable page);

    @Query("SELECT e FROM AcEnrollment e WHERE e.studentId = :s ORDER BY e.courseId")
    List<AcEnrollment> ofStudent(@Param("s") Long studentId, Pageable page);

    /** Ogrencinin kayitli oldugu dersler (ders kimlikleri). */
    @Query("SELECT e.courseId FROM AcEnrollment e WHERE e.studentId = :s ORDER BY e.courseId")
    List<Long> courseIdsOf(@Param("s") Long studentId, Pageable page);

    /** Kosullu yukseltme: yalniz bu cagri duzeyi yukselttiyse 1 doner (es zamanli finalize cift bildirim vermez). */
    @Modifying
    @org.springframework.transaction.annotation.Transactional
    @Query("UPDATE AcEnrollment e SET e.warnedLevel = :lvl WHERE e.courseId = :c AND e.studentId = :s AND e.warnedLevel < :lvl")
    int raiseWarned(@Param("c") Long courseId, @Param("s") Long studentId, @Param("lvl") short level);

    /** Duzeltme sonrasi sessiz dusurme (bildirim yok). */
    @Modifying
    @org.springframework.transaction.annotation.Transactional
    @Query("UPDATE AcEnrollment e SET e.warnedLevel = :lvl WHERE e.courseId = :c AND e.studentId = :s AND e.warnedLevel > :lvl")
    int lowerWarned(@Param("c") Long courseId, @Param("s") Long studentId, @Param("lvl") short level);

    @Modifying
    @org.springframework.transaction.annotation.Transactional
    @Query("DELETE FROM AcEnrollment e WHERE e.courseId = :c AND e.studentId = :s")
    int remove(@Param("c") Long courseId, @Param("s") Long studentId);
}
