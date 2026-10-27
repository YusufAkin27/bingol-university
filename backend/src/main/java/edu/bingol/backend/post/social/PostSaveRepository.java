package edu.bingol.backend.post.social;

import edu.bingol.backend.post.PostRepository;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PostSaveRepository extends JpaRepository<PostSave, PairId> {

    String LIVE = "AND EXISTS (SELECT 1 FROM Post p WHERE p.id = s.id.b AND " + PostRepository.VISIBLE + ") ";

    @Query("SELECT s FROM PostSave s WHERE s.id.a = :viewer " + LIVE + "ORDER BY s.createdAt DESC, s.id.b DESC")
    List<PostSave> first(@Param("viewer") Long viewer, Pageable page);

    @Query("SELECT s FROM PostSave s WHERE s.id.a = :viewer " + LIVE
            + "AND (s.createdAt < :at OR (s.createdAt = :at AND s.id.b < :cid)) ORDER BY s.createdAt DESC, s.id.b DESC")
    List<PostSave> after(@Param("viewer") Long viewer, @Param("at") Instant at, @Param("cid") Long cid, Pageable page);

    @Query("SELECT s.id.b FROM PostSave s WHERE s.id.a = :viewer AND s.id.b IN :ids")
    List<Long> savedAmong(@Param("viewer") Long viewer, @Param("ids") Collection<Long> ids);
}
