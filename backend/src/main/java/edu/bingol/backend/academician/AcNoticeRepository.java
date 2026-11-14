package edu.bingol.backend.academician;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AcNoticeRepository extends JpaRepository<AcNotice, Long> {

    /** Yeni -> eski, kimlik imeci (id &lt; before). Indeks: ak1900_notice_course_idx. */
    @Query("SELECT n FROM AcNotice n WHERE n.courseId = :c AND n.id < :before ORDER BY n.id DESC")
    List<AcNotice> page(@Param("c") Long courseId, @Param("before") Long before, Pageable page);

    @Query("SELECT COUNT(n) FROM AcNotice n WHERE n.courseId = :c AND n.createdAt >= :since")
    long countSince(@Param("c") Long courseId, @Param("since") Instant since);

    @Query("SELECT COUNT(n) FROM AcNotice n WHERE n.courseId = :c AND n.type IN :types AND n.createdAt >= :since")
    long countTypesSince(@Param("c") Long courseId, @Param("types") Collection<AcNotice.Type> types,
                         @Param("since") Instant since);

    @Query("SELECT n FROM AcNotice n WHERE n.courseId IN :courses AND n.type IN :types AND n.eventAt > :now "
            + "ORDER BY n.eventAt ASC, n.id ASC")
    List<AcNotice> upcoming(@Param("courses") Collection<Long> courseIds, @Param("types") Collection<AcNotice.Type> types,
                            @Param("now") Instant now, Pageable page);
}
