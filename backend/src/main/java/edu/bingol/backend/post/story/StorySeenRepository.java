package edu.bingol.backend.post.story;

import edu.bingol.backend.post.social.PairId;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface StorySeenRepository extends JpaRepository<StorySeen, PairId> {

    @Query("SELECT v FROM StorySeen v WHERE v.id.a = :story ORDER BY v.viewedAt DESC, v.id.b DESC")
    List<StorySeen> first(@Param("story") Long storyId, Pageable page);

    @Query("SELECT v FROM StorySeen v WHERE v.id.a = :story AND (v.viewedAt < :at OR (v.viewedAt = :at AND v.id.b < :cid)) "
            + "ORDER BY v.viewedAt DESC, v.id.b DESC")
    List<StorySeen> after(@Param("story") Long storyId, @Param("at") Instant at, @Param("cid") Long cid,
                          Pageable page);

    /** Bakanin gordugu hikayeler (verilenler icinden). */
    @Query("SELECT v.id.a FROM StorySeen v WHERE v.id.b = :viewer AND v.id.a IN :ids")
    List<Long> seenAmong(@Param("viewer") Long viewer, @Param("ids") Collection<Long> storyIds);
}
