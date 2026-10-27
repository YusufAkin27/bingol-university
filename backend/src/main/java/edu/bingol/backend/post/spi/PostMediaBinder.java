package edu.bingol.backend.post.spi;

import java.util.List;

/**
 * Gonderi olusturulurken yuklenmis medyayi baglar (B uygular).
 * attach: mediaIds sirasiyla position verir; medya ownerId'ye ait, post_id'si bos, en cok 10 (en cok 10 video)
 * olmali, aksi halde ApiException 400 POST_MEDIA_INVALID. Gonderi ile ayni islemde cagrilir (hata = geri alma).
 */
public interface PostMediaBinder {

    void attach(long postId, long ownerId, List<Long> mediaIds);

    /** Gonderiye bagli medya id'leri (silme olayi icin). */
    List<Long> mediaIdsOf(long postId);
}
