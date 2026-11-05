package edu.bingol.backend.forum.poll;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ForumPollVoteRepository extends JpaRepository<ForumPollVote, ForumPollVoteId> {

    /** Kullanicinin bu ankette verdigi secenek (yoksa bos). */
    @Query("select v.optionId from ForumPollVote v where v.pollId = :pollId and v.userId = :userId")
    Optional<Long> optionOf(@Param("pollId") Long pollId, @Param("userId") Long userId);

    /** Birden cok anket icin kullanicinin secimleri: [pollId, optionId]. */
    @Query("select v.pollId, v.optionId from ForumPollVote v where v.userId = :userId and v.pollId in :pollIds")
    List<Object[]> choicesOf(@Param("userId") Long userId, @Param("pollIds") Collection<Long> pollIds);

    /**
     * Yeni oy: YEREL INSERT. Ayni (anket, kullanici) ikinci kez eklenirse tekillik kisiti
     * DataIntegrityViolationException firlatir (es zamanli cift oy burada elenir).
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(value = "INSERT INTO forum_poll_vote (poll_id, user_id, option_id, created_at) "
            + "VALUES (:pollId, :userId, :optionId, CURRENT_TIMESTAMP)", nativeQuery = true)
    int insertVote(@Param("pollId") Long pollId, @Param("userId") Long userId, @Param("optionId") Long optionId);

    /** Kosullu degisim: yalniz oy hala {@code fromOption} ise gunceller (es zamanli degisimde 0 doner). */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("update ForumPollVote v set v.optionId = :toOption where v.pollId = :pollId and v.userId = :userId and v.optionId = :fromOption")
    int changeOption(@Param("pollId") Long pollId, @Param("userId") Long userId,
                     @Param("fromOption") Long fromOption, @Param("toOption") Long toOption);

    /** Kosullu geri alma: yalniz oy hala {@code option} ise siler. */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("delete from ForumPollVote v where v.pollId = :pollId and v.userId = :userId and v.optionId = :option")
    int deleteVote(@Param("pollId") Long pollId, @Param("userId") Long userId, @Param("option") Long option);
}
