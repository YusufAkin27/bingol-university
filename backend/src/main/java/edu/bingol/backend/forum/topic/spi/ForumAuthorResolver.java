package edu.bingol.backend.forum.topic.spi;

import edu.bingol.backend.forum.topic.dto.Author;
import java.util.List;

/**
 * SPI (uygulayan: forum.topic, A): yazar gorunumunun TEK uretim yeri. Yorum (B), arama/profil (E) kendi
 * {@code Author} kodlarini yazmaz; gizlilik/anonimlik/takma ad kurali burada olsun diye bunu cagirir.
 * Anonim yazarda gercek kimlik, avatar ve bolum ASLA donmez; "Anonim #N" konu basina kararlidir.
 */
public interface ForumAuthorResolver {

    /**
     * @param topicId  takma adin ait oldugu konu (anonimse zorunlu)
     * @param userId   yazarin gercek kimligi
     * @param anonymous icerigin anonim secimi
     */
    record Key(Long topicId, Long userId, boolean anonymous) {}

    /** Girdi sirasiyla ayni uzunlukta liste; bilinmeyen/pasif kullanici icin kimliksiz "silinmis kullanici" yazari. */
    List<Author> resolve(Long viewerId, List<Key> keys);

    default Author resolve(Long viewerId, Key key) {
        return resolve(viewerId, List.of(key)).get(0);
    }
}
