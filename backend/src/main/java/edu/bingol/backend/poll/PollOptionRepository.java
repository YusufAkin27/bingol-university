package edu.bingol.backend.poll;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PollOptionRepository extends JpaRepository<PollOption, Long> {

    List<PollOption> findByPollIdOrderByPositionAsc(Long pollId);

    List<PollOption> findByPollIdInOrderByPollIdAscPositionAsc(Collection<Long> pollIds);

    /** Atomik sayac guncelleme (okuma-degistirme-yazma yarisi yok). */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE PollOption o SET o.voteCount = o.voteCount + :votes, o.rankScore = o.rankScore + :score WHERE o.id = :id")
    int addCounts(@Param("id") Long optionId, @Param("votes") int votes, @Param("score") int score);

    @org.springframework.transaction.annotation.Transactional
    void deleteByPollId(Long pollId);
}
