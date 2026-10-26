package edu.bingol.backend.notification;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface NotificationSubtypePrefRepository extends JpaRepository<NotificationSubtypePref, Long> {

    List<NotificationSubtypePref> findByUserId(Long userId);

    Optional<NotificationSubtypePref> findByUserIdAndSubtype(Long userId, String subtype);
}
