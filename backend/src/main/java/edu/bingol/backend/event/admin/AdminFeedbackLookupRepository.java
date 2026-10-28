package edu.bingol.backend.event.admin;

import edu.bingol.backend.event.extras.EventFeedback;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

/** Yonetici geri bildirim silme icin kimlik+etkinlik aramasi (bean: adminFeedbackLookupRepository). */
public interface AdminFeedbackLookupRepository extends JpaRepository<EventFeedback, Long> {

    Optional<EventFeedback> findByIdAndEventId(Long id, Long eventId);
}
