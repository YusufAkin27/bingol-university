package edu.bingol.backend.event.admission;

import edu.bingol.backend.event.UserEvent;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;

/**
 * Alim akisinin etkinlik satirina yonelik ozel sorgulari (UserEventRepository'ye dokunmamak icin ayri depo).
 * Bean adi: admissionEventRepository.
 */
public interface AdmissionEventRepository extends Repository<UserEvent, Long> {

    /**
     * Etkinlik satirini kilitler (FOR UPDATE): ayni etkinligin tum alim islemleri (kabul, vazgecme, terfi, kapasite
     * degisimi) sirayla yurur; boylece kapasite ve bekleme sirasi yarisa girmez.
     */
    @Query(value = "SELECT id FROM user_event WHERE id = :id FOR UPDATE", nativeQuery = true)
    List<Long> lock(@Param("id") Long id);

    /** Guncel kapasite (birinci seviye onbellegi atlayan skaler sorgu); null = sinirsiz. */
    @Query("SELECT e.capacity FROM UserEvent e WHERE e.id = :id")
    Integer capacityOf(@Param("id") Long id);

    /** Kullanicinin yayindaki/onay bekleyen ve henuz bitmemis bagimsiz etkinlik sayisi. */
    @Query("""
            SELECT COUNT(e) FROM UserEvent e
            WHERE e.createdBy = :uid AND e.communityId IS NULL AND e.status IN :statuses AND e.endsAt > :now
            """)
    long countOpen(@Param("uid") Long userId, @Param("statuses") Collection<UserEvent.Status> statuses,
                   @Param("now") Instant now);

    /** Belirli andan beri acilan bagimsiz etkinlik sayisi (iptaller dahil: iptal-yeniden ac suistimalini onler). */
    @Query("SELECT COUNT(e) FROM UserEvent e WHERE e.createdBy = :uid AND e.communityId IS NULL AND e.createdAt >= :since")
    long countCreatedSince(@Param("uid") Long userId, @Param("since") Instant since);
}
