package edu.bingol.backend.forum.media;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ForumMediaRepository extends JpaRepository<ForumMedia, Long> {

    /** Erisim karari icin baglanti durumu: baglandigi konu (yoksa null). */
    @Query("SELECT i.topicId FROM ForumTopicImage i WHERE i.mediaId = :mid")
    Optional<Long> attachedTopic(@Param("mid") Long mediaId);

    /** Konuya baglanmamis yuklemelerin sayisi (bekleyen medya siniri). */
    @Query("SELECT COUNT(m) FROM ForumMedia m WHERE m.ownerId = :uid AND NOT EXISTS "
            + "(SELECT 1 FROM edu.bingol.backend.forum.topic.ForumTopicImage i WHERE i.mediaId = m.id)")
    long countUnattached(@Param("uid") Long ownerId);

    /** Baglanmamis ve {@code before}dan eski yuklemeler (supurucu). */
    @Query("SELECT m FROM ForumMedia m WHERE m.createdAt < :before AND NOT EXISTS "
            + "(SELECT 1 FROM edu.bingol.backend.forum.topic.ForumTopicImage i WHERE i.mediaId = m.id) ORDER BY m.id")
    List<ForumMedia> staleUnattached(@Param("before") Instant before, Pageable page);

    /** Yalniz hala baglanmamissa siler (supurucu ile baglama yarisi). */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("DELETE FROM ForumMedia m WHERE m.id = :id AND NOT EXISTS "
            + "(SELECT 1 FROM edu.bingol.backend.forum.topic.ForumTopicImage i WHERE i.mediaId = m.id)")
    int deleteIfUnattached(@Param("id") Long id);

    @Query("SELECT m.id, m.storageKey FROM ForumMedia m WHERE m.id > :after ORDER BY m.id")
    List<Object[]> keysAfter(@Param("after") long after, Pageable page);

    List<ForumMedia> findByIdIn(Collection<Long> ids);

    List<ForumMedia> findByOwnerId(Long ownerId);
}
