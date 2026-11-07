package edu.bingol.backend.event;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface EventRsvpRepository extends JpaRepository<EventRsvp, Long> {

    Optional<EventRsvp> findByEventIdAndUserId(Long eventId, Long userId);

    List<EventRsvp> findByUserId(Long userId);

    long countByEventIdAndStatus(Long eventId, EventRsvp.Status status);

    List<EventRsvp> findByUserIdAndEventIdIn(Long userId, Collection<Long> eventIds);

    /** Toplu sayim [eventId, adet]: takvim/liste goruntulerinde etkinlik basina sorgu atmamak icin. */
    @Query("SELECT r.eventId, COUNT(r) FROM EventRsvp r WHERE r.eventId IN :ids AND r.status = :status GROUP BY r.eventId")
    List<Object[]> countByEvents(@Param("ids") Collection<Long> eventIds, @Param("status") EventRsvp.Status status);

    @Query("SELECT r FROM EventRsvp r WHERE r.eventId = :eid AND r.status = :status AND r.id > :cursor ORDER BY r.id")
    List<EventRsvp> page(@Param("eid") Long eventId, @Param("status") EventRsvp.Status status,
                         @Param("cursor") long cursor, Pageable page);

    /** Bildirim hedefleri: etkinlige GOING diyenler. */
    @Query("SELECT r.userId FROM EventRsvp r WHERE r.eventId = :eid AND r.status = :status")
    List<Long> userIds(@Param("eid") Long eventId, @Param("status") EventRsvp.Status status, Pageable page);

    /** Bildirim hedefleri, kimlik imecli (T-051): kullanici kimligine gore artan; sessiz kesme yok. */
    @Query("SELECT r.userId FROM EventRsvp r WHERE r.eventId = :eid AND r.status = :status AND r.userId > :after ORDER BY r.userId")
    List<Long> userIdsAfter(@Param("eid") Long eventId, @Param("status") EventRsvp.Status status,
                            @Param("after") long after, Pageable page);

    /** Yoklama listesi icin: etkinlikteki tum GOING RSVP'ler (kapasite sinirli oldugundan kucuk). */
    List<EventRsvp> findByEventIdAndStatus(Long eventId, EventRsvp.Status status);

    /** Hatirlatma adaylari [rsvp, event]: GOING, ACTIVE etkinlik, baslangic (lo, hi] araliginda. */
    @Query("""
            SELECT r, e FROM EventRsvp r, UserEvent e
            WHERE r.eventId = e.id AND r.status = :going AND e.status = :active
              AND e.startsAt > :lo AND e.startsAt <= :hi AND r.remindedDay = FALSE AND r.remindedHour = FALSE
              AND r.userId IN (SELECT u.id FROM User u WHERE u.status = edu.bingol.backend.user.UserStatus.ACTIVE)
            ORDER BY e.startsAt, r.id
            """)
    List<Object[]> dayCandidates(@Param("going") EventRsvp.Status going, @Param("active") UserEvent.Status active,
                                 @Param("lo") Instant lo, @Param("hi") Instant hi, Pageable page);

    @Query("""
            SELECT r, e FROM EventRsvp r, UserEvent e
            WHERE r.eventId = e.id AND r.status = :going AND e.status = :active
              AND e.startsAt > :lo AND e.startsAt <= :hi AND r.remindedHour = FALSE
              AND r.userId IN (SELECT u.id FROM User u WHERE u.status = edu.bingol.backend.user.UserStatus.ACTIVE)
            ORDER BY e.startsAt, r.id
            """)
    List<Object[]> hourCandidates(@Param("going") EventRsvp.Status going, @Param("active") UserEvent.Status active,
                                  @Param("lo") Instant lo, @Param("hi") Instant hi, Pageable page);

    /** Hatirlatmayi "sahiplen": yalnizca bayrak hala false ise 1 doner (cok sunuculu kurulumda cift gonderimi onler). */
    @Transactional
    @Modifying
    @Query("UPDATE EventRsvp r SET r.remindedDay = TRUE WHERE r.id = :id AND r.remindedDay = FALSE")
    int claimDay(@Param("id") Long id);

    /** FIX-P05: gonderim basarisiz olursa gun izi geri alinir (hatirlatma kalici kaybolmasin). */
    @Transactional
    @Modifying
    @Query("UPDATE EventRsvp r SET r.remindedDay = FALSE WHERE r.id = :id")
    int unclaimDay(@Param("id") Long id);

    /** FIX-P05: gonderim basarisiz olursa saat izi geri alinir (gun izi oldugu gibi kalir). */
    @Transactional
    @Modifying
    @Query("UPDATE EventRsvp r SET r.remindedHour = FALSE WHERE r.id = :id")
    int unclaimHour(@Param("id") Long id);

    /** Saat hatirlatmasi gonderildiyse gun hatirlatmasi da artik anlamsizdir; ikisi birden isaretlenir. */
    @Transactional
    @Modifying
    @Query("UPDATE EventRsvp r SET r.remindedHour = TRUE, r.remindedDay = TRUE WHERE r.id = :id AND r.remindedHour = FALSE")
    int claimHour(@Param("id") Long id);

    /**
     * FIX-P05 (A05#2): durum gecisini "sahiplen". Yalnizca satir hala {@code from} durumundaysa gunceller (1 doner);
     * es zamanli ikinci istek 0 alir ve going_count sayacina DOKUNMAMALIDIR (cift azaltma / cift artirma = hayalet koltuk).
     * Satir kilidi sayesinde ikinci istek ilkinin commit'ini bekler ve kosulu yeniden degerlendirir.
     */
    @Modifying(flushAutomatically = true)
    @Query("UPDATE EventRsvp r SET r.status = :to WHERE r.id = :id AND r.status = :from")
    int transition(@Param("id") Long id, @Param("from") EventRsvp.Status from, @Param("to") EventRsvp.Status to);

    /** FIX-P05: RSVP'yi "sahiplenerek" siler; yalniz silen ilk istek 1 alir (sayac cift azaltilmaz). */
    @Modifying(flushAutomatically = true)
    @Query("DELETE FROM EventRsvp r WHERE r.id = :id")
    int deleteClaim(@Param("id") Long id);

    /** Etkinlik saati degisince hatirlatma isaretlerini sifirlar (yeni saat icin tekrar hatirlatilir). */
    @Transactional
    @Modifying
    @Query("UPDATE EventRsvp r SET r.remindedDay = FALSE, r.remindedHour = FALSE WHERE r.eventId = :eid")
    int resetReminders(@Param("eid") Long eventId);
}
