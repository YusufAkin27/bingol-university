package edu.bingol.backend.post;

/**
 * Gonderi ya da yorum metni yazildi/degisti (ayni islemde, esenkronize yayinlanir). post.social dinler:
 * #etiket / @etiket ayristirir, dogrular (ihlalde ApiException = islem geri alinir) ve bildirim gonderir.
 * commentId null ise gonderi metnidir.
 */
public record SocialTextEvent(Long postId, Long commentId, Long actorId, String text) {}
