package edu.bingol.backend.poll;

import edu.bingol.backend.academic.AudienceKey;
import jakarta.persistence.LockModeType;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface PollRepository extends JpaRepository<Poll, Long>, JpaSpecificationExecutor<Poll> {

    /** Oy/durum degisikliklerini bir anket icin sirala (cift oy ve sayac yarisi buradan kilitlenir). */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT p FROM Poll p WHERE p.id = :id")
    Optional<Poll> lockById(@Param("id") Long id);

    Optional<Poll> findByMenuDate(LocalDate date);

    /** Acik anketler: pencere icinde, genel ya da uyesi olunan kuluplerden. */
    @Query("""
            SELECT p FROM Poll p WHERE p.id < :cursor AND p.status = :open
              AND p.opensAt <= :now AND (p.closesAt IS NULL OR p.closesAt > :now)
              AND (p.scope <> :community OR p.communityId IN :communityIds)
            ORDER BY p.id DESC
            """)
    List<Poll> openQuery(@Param("cursor") long cursor, @Param("now") Instant now,
                         @Param("communityIds") Collection<Long> communityIds, @Param("open") Poll.Status open,
                         @Param("community") Poll.Scope community, Pageable page);

    default List<Poll> open(long cursor, Instant now, Collection<Long> communityIds, Pageable page) {
        return openQuery(cursor, now, communityIds, Poll.Status.OPEN, Poll.Scope.COMMUNITY, page);
    }

    /** Kapanmis anketler (durum CLOSED ya da suresi dolmus). */
    @Query("""
            SELECT p FROM Poll p WHERE p.id < :cursor
              AND (p.status = :closed OR (p.status = :open AND p.closesAt IS NOT NULL AND p.closesAt <= :now))
              AND (p.scope <> :community OR p.communityId IN :communityIds)
            ORDER BY p.id DESC
            """)
    List<Poll> closedQuery(@Param("cursor") long cursor, @Param("now") Instant now,
                           @Param("communityIds") Collection<Long> communityIds, @Param("open") Poll.Status open,
                           @Param("closed") Poll.Status closed, @Param("community") Poll.Scope community, Pageable page);

    default List<Poll> closed(long cursor, Instant now, Collection<Long> communityIds, Pageable page) {
        return closedQuery(cursor, now, communityIds, Poll.Status.OPEN, Poll.Status.CLOSED, Poll.Scope.COMMUNITY, page);
    }

    /** Oluşturduklarim ve oy verdiklerim. */
    @Query("""
            SELECT p FROM Poll p WHERE p.id < :cursor
              AND (p.createdBy = :uid OR p.id IN (SELECT b.pollId FROM PollBallot b WHERE b.userId = :uid))
            ORDER BY p.id DESC
            """)
    List<Poll> mine(@Param("cursor") long cursor, @Param("uid") Long userId, Pageable page);

    @Query("""
            SELECT p FROM Poll p WHERE p.id < :cursor AND p.communityId = :communityId
              AND (:includeDraft = TRUE OR p.status <> :draft)
            ORDER BY p.id DESC
            """)
    List<Poll> ofCommunityQuery(@Param("cursor") long cursor, @Param("communityId") Long communityId,
                                @Param("includeDraft") boolean includeDraft, @Param("draft") Poll.Status draft, Pageable page);

    default List<Poll> ofCommunity(long cursor, Long communityId, boolean includeDraft, Pageable page) {
        return ofCommunityQuery(cursor, communityId, includeDraft, Poll.Status.DRAFT, page);
    }

    /** Suresi dolan acik anketler (kapanis isi). */
    List<Poll> findByStatusAndClosesAtLessThanEqual(Poll.Status status, Instant now);

    /** Acilisi bildirilmemis, simdi acik, bildirimli anketler. */
    @Query("SELECT p FROM Poll p WHERE p.status = :open AND p.notify = TRUE AND p.openedNotifiedAt IS NULL AND p.opensAt <= :now")
    List<Poll> openedNotNotifiedQuery(@Param("now") Instant now, @Param("open") Poll.Status open);

    default List<Poll> openedNotNotified(Instant now) {
        return openedNotNotifiedQuery(now, Poll.Status.OPEN);
    }

    /** Kapanisa `until` kadar kalmis, bildirilmemis, bildirimli anketler. */
    @Query("SELECT p FROM Poll p WHERE p.status = :open AND p.notify = TRUE "
            + "AND p.closingNotifiedAt IS NULL AND p.closesAt IS NOT NULL AND p.closesAt > :now AND p.closesAt <= :until "
            + "AND p.opensAt <= :now")
    List<Poll> closingSoonQuery(@Param("now") Instant now, @Param("until") Instant until, @Param("open") Poll.Status open);

    default List<Poll> closingSoonNotNotified(Instant now, Instant until) {
        return closingSoonQuery(now, until, Poll.Status.OPEN);
    }

    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE Poll p SET p.voterCount = p.voterCount + :delta WHERE p.id = :id")
    int addVoters(@Param("id") Long id, @Param("delta") int delta);

    /**
     * Oy yolunun SON adimi: secmen sayacini atomik gunceller VE anketin hala acik oldugunu ayni ifadede dogrular (0 donerse
     * kapandi/iptal/acilmamis). Satir kilidi bu ifadeden commit'e kadar tutulur; bu yuzden oy islemi bunu en sona koyar.
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("""
            UPDATE Poll p SET p.voterCount = p.voterCount + :delta
            WHERE p.id = :id AND p.status = :open AND p.opensAt <= :now
              AND (p.closesAt IS NULL OR p.closesAt > :now)""")
    int addVotersIfOpen(@Param("id") Long id, @Param("delta") int delta, @Param("now") Instant now,
                        @Param("open") Poll.Status open);

    default int addVotersIfOpen(Long id, int delta, Instant now) {
        return addVotersIfOpen(id, delta, now, Poll.Status.OPEN);
    }

    /** Acildi bildirimi isareti (yalniz henuz isaretlenmemisse; 0 donerse baska ornek gondermistir). */
    @Transactional
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE Poll p SET p.openedNotifiedAt = :now WHERE p.id = :id AND p.openedNotifiedAt IS NULL")
    int markOpenedNotified(@Param("id") Long id, @Param("now") Instant now);

    @Transactional
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE Poll p SET p.closingNotifiedAt = :now WHERE p.id = :id AND p.closingNotifiedAt IS NULL")
    int markClosingNotified(@Param("id") Long id, @Param("now") Instant now);

    long countByStatus(Poll.Status status);

    long countByScope(Poll.Scope scope);

    @Query("SELECT COALESCE(SUM(p.voterCount), 0) FROM Poll p")
    long totalVoters();

    // ---- Liste sayaclari (sekme rozetleri / arsiv sayisi): tek COUNT; hedef kitle SQL'de eslenir ----

    /** Acik anket sayisi (uyelik + hedef kitle); `all` = hedef kitle suzgeci yok (sistem yoneticisi). */
    @Query("""
            SELECT COUNT(p) FROM Poll p WHERE p.status = :open
              AND p.opensAt <= :now AND (p.closesAt IS NULL OR p.closesAt > :now)
              AND (p.scope <> :community OR p.communityId IN :communityIds)
              AND (:all = TRUE OR p.createdBy = :uid
                   OR ((p.audienceFaculty IS NULL OR LOWER(FUNCTION('translate', TRIM(p.audienceFaculty), :tFrom, :tTo)) = :fac)
                   AND (p.audienceDepartment IS NULL OR LOWER(FUNCTION('translate', TRIM(p.audienceDepartment), :tFrom, :tTo)) = :dep)
                   AND (p.audienceGrade IS NULL OR UPPER(TRIM(p.audienceGrade)) = :grade)))
            """)
    long countOpenQuery(@Param("now") Instant now, @Param("communityIds") Collection<Long> communityIds,
                        @Param("open") Poll.Status open, @Param("community") Poll.Scope community,
                        @Param("all") boolean all, @Param("uid") Long uid, @Param("fac") String fac,
                        @Param("dep") String dep, @Param("grade") String grade, @Param("tFrom") String tFrom,
                        @Param("tTo") String tTo);

    /**
     * `fac`/`dep`: {@code AudienceKey.of} anahtari (bos profil = ayirici deger), `grade`: BUYUK harf. Olusturan kendi
     * anketini listede gordugu icin sayaca da girer (liste = sayac mantigi, T-042).
     */
    default long countOpen(Instant now, Collection<Long> communityIds, boolean all, Long uid, String fac, String dep,
                           String grade) {
        return countOpenQuery(now, communityIds, Poll.Status.OPEN, Poll.Scope.COMMUNITY, all, uid, fac, dep, grade,
                AudienceKey.fromChars(), AudienceKey.toChars());
    }

    /** Kapanmis anket sayisi (uyelik + hedef kitle). */
    @Query("""
            SELECT COUNT(p) FROM Poll p
            WHERE (p.status = :closed OR (p.status = :open AND p.closesAt IS NOT NULL AND p.closesAt <= :now))
              AND (p.scope <> :community OR p.communityId IN :communityIds)
              AND (:all = TRUE OR p.createdBy = :uid
                   OR ((p.audienceFaculty IS NULL OR LOWER(FUNCTION('translate', TRIM(p.audienceFaculty), :tFrom, :tTo)) = :fac)
                   AND (p.audienceDepartment IS NULL OR LOWER(FUNCTION('translate', TRIM(p.audienceDepartment), :tFrom, :tTo)) = :dep)
                   AND (p.audienceGrade IS NULL OR UPPER(TRIM(p.audienceGrade)) = :grade)))
            """)
    long countClosedQuery(@Param("now") Instant now, @Param("communityIds") Collection<Long> communityIds,
                          @Param("open") Poll.Status open, @Param("closed") Poll.Status closed,
                          @Param("community") Poll.Scope community, @Param("all") boolean all, @Param("uid") Long uid,
                          @Param("fac") String fac, @Param("dep") String dep, @Param("grade") String grade,
                          @Param("tFrom") String tFrom, @Param("tTo") String tTo);

    default long countClosed(Instant now, Collection<Long> communityIds, boolean all, Long uid, String fac, String dep,
                             String grade) {
        return countClosedQuery(now, communityIds, Poll.Status.OPEN, Poll.Status.CLOSED, Poll.Scope.COMMUNITY, all, uid,
                fac, dep, grade, AudienceKey.fromChars(), AudienceKey.toChars());
    }

    /**
     * Kulup silinince (T-047): kulubun taslak / acik anketleri tek ifadede iptal edilir (oylar kapanir, sonuclar kalir,
     * kapanis/acilis bildirimi sorgulari yalniz OPEN'a baktigi icin bildirim de durur). Doner: etkilenen satir.
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("""
            UPDATE Poll p SET p.status = :cancelled, p.closedAt = :now, p.updatedAt = :now
            WHERE p.communityId = :cid AND p.status IN (:open, :draft)""")
    int cancelOfCommunityQuery(@Param("cid") Long communityId, @Param("now") Instant now,
                               @Param("cancelled") Poll.Status cancelled, @Param("open") Poll.Status open,
                               @Param("draft") Poll.Status draft);

    default int cancelOfCommunity(Long communityId, Instant now) {
        return cancelOfCommunityQuery(communityId, now, Poll.Status.CANCELLED, Poll.Status.OPEN, Poll.Status.DRAFT);
    }

    /** Olusturduklarim + oy verdiklerim sayisi. */
    @Query("""
            SELECT COUNT(p) FROM Poll p
            WHERE p.createdBy = :uid OR p.id IN (SELECT b.pollId FROM PollBallot b WHERE b.userId = :uid)
            """)
    long countMine(@Param("uid") Long userId);

    @Query("SELECT COUNT(p) FROM Poll p WHERE p.communityId = :communityId AND (:includeDraft = TRUE OR p.status <> :draft)")
    long countOfCommunityQuery(@Param("communityId") Long communityId, @Param("includeDraft") boolean includeDraft,
                               @Param("draft") Poll.Status draft);

    default long countOfCommunity(Long communityId, boolean includeDraft) {
        return countOfCommunityQuery(communityId, includeDraft, Poll.Status.DRAFT);
    }
}
