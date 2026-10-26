package edu.bingol.backend.community.permissions;

import jakarta.persistence.LockModeType;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ClubOwnershipTransferRepository extends JpaRepository<ClubOwnershipTransfer, Long> {

    /** Cift kabulu onlemek icin satir kilidiyle. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT t FROM ClubOwnershipTransfer t WHERE t.communityId = :cid AND t.status = :status")
    Optional<ClubOwnershipTransfer> lockByStatus(@Param("cid") Long communityId,
                                                 @Param("status") ClubOwnershipTransfer.Status status);

    List<ClubOwnershipTransfer> findByFromUserIdOrToUserId(Long fromUserId, Long toUserId);

    List<ClubOwnershipTransfer> findByCommunityIdAndStatusIn(Long communityId,
                                                            Collection<ClubOwnershipTransfer.Status> statuses);
}
