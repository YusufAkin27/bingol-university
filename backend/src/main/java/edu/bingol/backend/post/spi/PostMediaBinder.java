package edu.bingol.backend.post.spi;

import java.util.List;

/**
 * Gonderi olusturulurken yuklenmis medyayi baglar (B uygular).
 * attach: mediaIds sirasiyla position verir; medya ownerId'ye ait, post_id'si bos, en cok 10 (en cok 10 video)
 * olmali, aksi halde ApiException 400 POST_MEDIA_INVALID. Gonderi ile ayni islemde cagrilir (hata = geri alma).
 */
public interface PostMediaBinder {

    /**
     * Sade gonderi: medya tam 1 adet, ownerId'ye ait, baglanmamis ve FOTOGRAF olmali.
     * Video -> 400 POST_VIDEO_NOT_ALLOWED; diger gecersizlik -> 400 POST_MEDIA_INVALID.
     */
    void requireImage(long ownerId, List<Long> mediaIds);

    /**
     * Gonderi: medya 1..10 adet (sirali, tekrarsiz; asarsa 422 POST_MEDIA_LIMIT), ownerId'ye ait, baglanmamis ve gizli degil (fotograf ya da video).
     * Video tek basina olmali (422 POST_MEDIA_MIX). Gecersizlik -> 400 POST_MEDIA_INVALID. Doner: medyanin turu ("IMAGE" | "VIDEO").
     */
    String requireMedia(long ownerId, List<Long> mediaIds);

    void attach(long postId, long ownerId, List<Long> mediaIds);

    /** Gonderiye bagli medya id'leri (silme olayi icin). */
    List<Long> mediaIdsOf(long postId);
}
