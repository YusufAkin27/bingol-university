package edu.bingol.backend.accessban;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface UserDeviceLogRepository extends JpaRepository<UserDeviceLog, Long> {

    Optional<UserDeviceLog> findByUserIdAndDeviceHashAndIp(Long userId, String deviceHash, String ip);

    List<UserDeviceLog> findByUserIdOrderByLastSeenAtDesc(Long userId);

    /** Kullanici basina satir ust siniri icin: toplam satir, farkli cihaz ozeti, en eski kayit. */
    long countByUserId(Long userId);

    boolean existsByUserIdAndDeviceHash(Long userId, String deviceHash);

    @Query("SELECT COUNT(DISTINCT l.deviceHash) FROM UserDeviceLog l WHERE l.userId = :uid")
    long countDistinctDevices(@Param("uid") Long userId);

    Optional<UserDeviceLog> findFirstByUserIdOrderByLastSeenAtAsc(Long userId);

    @Query("SELECT l FROM UserDeviceLog l WHERE l.userId = :uid AND l.lastSeenAt >= :since ORDER BY l.lastSeenAt DESC")
    List<UserDeviceLog> findSince(@Param("uid") Long userId, @Param("since") Instant since);

    /** Verilen cihaz ozetlerini kullanan kullanicilar (oturum kapatma). */
    @Query("SELECT DISTINCT l.userId FROM UserDeviceLog l WHERE l.deviceHash IN :hashes")
    List<Long> usersOfDevices(@Param("hashes") Collection<String> hashes);

    @Query("SELECT DISTINCT l.userId FROM UserDeviceLog l WHERE l.ip = :ip AND l.lastSeenAt >= :since")
    List<Long> usersOfIp(@Param("ip") String ip, @Param("since") Instant since);

    /** CIDR eslemesi icin son donemin (kullanici, ip) ciftleri. */
    @Query("SELECT DISTINCT l.userId, l.ip FROM UserDeviceLog l WHERE l.lastSeenAt >= :since")
    List<Object[]> recentUserIps(@Param("since") Instant since, Pageable page);

    /** Ayni cihaz ozetini kullanan DIGER kullanicilar (coklu hesap tespiti). */
    @Query("SELECT DISTINCT l.userId FROM UserDeviceLog l WHERE l.deviceHash = :hash AND l.userId <> :uid")
    List<Long> otherUsersOfDevice(@Param("hash") String hash, @Param("uid") Long uid, Pageable page);

    /** Raporlayici kumeleme (T-057): verilen kullanicilarin tum cihaz/IP satirlari. */
    List<UserDeviceLog> findByUserIdIn(Collection<Long> userIds);

    /** IP basina farkli kullanici sayisi (kampus NAT'i gibi cok kullanicili IP'ler kume sinyali sayilmaz). */
    @Query("SELECT l.ip, COUNT(DISTINCT l.userId) FROM UserDeviceLog l WHERE l.ip IN :ips GROUP BY l.ip")
    List<Object[]> userCountsByIp(@Param("ips") Collection<String> ips);

    @Transactional
    @Modifying
    @Query("DELETE FROM UserDeviceLog l WHERE l.userId = :uid")
    int deleteByUser(@Param("uid") Long userId);

    @Transactional
    @Modifying
    @Query("DELETE FROM UserDeviceLog l WHERE l.lastSeenAt < :cutoff")
    int deleteOlderThan(@Param("cutoff") Instant cutoff);
}
