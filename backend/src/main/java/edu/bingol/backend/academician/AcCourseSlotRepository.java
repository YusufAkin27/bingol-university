package edu.bingol.backend.academician;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AcCourseSlotRepository extends JpaRepository<AcCourseSlot, Long> {

    /** Bir dersin saatleri en cok 30 satirdir (servis sinirlar). */
    List<AcCourseSlot> findTop30ByCourseIdOrderByDayOfWeekAscStartTimeAsc(Long courseId);

    /** Liste ekrani: en cok 50 dersin saatleri tek sorguda (ders basina en cok 30, servis sinirlar). */
    @Query("SELECT s FROM AcCourseSlot s WHERE s.courseId IN :ids ORDER BY s.courseId, s.dayOfWeek, s.startTime")
    List<AcCourseSlot> ofCourses(@Param("ids") java.util.Collection<Long> courseIds, org.springframework.data.domain.Pageable page);

    boolean existsByIdAndCourseId(Long id, Long courseId);

    @Modifying
    @Query("DELETE FROM AcCourseSlot s WHERE s.courseId = :courseId")
    int deleteByCourse(@Param("courseId") Long courseId);
}
