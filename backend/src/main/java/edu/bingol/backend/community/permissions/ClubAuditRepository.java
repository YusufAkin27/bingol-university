package edu.bingol.backend.community.permissions;

import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ClubAuditRepository extends JpaRepository<ClubAudit, Long> {

    @Query("SELECT a FROM ClubAudit a WHERE a.communityId = :cid AND a.id < :cursor ORDER BY a.id DESC")
    List<ClubAudit> page(@Param("cid") Long communityId, @Param("cursor") long cursor, Pageable page);

    /** KVKK disa aktarim: kullanicinin yaptigi veya hakkinda yapilan kayitlar. */
    @Query("SELECT a FROM ClubAudit a WHERE a.actorId = :uid OR a.targetUserId = :uid ORDER BY a.id DESC")
    List<ClubAudit> involving(@Param("uid") Long userId, Pageable page);
}
