package edu.bingol.backend.forum.topic.spi;

import java.util.Set;

/**
 * SPI (uygulayan: forum.moderation, D; forum_user_mute tablosu): bakanin sessize aldigi kullanicilar (tek yonlu).
 * A listeleri/aramayi bu kumeyle suzer. Uygulama yoksa (bean yok) sessize alma uygulanmaz. Engel ({@code BlockService})
 * ayrica ve iki yonludur; bu arayuz yalniz sessize almayi kapsar.
 */
public interface ForumMuteLookup {

    /** {@code viewerId}'nin sessize aldigi kullanici kimlikleri (bos olabilir, null donmez). */
    Set<Long> mutedBy(Long viewerId);
}
