package edu.bingol.backend.messaging.room;

/** Bir oda turunde (kulup/etkinlik) baskasinin mesajini silebilecek kisileri kaynak modulun kurallariyla belirler. */
public interface RoomModerationAuthorizer {

    RoomKind kind();

    /** `refId` kaynagin (kulup/etkinlik) kimligidir; yetki yoksa ya da kaynak bulunamazsa false. */
    boolean canModerate(Long refId, Long userId);
}
