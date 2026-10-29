package edu.bingol.backend.poll;

import jakarta.persistence.LockModeType;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface PollBallotRepository extends JpaRepository<PollBallot, Long> {

    Optional<PollBallot> findByPollIdAndUserId(Long pollId, Long userId);

    /** Ayni kullanicinin es zamanli oy/geri cekme istekleri siraya girer; farkli kullanicilar birbirini beklemez. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT b FROM PollBallot b WHERE b.pollId = :pollId AND b.userId = :userId")
    Optional<PollBallot> lockByPollIdAndUserId(@Param("pollId") Long pollId, @Param("userId") Long userId);

    List<PollBallot> findByUserIdAndPollIdIn(Long userId, Collection<Long> pollIds);

    @Transactional
    void deleteByPollIdAndUserId(Long pollId, Long userId);

    @Transactional
    void deleteByPollId(Long pollId);
}
