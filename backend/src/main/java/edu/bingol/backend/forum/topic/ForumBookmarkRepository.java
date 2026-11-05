package edu.bingol.backend.forum.topic;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ForumBookmarkRepository extends JpaRepository<ForumBookmark, ForumBookmarkId> {

    @Query("SELECT b.id.targetId FROM ForumBookmark b WHERE b.id.userId = :uid AND b.id.targetType = :type "
            + "AND b.id.targetId IN :ids")
    List<Long> savedAmong(@Param("uid") Long userId, @Param("type") String type, @Param("ids") Collection<Long> ids);
}
