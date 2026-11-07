package edu.bingol.backend.forum.profile;

import java.util.Collection;
import java.util.Map;

/**
 * Profil / kaydedilenler listelerinin yorum satirlari icin B'nin (forum.comment) {@code CommentView} gorunumunu veren
 * kosum noktasi. Uygulama B'ye baglanan ince bir adaptordur ({@link ForumProfileCommentsAdapter}); B'nin gorunurluk
 * kurali (silinmis/kaldirilmis/engelli/sessize alinmis/anonim) tek yerde kalir: gorunmeyen yorum haritada YOKTUR.
 * Donen deger JSON'a oldugu gibi serilestirilir (CommentView).
 */
public interface ForumProfileComments {

    /** @return yorum kimligi -> CommentView (bakan icin gorunur olanlar) */
    Map<Long, Object> views(Collection<Long> commentIds, Long viewerId);
}
