package edu.bingol.backend.moderation;

import java.time.Instant;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AccountDeleteHoldRepository extends JpaRepository<AccountDeleteHold, Long> {

    @Modifying
    @Query("DELETE FROM AccountDeleteHold h WHERE h.releaseAt < :cutoff")
    int deleteReleasedBefore(@Param("cutoff") Instant cutoff);
}
