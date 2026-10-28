package edu.bingol.backend.community;

import edu.bingol.backend.common.storage.FileStorage;
import edu.bingol.backend.media.MediaReferenceSource;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * Kulup gonderisi gorsellerini fiziksel olarak siler (KVKK silme: /files/posts/... kimlik dogrulamasiz ve 30 gun
 * onbellekli sunuldugu icin "silindi" yalnizca isaretle yetmez). Once gonderinin image_url alani bosaltilir, sonra
 * baska hicbir kayit dosyayi kullanmiyorsa dosya diskten kaldirilir. Hic exception firlatmaz.
 */
@Component
public class CommunityPostMedia {

    private static final Logger log = LoggerFactory.getLogger(CommunityPostMedia.class);

    private final CommunityPostRepository posts;
    private final FileStorage storage;
    private final List<MediaReferenceSource> sources;

    public CommunityPostMedia(CommunityPostRepository posts, FileStorage storage, List<MediaReferenceSource> sources) {
        this.posts = posts;
        this.storage = storage;
        this.sources = sources;
    }

    /** Verilen (zaten silinmis ya da silinecek) yazilarin gorselini alandan kaldirir ve dosyayi siler. */
    public void release(List<CommunityPost> list) {
        for (CommunityPost p : list) {
            String url = p.getImageUrl();
            if (url == null) {
                continue;
            }
            try {
                p.setImageUrl(null);
                posts.saveAndFlush(p);
                if (sources.stream().noneMatch(s -> s.isReferenced(url))) {
                    storage.delete(url);
                }
            } catch (RuntimeException e) {
                log.warn("Kulup gonderisi gorseli silinemedi (yazi {}): {}", p.getId(), e.toString());
            }
        }
    }

    /** Hesap silme: yazarin tum gorselli yazilarinin gorselleri. */
    public void releaseByAuthor(Long authorId) {
        release(posts.findByAuthorIdAndImageUrlIsNotNull(authorId));
    }

    /** Kulup silme: kulubun tum gorselli yazilarinin gorselleri. */
    public void releaseByCommunity(Long communityId) {
        release(posts.findByCommunityIdAndImageUrlIsNotNull(communityId));
    }
}
