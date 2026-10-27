package edu.bingol.backend.poll;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.transaction.annotation.Transactional;

public interface PollVoteRepository extends JpaRepository<PollVote, Long> {

    List<PollVote> findByPollIdAndUserIdOrderByChoiceRankAsc(Long pollId, Long userId);

    List<PollVote> findByUserIdAndPollIdIn(Long userId, Collection<Long> pollIds);

    /** KVKK disa aktarim: yalniz kullanicinin kendi oylari. */
    List<PollVote> findByUserIdOrderByIdDesc(Long userId);

    @Transactional
    void deleteByPollIdAndUserId(Long pollId, Long userId);

    @Transactional
    void deleteByPollId(Long pollId);
}
