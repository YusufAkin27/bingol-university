package edu.bingol.backend.moderation;

import java.time.Instant;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ViolationLedgerRepository extends JpaRepository<ViolationLedger, Long> {

    Optional<ViolationLedger> findByEmailDigest(String emailDigest);

    @Modifying
    @Query("DELETE FROM ViolationLedger l WHERE l.expiresAt < :now")
    int deleteExpired(@Param("now") Instant now);
}
