package edu.bingol.backend.profile.privacy;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProfilePrivacyRepository extends JpaRepository<ProfilePrivacy, Long> {

    List<ProfilePrivacy> findByUserIdIn(Collection<Long> userIds);
}
