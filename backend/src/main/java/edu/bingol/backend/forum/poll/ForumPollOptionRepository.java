package edu.bingol.backend.forum.poll;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ForumPollOptionRepository extends JpaRepository<ForumPollOption, Long> {

    List<ForumPollOption> findByPollIdOrderByPositionAscIdAsc(Long pollId);

    List<ForumPollOption> findByPollIdInOrderByPollIdAscPositionAscIdAsc(Collection<Long> pollIds);

    /**
     * Atomik sayac degisimi (okuma-degistir-yaz YOK). Azaltma 0'in altina inmez; etkilenen satir 0 ise sayac zaten
     * 0'dir (tutarsizlik sinyali), cagiran yoksayabilir.
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("update ForumPollOption o set o.voteCount = o.voteCount + :delta where o.id = :id and o.voteCount + :delta >= 0")
    int addVotes(@Param("id") Long id, @Param("delta") int delta);
}
