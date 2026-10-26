package edu.bingol.backend.event.extras;

import java.util.Collection;
import java.util.HashSet;
import java.util.Set;

/**
 * EventService'in "yonetici mi" kontrolune ortak organizatoru da katmak icin bagladigi dar arayuz
 * (@Lazy setter ile; dongusel bagimlilik olmaz, null iken eski davranis).
 */
public interface CoOrganizerLookup {

    boolean isCoOrganizer(Long eventId, Long userId);

    /** eventIds icinden kullanicinin ortak organizator oldugu etkinlikler (liste goruntulerinde toplu kontrol). */
    default Set<Long> coOrganizedAmong(Collection<Long> eventIds, Long userId) {
        Set<Long> out = new HashSet<>();
        eventIds.forEach(id -> {
            if (isCoOrganizer(id, userId)) {
                out.add(id);
            }
        });
        return out;
    }
}
