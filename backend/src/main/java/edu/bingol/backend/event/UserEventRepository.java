package edu.bingol.backend.event;

import java.time.Instant;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface UserEventRepository extends JpaRepository<UserEvent, Long> {

    /**
     * Kapasiteyi veritabani seviyesinde atomik uygular: yer varsa GOING sayisini 1 artirir (1 doner),
     * doluysa hicbir satir guncellenmez (0 doner). Eszamanli isteklerde satir kilidi sirayla uygular.
     */
    @Modifying(flushAutomatically = true)
    @Query("UPDATE UserEvent e SET e.goingCount = e.goingCount + 1 WHERE e.id = :id AND (e.capacity IS NULL OR e.goingCount < e.capacity)")
    int tryIncrementGoing(@Param("id") Long id);

    @Modifying(flushAutomatically = true)
    @Query("UPDATE UserEvent e SET e.goingCount = e.goingCount - 1 WHERE e.id = :id AND e.goingCount > 0")
    int decrementGoing(@Param("id") Long id);

    /** Toplulugun etkinlik kimlikleri (belirtilen kullanicinin olusturdugu etkinlikler haric). */
    @Query("SELECT e.id FROM UserEvent e WHERE e.communityId = :cid AND e.createdBy <> :uid")
    List<Long> idsByCommunityExcludingCreator(@Param("cid") Long communityId, @Param("uid") Long userId);

    /** Guncel GOING sayisi (birinci seviye onbellegi atlayan skaler sorgu). */
    @Query("SELECT e.goingCount FROM UserEvent e WHERE e.id = :id")
    int goingCount(@Param("id") Long id);

    /**
     * Yaklasan/tarih araligindaki etkinlikler (takvim sirasi: baslangic, id). Gorunurluk: topluluksuz ya da
     * ACTIVE + (PUBLIC veya uyesi oldugum) topluluk. communityId = 0 ise topluluk filtresi yok.
     * (cs, cid) onceki sayfanin son kaydidir (imec).
     */
    @Query("""
            SELECT e FROM UserEvent e
            WHERE e.status = :active AND e.endsAt >= :from AND e.startsAt < :to
              AND (:communityId = 0 OR e.communityId = :communityId)
              AND (e.startsAt > :cs OR (e.startsAt = :cs AND e.id > :cid))
              AND (e.communityId IS NULL OR e.communityId IN (
                    SELECT c.id FROM Community c WHERE c.status = :cActive AND (c.visibility = :pub
                      OR c.id IN (SELECT m.communityId FROM CommunityMember m WHERE m.userId = :uid AND m.status = :mActive))))
            ORDER BY e.startsAt, e.id
            """)
    List<UserEvent> upcoming(@Param("active") UserEvent.Status active, @Param("from") Instant from,
                             @Param("to") Instant to, @Param("communityId") long communityId,
                             @Param("cs") Instant cursorStart, @Param("cid") long cursorId,
                             @Param("cActive") edu.bingol.backend.community.Community.Status cActive,
                             @Param("pub") edu.bingol.backend.community.Community.Visibility pub,
                             @Param("uid") Long userId,
                             @Param("mActive") edu.bingol.backend.community.CommunityMember.Status mActive,
                             Pageable page);

    /**
     * Ana sayfa "one cikan": bitmemis ACTIVE etkinlikler icinde en cok GOING, esitlikte en yakin baslangic.
     * Gorunurluk kurali upcoming ile ayni; sayac denormalize (goingCount) oldugundan RSVP tablosu taranmaz.
     */
    @Query("""
            SELECT e FROM UserEvent e
            WHERE e.status = :active AND e.endsAt >= :now
              AND (e.communityId IS NULL OR e.communityId IN (
                    SELECT c.id FROM Community c WHERE c.status = :cActive AND (c.visibility = :pub
                      OR c.id IN (SELECT m.communityId FROM CommunityMember m WHERE m.userId = :uid AND m.status = :mActive))))
            ORDER BY e.goingCount DESC, e.startsAt, e.id
            """)
    List<UserEvent> featured(@Param("active") UserEvent.Status active, @Param("now") Instant now,
                             @Param("cActive") edu.bingol.backend.community.Community.Status cActive,
                             @Param("pub") edu.bingol.backend.community.Community.Visibility pub,
                             @Param("uid") Long userId,
                             @Param("mActive") edu.bingol.backend.community.CommunityMember.Status mActive,
                             Pageable page);

    /** Katilacaklarim: RSVP'li (GOING/INTERESTED), bitmemis, ACTIVE etkinlikler; takvim sirasi. */
    @Query("""
            SELECT e FROM UserEvent e
            WHERE e.status = :active AND e.endsAt >= :now
              AND (e.startsAt > :cs OR (e.startsAt = :cs AND e.id > :cid))
              AND e.id IN (SELECT r.eventId FROM EventRsvp r WHERE r.userId = :uid)
              AND (e.communityId IS NULL OR e.communityId IN (
                    SELECT c.id FROM Community c WHERE c.status = :cActive AND (c.visibility = :pub
                      OR c.id IN (SELECT m.communityId FROM CommunityMember m WHERE m.userId = :uid AND m.status = :mActive))))
            ORDER BY e.startsAt, e.id
            """)
    List<UserEvent> attending(@Param("active") UserEvent.Status active, @Param("now") Instant now,
                              @Param("cs") Instant cursorStart, @Param("cid") long cursorId,
                              @Param("uid") Long userId,
                              @Param("cActive") edu.bingol.backend.community.Community.Status cActive,
                              @Param("pub") edu.bingol.backend.community.Community.Visibility pub,
                              @Param("mActive") edu.bingol.backend.community.CommunityMember.Status mActive,
                              Pageable page);

    /**
     * Etkinliklerim, yaklasan/suren (mode upcoming|going): RSVP'li etkinlikler; own=true ise olusturduklarim da;
     * goingOnly=true ise yalniz GOING. Takvim sirasi, imec (cs, cid).
     */
    @Query("""
            SELECT e FROM UserEvent e
            WHERE e.status = :active AND e.endsAt >= :now
              AND (e.startsAt > :cs OR (e.startsAt = :cs AND e.id > :cid))
              AND ((:own = true AND e.createdBy = :uid)
                   OR e.id IN (SELECT r.eventId FROM EventRsvp r
                               WHERE r.userId = :uid AND (:goingOnly = false OR r.status = :going)))
              AND (e.createdBy = :uid OR e.communityId IS NULL OR e.communityId IN (
                    SELECT c.id FROM Community c WHERE c.status = :cActive AND (c.visibility = :pub
                      OR c.id IN (SELECT m.communityId FROM CommunityMember m WHERE m.userId = :uid AND m.status = :mActive))))
            ORDER BY e.startsAt, e.id
            """)
    List<UserEvent> mineUpcoming(@Param("active") UserEvent.Status active, @Param("now") Instant now,
                                 @Param("cs") Instant cursorStart, @Param("cid") long cursorId,
                                 @Param("uid") Long userId, @Param("own") boolean own,
                                 @Param("goingOnly") boolean goingOnly,
                                 @Param("going") EventRsvp.Status going,
                                 @Param("cActive") edu.bingol.backend.community.Community.Status cActive,
                                 @Param("pub") edu.bingol.backend.community.Community.Visibility pub,
                                 @Param("mActive") edu.bingol.backend.community.CommunityMember.Status mActive,
                                 Pageable page);

    /** Etkinliklerim, gecmis (mode past): bitmis ACTIVE etkinlikler (RSVP'li + olusturduklarim); yeniden eskiye, imec (cs, cid). */
    @Query("""
            SELECT e FROM UserEvent e
            WHERE e.status = :active AND e.endsAt < :now
              AND (e.startsAt < :cs OR (e.startsAt = :cs AND e.id < :cid))
              AND (e.createdBy = :uid OR e.id IN (SELECT r.eventId FROM EventRsvp r WHERE r.userId = :uid))
              AND (e.createdBy = :uid OR e.communityId IS NULL OR e.communityId IN (
                    SELECT c.id FROM Community c WHERE c.status = :cActive AND (c.visibility = :pub
                      OR c.id IN (SELECT m.communityId FROM CommunityMember m WHERE m.userId = :uid AND m.status = :mActive))))
            ORDER BY e.startsAt DESC, e.id DESC
            """)
    List<UserEvent> minePast(@Param("active") UserEvent.Status active, @Param("now") Instant now,
                             @Param("cs") Instant cursorStart, @Param("cid") long cursorId,
                             @Param("uid") Long userId,
                             @Param("cActive") edu.bingol.backend.community.Community.Status cActive,
                             @Param("pub") edu.bingol.backend.community.Community.Visibility pub,
                             @Param("mActive") edu.bingol.backend.community.CommunityMember.Status mActive,
                             Pageable page);

    /** Kulubun bitmemis, verilen durumlardaki etkinlik kimlikleri (kulup silinince iptal icin). */
    @Query("SELECT e.id FROM UserEvent e WHERE e.communityId = :cid AND e.status IN :statuses AND e.endsAt > :now")
    List<Long> liveIdsByCommunity(@Param("cid") Long communityId, @Param("statuses") List<UserEvent.Status> statuses,
                                  @Param("now") Instant now);

    /** Duzenlediklerim (iptal edilenler haric), yeniden eskiye. */
    @Query("SELECT e FROM UserEvent e WHERE e.createdBy = :uid AND e.status <> :cancelled AND e.id < :cursor ORDER BY e.id DESC")
    List<UserEvent> organizing(@Param("uid") Long userId, @Param("cancelled") UserEvent.Status cancelled,
                               @Param("cursor") long cursor, Pageable page);

    @Query("SELECT e FROM UserEvent e WHERE e.status = :status AND e.id < :cursor ORDER BY e.id DESC")
    List<UserEvent> byStatus(@Param("status") UserEvent.Status status, @Param("cursor") long cursor, Pageable page);

    /** Genel arama (SearchProvider): ILIKE; ACTIVE ve topluluksuz ya da PUBLIC + ACTIVE topluluk etkinlikleri. */
    @Query(value = """
            SELECT e.* FROM user_event e
            WHERE e.status = 'ACTIVE' AND e.ends_at >= now()
              AND (e.title ILIKE :pattern ESCAPE '!' OR e.description ILIKE :pattern ESCAPE '!' OR e.location ILIKE :pattern ESCAPE '!')
              AND (e.community_id IS NULL OR e.community_id IN
                    (SELECT c.id FROM community c WHERE c.status = 'ACTIVE' AND c.visibility = 'PUBLIC'))
            ORDER BY e.starts_at
            LIMIT :lim
            """, nativeQuery = true)
    List<UserEvent> search(@Param("pattern") String pattern, @Param("lim") int limit);
}
