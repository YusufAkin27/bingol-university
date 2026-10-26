package edu.bingol.backend.event.chat;

/**
 * EventService / EventAdmissionService'in etkinlik sohbet odasini senkron tuttugu dar arayuz (@Lazy setter ile
 * baglanir; null iken eski davranis). Hicbir metot exception sizdirmaz: oda senkronu basarisiz olsa katilim
 * islemi bozulmaz, bakim gorevi (EventChatMaintenance) tutarsizligi giderir.
 */
public interface EventChatHooks {

    /** Kullanici etkinlige GOING oldu (RSVP, basvuru kabulu, bekleme listesinden terfi). */
    void onGoing(Long eventId, Long userId);

    /** Kullanici GOING'den dustu (vazgecme, ret, cikarma). Organizator/ortak organizator odada kalir. */
    void onLeft(Long eventId, Long userId);

    /** Etkinlik iptal edildi: oda hemen kapanir. */
    void onCancelled(Long eventId);
}
