package edu.bingol.backend.community.permissions;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ClubInviteRepository extends JpaRepository<ClubInvite, Long> {

    Optional<ClubInvite> findByCodeHash(String codeHash);

    List<ClubInvite> findByCommunityIdOrderByIdDesc(Long communityId);

    Optional<ClubInvite> findByIdAndCommunityId(Long id, Long communityId);

    List<ClubInvite> findByCreatedBy(Long userId);

    @Query("SELECT COUNT(i) FROM ClubInvite i WHERE i.communityId = :cid AND i.revoked = false AND i.expiresAt > :now")
    long countActive(@Param("cid") Long communityId, @Param("now") Instant now);

    /** Atomik kullanim: sinir/sure/iptal kosullari tek UPDATE'te; etkilenen satir 0 ise kod gecersizdir. */
    @Modifying
    @Query("""
            UPDATE ClubInvite i SET i.usedCount = i.usedCount + 1
            WHERE i.id = :id AND i.revoked = false AND i.expiresAt > :now
              AND (i.maxUses IS NULL OR i.usedCount < i.maxUses)
            """)
    int consume(@Param("id") Long id, @Param("now") Instant now);
}
