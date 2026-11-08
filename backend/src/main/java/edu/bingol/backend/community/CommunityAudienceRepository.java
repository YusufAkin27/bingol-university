package edu.bingol.backend.community;

import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CommunityAudienceRepository extends JpaRepository<CommunityAudience, Long> {

    List<CommunityAudience> findByCommunityIdIn(Collection<Long> communityIds);

    @Modifying
    @Query("DELETE FROM CommunityAudience a WHERE a.communityId = :cid")
    void deleteAllFor(@Param("cid") Long communityId);

    /** Kullanicinin fakulte/bolumune hedeflenmis satirlar (sinirli havuz). */
    @Query("""
            SELECT a FROM CommunityAudience a
            WHERE (a.kind = 'FACULTY' AND a.value = :faculty) OR (a.kind = 'DEPARTMENT' AND a.value = :department)
            """)
    List<CommunityAudience> matching(@Param("faculty") String faculty, @Param("department") String department,
                                     Pageable page);
}
