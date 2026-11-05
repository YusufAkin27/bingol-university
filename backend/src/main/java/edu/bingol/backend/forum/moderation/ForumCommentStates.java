package edu.bingol.backend.forum.moderation;

/**
 * B'nin yorum durum servisine (kaldir/geri al) ince kapi. B'nin arayuzu yayinlanana kadar ayri tutulur; uygulama
 * {@link ForumCommentStatesImpl}'dir.
 */
public interface ForumCommentStates {

    void remove(Long commentId, String reason);

    void restore(Long commentId);
}
