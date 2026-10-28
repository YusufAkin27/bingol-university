package edu.bingol.backend.event.admin;

import edu.bingol.backend.event.extras.EventCertificate;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/** Yonetici sertifika sorgulari (mevcut EventCertificateRepository'ye dokunmamak icin ayri depo; bean: adminCertificateRepository). */
public interface AdminCertificateRepository extends JpaRepository<EventCertificate, Long> {

    Optional<EventCertificate> findByEventIdAndUserId(Long eventId, Long userId);

    List<EventCertificate> findByEventId(Long eventId);

    /** Artan id imeci (V690: p07_cert_event_id). */
    @Query("SELECT c FROM EventCertificate c WHERE c.eventId = :eid AND c.id > :cursor ORDER BY c.id")
    List<EventCertificate> page(@Param("eid") Long eventId, @Param("cursor") long cursor, Pageable page);
}
