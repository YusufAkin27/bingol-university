package edu.bingol.backend.forum.topic;

import edu.bingol.backend.forum.category.ForumCategory;
import edu.bingol.backend.forum.category.ForumCategoryRepository;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.time.Instant;
import java.util.UUID;
import javax.imageio.ImageIO;

/** Forum A testleri icin ortak yardimcilar (kullanici, kategori, konu satiri, PNG). */
public final class ForumTestSupport {

    private ForumTestSupport() {}

    public static User user(UserRepository users, String name) {
        User u = new User();
        u.setEmail(name + "-" + UUID.randomUUID() + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName(name);
        u.setEmailVerified(true);
        return users.save(u);
    }

    public static ForumCategory category(ForumCategoryRepository repo, String name) {
        ForumCategory c = new ForumCategory();
        c.setSlug(name.toLowerCase() + "-" + UUID.randomUUID().toString().substring(0, 8));
        c.setNameTr(name);
        c.setNameEn(name + " EN");
        c.setNameAr(name + " AR");
        c.setSortOrder(1);
        return repo.save(c);
    }

    /** Dogrudan konu satiri (sayac ve etkinlik zamani verilebilir). */
    public static ForumTopic topic(ForumTopicRepository repo, Long userId, Long categoryId, String title, int likes,
                                   int comments, boolean anonymous, long activityMinutesAgo) {
        ForumTopic t = new ForumTopic();
        t.setUserId(userId);
        t.setCategoryId(categoryId);
        t.setTitle(title);
        t.setBody("govde " + title);
        t.setAnonymous(anonymous);
        t.setLikeCount(likes);
        t.setCommentCount(comments);
        Instant at = Instant.now().minusSeconds(activityMinutesAgo * 60).truncatedTo(java.time.temporal.ChronoUnit.MICROS);
        t.setLastActivityAt(at);
        return repo.saveAndFlush(t);
    }

    public static byte[] png(int w, int h) {
        try {
            BufferedImage img = new BufferedImage(w, h, BufferedImage.TYPE_INT_RGB);
            for (int x = 0; x < w; x++) {
                for (int y = 0; y < h; y++) {
                    img.setRGB(x, y, (x * 7 + y * 13) & 0xFFFFFF);
                }
            }
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            ImageIO.write(img, "png", out);
            return out.toByteArray();
        } catch (java.io.IOException e) {
            throw new IllegalStateException(e);
        }
    }
}
