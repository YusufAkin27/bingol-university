package edu.bingol.backend.auth.oauth;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AuthIdentityRepository extends JpaRepository<AuthIdentity, Long> {

    Optional<AuthIdentity> findByProviderAndSubject(OAuthProvider provider, String subject);

    Optional<AuthIdentity> findByUserIdAndProvider(Long userId, OAuthProvider provider);

    List<AuthIdentity> findByUserIdOrderByCreatedAtAsc(Long userId);

    long countByUserId(Long userId);
}
