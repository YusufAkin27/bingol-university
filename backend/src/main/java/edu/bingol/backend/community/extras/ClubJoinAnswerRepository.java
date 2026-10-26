package edu.bingol.backend.community.extras;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface ClubJoinAnswerRepository extends JpaRepository<ClubJoinAnswer, Long> {

    List<ClubJoinAnswer> findByCommunityIdAndUserId(Long communityId, Long userId);

    /** Bekleyen istek listesi icin toplu getirme (N+1 yok). */
    List<ClubJoinAnswer> findByCommunityIdAndUserIdIn(Long communityId, java.util.Collection<Long> userIds);

    @Transactional
    @Modifying
    @Query("DELETE FROM ClubJoinAnswer a WHERE a.communityId = :cid AND a.userId = :uid")
    int deleteMember(@Param("cid") Long communityId, @Param("uid") Long userId);
}
