package edu.bingol.backend.academician;

import jakarta.persistence.LockModeType;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AcCourseRepository extends JpaRepository<AcCourse, Long> {

    Optional<AcCourse> findByIdAndOwnerId(Long id, Long ownerId);

    @Query("SELECT c FROM AcCourse c WHERE c.ownerId = :owner ORDER BY c.id DESC")
    List<AcCourse> ofOwner(@Param("owner") Long owner, Pageable page);

    long countByOwnerId(Long ownerId);

    /** Es zamanli oturum acma / duyuru olusturma tek satirda siralansin. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT c FROM AcCourse c WHERE c.id = :id")
    Optional<AcCourse> lockById(@Param("id") Long id);

    @Query("SELECT c FROM AcCourse c WHERE c.id IN :ids")
    List<AcCourse> byIds(@Param("ids") Collection<Long> ids);
}
