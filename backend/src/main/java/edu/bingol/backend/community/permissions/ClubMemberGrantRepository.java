package edu.bingol.backend.community.permissions;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ClubMemberGrantRepository extends JpaRepository<ClubMemberGrant, Long> {

    Optional<ClubMemberGrant> findByCommunityIdAndUserId(Long communityId, Long userId);

    List<ClubMemberGrant> findByCommunityId(Long communityId);

    List<ClubMemberGrant> findByUserId(Long userId);

    List<ClubMemberGrant> findByCommunityIdAndUserIdIn(Long communityId, Collection<Long> userIds);

    @Modifying
    @Query("DELETE FROM ClubMemberGrant g WHERE g.communityId = :cid AND g.userId = :uid")
    int deleteMember(@Param("cid") Long communityId, @Param("uid") Long userId);
}
