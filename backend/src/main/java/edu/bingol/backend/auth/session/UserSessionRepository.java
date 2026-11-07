package edu.bingol.backend.auth.session;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface UserSessionRepository extends JpaRepository<UserSession, String> {

    /** Acik oturumlar: iptal edilmemis, yenileme omru ve mutlak omur icinde (son kullanima gore, sinirli). */
    @Query("SELECT s FROM UserSession s WHERE s.userId = :uid AND s.revokedAt IS NULL AND s.lastUsedAt >= :usedSince "
            + "AND s.createdAt >= :bornSince ORDER BY s.lastUsedAt DESC")
    List<UserSession> findActive(@Param("uid") Long userId, @Param("usedSince") Instant usedSince,
                                 @Param("bornSince") Instant bornSince, Pageable page);

    Optional<UserSession> findBySidAndUserId(String sid, Long userId);

    /** Bu cihaz ozeti bu kullanicida baska bir oturumda daha once goruldu mu (bilinen cihaz)? */
    boolean existsByUserIdAndDeviceHashAndSidNot(Long userId, String deviceHash, String sid);

    /** Cihaz ozeti gonderemeyen istemciler (web) icin: ayni istemci + cihaz adi + maskeli IP daha once goruldu mu? */
    boolean existsByUserIdAndClientAndDeviceNameAndIpMaskedAndSidNot(Long userId, String client, String deviceName,
                                                                     String ipMasked, String sid);

    /** Bu kullanicinin baska acik oturumu var mi (yeni cihaz bildirimi icin)? */
    @Query("SELECT COUNT(s) FROM UserSession s WHERE s.userId = :uid AND s.sid <> :sid AND s.revokedAt IS NULL "
            + "AND s.lastUsedAt >= :usedSince AND s.createdAt >= :bornSince")
    long countOtherActive(@Param("uid") Long userId, @Param("sid") String sid, @Param("usedSince") Instant usedSince,
                          @Param("bornSince") Instant bornSince);

    @Transactional(propagation = org.springframework.transaction.annotation.Propagation.REQUIRES_NEW)
    @Modifying
    @Query("UPDATE UserSession s SET s.revokedAt = :now WHERE s.userId = :uid AND s.revokedAt IS NULL")
    int revokeAllOf(@Param("uid") Long userId, @Param("now") Instant now);

    @Transactional(propagation = org.springframework.transaction.annotation.Propagation.REQUIRES_NEW)
    @Modifying
    @Query("UPDATE UserSession s SET s.revokedAt = :now WHERE s.userId = :uid AND s.client = :client AND s.revokedAt IS NULL")
    int revokeClientOf(@Param("uid") Long userId, @Param("client") String client, @Param("now") Instant now);

    @Transactional(propagation = org.springframework.transaction.annotation.Propagation.REQUIRES_NEW)
    @Modifying
    @Query("UPDATE UserSession s SET s.revokedAt = :now WHERE s.userId = :uid AND s.authTimeMs = :auth AND s.revokedAt IS NULL")
    int revokeByAuthTime(@Param("uid") Long userId, @Param("auth") long authTimeMs, @Param("now") Instant now);

    @Transactional(propagation = org.springframework.transaction.annotation.Propagation.REQUIRES_NEW)
    @Modifying
    @Query("UPDATE UserSession s SET s.revokedAt = :now WHERE s.sid = :sid AND s.revokedAt IS NULL")
    int revokeBySid(@Param("sid") String sid, @Param("now") Instant now);

    @Transactional(propagation = org.springframework.transaction.annotation.Propagation.REQUIRES_NEW)
    @Modifying
    @Query("UPDATE UserSession s SET s.lastUsedAt = :now, s.ipMasked = COALESCE(:ip, s.ipMasked), "
            + "s.appVersion = COALESCE(:ver, s.appVersion) WHERE s.sid = :sid AND s.revokedAt IS NULL")
    int touch(@Param("sid") String sid, @Param("now") Instant now, @Param("ip") String ipMasked,
              @Param("ver") String appVersion);
}
