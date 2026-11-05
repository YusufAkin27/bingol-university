package edu.bingol.backend.forum.topic;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ForumTopicFollowRepository extends JpaRepository<ForumTopicFollow, TopicUserId> {

    @Query("SELECT f.id.topicId FROM ForumTopicFollow f WHERE f.id.userId = :uid AND f.follow = TRUE "
            + "AND f.id.topicId IN :ids")
    List<Long> followedAmong(@Param("uid") Long userId, @Param("ids") Collection<Long> topicIds);

    /** Takip eden VE bildirimi acik kullanicilar (kimlik sirali, sinirli). */
    @Query("SELECT f.id.userId FROM ForumTopicFollow f WHERE f.id.topicId = :tid AND f.follow = TRUE "
            + "AND f.notify = TRUE ORDER BY f.id.userId")
    List<Long> notifyFollowers(@Param("tid") Long topicId, Pageable page);

    /** Bildirimi kapatilmis satirlar (takip eden ya da etmeyen). */
    @Query("SELECT f FROM ForumTopicFollow f WHERE f.id.topicId = :tid AND f.id.userId = :uid")
    Optional<ForumTopicFollow> find(@Param("tid") Long topicId, @Param("uid") Long userId);
}
