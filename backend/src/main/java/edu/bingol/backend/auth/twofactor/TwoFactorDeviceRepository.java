package edu.bingol.backend.auth.twofactor;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

/**
 * Guvenilen cihaz deposu. Bilerek dar bir arayuz ({@code Repository}): yalnizca 2FA'nin ihtiyac duydugu islemler
 * (testlerde bellek ici taklit yazmak kolay olsun).
 */
public interface TwoFactorDeviceRepository extends Repository<TwoFactorDevice, Long> {

    TwoFactorDevice save(TwoFactorDevice device);

    Optional<TwoFactorDevice> findByUserIdAndDeviceHash(Long userId, String deviceHash);

    Optional<TwoFactorDevice> findByIdAndUserId(Long id, Long userId);

    /** Son kullanimi yeni olan once. Kullanici basina en cok 10 satir olur. */
    List<TwoFactorDevice> findByUserIdOrderByLastUsedAtDesc(Long userId);

    long countByUserId(Long userId);

    void delete(TwoFactorDevice device);

    @Transactional
    @Modifying
    @Query("DELETE FROM TwoFactorDevice d WHERE d.userId = :uid")
    int deleteAllForUser(@Param("uid") Long userId);

    /**
     * {@code SessionsRevokedEvent} dinleyicisi icin: olay islemin COMMIT sonrasi geri cagirisinda (AfterCommit: askiya
     * alma, sifre degisimi) yayinlanabilir; orada REQUIRED bitmis islemi "katilir" ve 'No active transaction' ile dusuyordu
     * (bkz. notification.DeviceRepository.deleteAllByUser). Ayri islem: cagirani ayni satirlari kendi islemiyle silmemis
     * olmalidir (TwoFactorService bu yuzden once oturumlari kapatir, sonra cihazlari siler).
     */
    @Transactional(propagation = org.springframework.transaction.annotation.Propagation.REQUIRES_NEW)
    @Modifying
    @Query("DELETE FROM TwoFactorDevice d WHERE d.userId = :uid")
    int deleteAllForUserInNewTx(@Param("uid") Long userId);
}
