package edu.bingol.backend.legal;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AcceptanceRepository extends JpaRepository<LegalAcceptance, Long> {

    boolean existsByUserIdAndDocTypeAndVersion(Long userId, LegalType docType, int version);

    List<LegalAcceptance> findByUserIdOrderByAcceptedAtDesc(Long userId);
}
