package edu.bingol.backend.support.ticket;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SupportTrackTokenRepository extends JpaRepository<SupportTrackToken, Long> {

    Optional<SupportTrackToken> findByTokenHash(String tokenHash);
}
