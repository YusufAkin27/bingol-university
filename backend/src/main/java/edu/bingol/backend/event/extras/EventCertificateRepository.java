package edu.bingol.backend.event.extras;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface EventCertificateRepository extends JpaRepository<EventCertificate, Long> {

    Optional<EventCertificate> findByEventIdAndUserId(Long eventId, Long userId);

    Optional<EventCertificate> findByCode(String code);

    List<EventCertificate> findByUserId(Long userId);
}
