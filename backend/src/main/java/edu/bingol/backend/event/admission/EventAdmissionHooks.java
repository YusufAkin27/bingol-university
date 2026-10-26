package edu.bingol.backend.event.admission;

import edu.bingol.backend.community.Actor;
import edu.bingol.backend.event.EventRsvp;
import edu.bingol.backend.event.UserEvent;

/**
 * EventService / AttendanceService'in alim kurallarina baglandigi dar arayuz (mevcut siniflardaki degisiklik
 * en az satirda kalsin; EventService bunu @Lazy setter ile alir, boylece dongusel bagimlilik olmaz).
 */
public interface EventAdmissionHooks {

    /** Bagimsiz etkinlik yonetici onayi gerektiriyor mu (app_setting: events_require_approval). */
    boolean requireApproval();

    /** Bagimsiz etkinlik acarken kullanici basina acik etkinlik ve gunluk acma sinirini uygular; asilirsa 429/409. */
    void beforeCreate(Actor a);

    /** APPROVAL modunda dogrudan GOING reddedilir (409 APPLICATION_REQUIRED). */
    void guardDirectRsvp(UserEvent e, EventRsvp.Status status);

    /**
     * Kullanicinin GOING RSVP'sini basvuru akisi uzerinden iptal eder (koltuk serbest, sira terfi). Kullanicinin
     * ACCEPTED basvurusu yoksa false doner ve cagiran eski yolu izler.
     */
    boolean withdrawAccepted(Actor a, UserEvent e);

    /** Kapasite degisti: yer acildiysa bekleme listesinden terfi. */
    void afterCapacityChanged(UserEvent e);

    /** Etkinlik iptal edildi: bekleyen basvurular kapanir. */
    void onEventCancelled(UserEvent e);

    /** APPROVAL modunda elle yoklama yalnizca kabul edilmis (GOING) katilimciya yapilir; degilse 409. */
    void requireEligibleForMark(UserEvent e, Long userId);
}
