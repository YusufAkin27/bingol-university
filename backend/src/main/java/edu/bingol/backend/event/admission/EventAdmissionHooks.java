package edu.bingol.backend.event.admission;

import edu.bingol.backend.community.Actor;
import edu.bingol.backend.event.EventRsvp;
import edu.bingol.backend.event.UserEvent;
import edu.bingol.backend.event.admission.EventAdmission.Mode;

/**
 * EventService / AttendanceService'in alim kurallarina baglandigi dar arayuz (mevcut siniflardaki degisiklik
 * en az satirda kalsin; EventService bunu @Lazy setter ile alir, boylece dongusel bagimlilik olmaz).
 */
public interface EventAdmissionHooks {

    /** Bagimsiz etkinlik yonetici onayi gerektiriyor mu (app_setting: events_require_approval). */
    boolean requireApproval();

    /** Bagimsiz etkinlik acarken kullanici basina acik etkinlik ve gunluk acma sinirini uygular; asilirsa 429/409. */
    void beforeCreate(Actor a);

    /** Etkinligin katilim turu (joinPolicy): satir yoksa OPEN. */
    EventAdmission.Mode joinPolicyOf(Long eventId);

    /** Toplu katilim turu (liste gorunumleri icin). Satiri olmayan kimlik haritada yoktur (= OPEN). */
    java.util.Map<Long, EventAdmission.Mode> joinPolicies(java.util.Collection<Long> eventIds);

    /** Katilim turunu yazar (olusturma/duzenleme). APPROVAL -> OPEN: bekleyen istekler kapanir ve haber verilir. */
    void applyJoinPolicy(UserEvent e, EventAdmission.Mode mode);

    /** Kullanicinin istek durumlari: PENDING (bekleyen/bekleme listesi) ve REJECTED; baska durum haritada yok. */
    java.util.Map<Long, EventRsvp.Status> requestStates(Long userId, java.util.Collection<Long> eventIds);

    /** Bekleyen istek sayilari (PENDING). Istek olmayan kimlik haritada yoktur. */
    java.util.Map<Long, Long> pendingCounts(java.util.Collection<Long> eventIds);

    /**
     * APPROVAL etkinlikte GOING istegi dogrudan katilim degil katilim isteginin acilmasidir (PENDING). Etkinlik
     * APPROVAL ise istegi acar ve true doner; OPEN ise false.
     */
    boolean requestIfApprovalRequired(Actor a, UserEvent e);

    /** (Eski) APPROVAL modunda dogrudan GOING reddedilir (409 APPLICATION_REQUIRED). */
    void guardDirectRsvp(UserEvent e, EventRsvp.Status status);

    /**
     * Kullanicinin GOING RSVP'sini ya da bekleyen isegini (PENDING/WAITLISTED/ACCEPTED) basvuru akisi uzerinden
     * geri ceker (koltuk serbest, sira terfi). Acik basvurusu yoksa false doner ve cagiran eski yolu izler.
     */
    boolean withdrawAccepted(Actor a, UserEvent e);

    /** Kapasite degisti: yer acildiysa bekleme listesinden terfi. */
    void afterCapacityChanged(UserEvent e);

    /** Etkinlik iptal edildi: bekleyen basvurular kapanir. */
    void onEventCancelled(UserEvent e);

    /**
     * Hesap silindi: kullanicinin acik basvurulari (PENDING/WAITLISTED/ACCEPTED) kapatilir ve koltugu serbest kalan
     * etkinliklerde (basvurusuyla ya da dogrudan GOING iken) bekleme listesi terfi eder.
     */
    void onUserDeleted(Long userId, java.util.Collection<Long> freedEventIds);

    /** APPROVAL modunda elle yoklama yalnizca kabul edilmis (GOING) katilimciya yapilir; degilse 409. */
    void requireEligibleForMark(UserEvent e, Long userId);
}
