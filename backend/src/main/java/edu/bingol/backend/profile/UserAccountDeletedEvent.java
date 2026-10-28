package edu.bingol.backend.profile;

import java.util.List;

/**
 * Hesap silindi (anonimlestirildi). Islem commit olduktan sonra dinleyiciler artik kayitlari toparlar: sahipsiz kulup,
 * yetim etkinlik basvurulari/bekleme listesi, kulup gonderisi gorselleri. Dinleyiciler exception sizdirmamalidir.
 *
 * @param freedEventIds kullanicinin GOING RSVP'si silinip koltugu serbest kalan etkinlikler (bekleme listesi terfisi icin)
 */
public record UserAccountDeletedEvent(Long userId, List<Long> freedEventIds) {}
