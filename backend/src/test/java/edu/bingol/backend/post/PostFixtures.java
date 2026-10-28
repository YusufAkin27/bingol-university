package edu.bingol.backend.post;

import edu.bingol.backend.post.media.PostMedia;
import edu.bingol.backend.post.media.PostMediaRepository;
import java.util.UUID;

/**
 * Test yardimcisi: sade gonderi sozlesmesi (tek fotograf zorunlu) service.create ile fotograf yuklemeyi gerektirir;
 * akis/moderasyon testleri icin dogrudan Post + baglanmis IMAGE medya satiri yazar (metin kurali uygulanmaz).
 */
public final class PostFixtures {

    private PostFixtures() {}

    public static PostMedia media(PostMediaRepository repo, Long owner, Long postId, String kind) {
        PostMedia m = new PostMedia();
        m.setOwnerId(owner);
        m.setPostId(postId);
        m.setKind(kind);
        m.setStorageKey("t/" + UUID.randomUUID() + (PostMedia.VIDEO.equals(kind) ? ".mp4" : ".jpg"));
        m.setContentType(PostMedia.VIDEO.equals(kind) ? "video/mp4" : "image/jpeg");
        m.setBytes(10);
        return repo.saveAndFlush(m);
    }

    /** Fotografsiz gonderi (eski veri; akista gorunmez). */
    public static Post textOnly(PostRepository posts, Long author, String text) {
        Post p = new Post();
        p.setAuthorId(author);
        p.setBody(text);
        return posts.saveAndFlush(p);
    }

    /** Fotografli gonderi (feed'de gorunur). */
    public static Post withPhoto(PostRepository posts, PostMediaRepository media, Long author, String text) {
        Post p = new Post();
        p.setAuthorId(author);
        p.setBody(text);
        p.setMediaCount((short) 1);
        p = posts.saveAndFlush(p);
        media(media, author, p.getId(), PostMedia.IMAGE);
        return p;
    }
}
