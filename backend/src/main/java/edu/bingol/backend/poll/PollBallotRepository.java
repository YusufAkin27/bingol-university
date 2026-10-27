package edu.bingol.backend.poll;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.transaction.annotation.Transactional;

public interface PollBallotRepository extends JpaRepository<PollBallot, Long> {

    Optional<PollBallot> findByPollIdAndUserId(Long pollId, Long userId);

    List<PollBallot> findByUserIdAndPollIdIn(Long userId, Collection<Long> pollIds);

    @Transactional
    void deleteByPollIdAndUserId(Long pollId, Long userId);

    @Transactional
    void deleteByPollId(Long pollId);
}
