package edu.bingol.backend.forum.notify;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ForumNotificationPrefRepository extends JpaRepository<ForumNotificationPref, Long> {

    /** Verilen kullanicilarin kayitli tercihleri (satiri olmayan = hepsi acik). */
    List<ForumNotificationPref> findByUserIdIn(Collection<Long> userIds);
}
