package edu.bingol.backend.admin.rbac;

import jakarta.persistence.LockModeType;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AdminProfileChangeRepository extends JpaRepository<AdminProfileChange, Long> {

    List<AdminProfileChange> findTop100ByStatusOrderByIdDesc(AdminProfileChange.Status status);

    List<AdminProfileChange> findTop100ByOrderByIdDesc();

    boolean existsByTargetUserIdAndStatus(Long targetUserId, AdminProfileChange.Status status);

    /** Karar yarisi olmasin diye satiri kilitler (PostgreSQL FOR UPDATE; H2 de destekler). */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT c FROM AdminProfileChange c WHERE c.id = :id")
    Optional<AdminProfileChange> findForUpdate(@Param("id") Long id);

    /** Suresi dolan bekleyenleri EXPIRED yapar; etkilenen satir sayisini doner. */
    @Modifying
    @Query("UPDATE AdminProfileChange c SET c.status = edu.bingol.backend.admin.rbac.AdminProfileChange.Status.EXPIRED"
            + " WHERE c.status = edu.bingol.backend.admin.rbac.AdminProfileChange.Status.PENDING AND c.expiresAt < :now")
    int expireOverdue(@Param("now") Instant now);
}
