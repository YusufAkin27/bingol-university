package edu.bingol.backend.share;

import java.util.Collection;
import java.util.Map;

/**
 * Kampus Forum konu/yorum paylasim cozumleyicisi (uygulama: {@code forum.share}). {@link ShareService} yalniz bu
 * arayuzu tanir; forum paketine dogrudan bagimliligi yoktur.
 *
 * <p>Sozlesme: yalniz GORUNEN icerikler doner (silinmis/kaldirilmis/engelli/sessize alinmis/pasif yazar donmez; var/yok
 * ayrimi yapilmaz). {@code viewerId == null}: herkese acik (anonim) onizleme. Anonim icerikte yazar kimligi/adi
 * {@code Resolved} icinde HIC bulunmaz.
 */
public interface ForumShareResolver {

    Map<ShareRef, ShareService.Resolved> resolve(Long viewerId, Collection<ShareRef> refs);
}
