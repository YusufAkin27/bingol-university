package edu.bingol.backend.event.extras;

/**
 * EventService'in "yonetici mi" kontrolune ortak organizatoru da katmak icin bagladigi dar arayuz
 * (@Lazy setter ile; dongusel bagimlilik olmaz, null iken eski davranis).
 */
public interface CoOrganizerLookup {

    boolean isCoOrganizer(Long eventId, Long userId);
}
