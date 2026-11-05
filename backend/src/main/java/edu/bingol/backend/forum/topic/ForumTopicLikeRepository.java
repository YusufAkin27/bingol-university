package edu.bingol.backend.forum.topic;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ForumTopicLikeRepository extends JpaRepository<ForumTopicLike, TopicUserId> {

    @Query("SELECT l.id.topicId FROM ForumTopicLike l WHERE l.id.userId = :uid AND l.id.topicId IN :ids")
    List<Long> likedAmong(@Param("uid") Long userId, @Param("ids") Collection<Long> topicIds);
}
