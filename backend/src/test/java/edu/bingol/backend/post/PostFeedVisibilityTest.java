package edu.bingol.backend.post;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.post.media.PostMediaRepository;
import edu.bingol.backend.profile.privacy.ProfilePrivacy;
import edu.bingol.backend.profile.privacy.ProfilePrivacyRepository;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

/** QA-P: Kesfet/Senin Icin akisinin filtreleri: gizlenmis, silinmis, pasif yazar, gizli hesap, kendi gonderisi. */
@SpringBootTest
class PostFeedVisibilityTest {

    @Autowired PostService service;
    @Autowired PostRepository posts;
    @Autowired PostMediaRepository mediaRepo;
    @Autowired UserRepository users;
    @Autowired PostRankService rank;
    @Autowired ProfilePrivacyRepository privacy;

    private User user() {
        User u = new User();
        u.setEmail("v" + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Gorunurluk");
        u.setEmailVerified(true);
        return users.saveAndFlush(u);
    }

    private Post photo(User a) {
        return posts.saveAndFlush(PostFixtures.withPhoto(posts, mediaRepo, a.getId(), "t"));
    }

    private List<Long> walk(Long viewer, String scope) {
        List<Long> ids = new ArrayList<>();
        String cursor = null;
        for (int i = 0; i < 200; i++) {
            var page = service.feed(viewer, scope, cursor, 30);
            page.items().forEach(v -> ids.add(v.id()));
            cursor = page.nextCursor();
            if (cursor == null || page.exhausted() == Boolean.TRUE) {
                break;
            }
        }
        return ids;
    }

    @Test
    void hiddenDeletedInactiveAuthorAndPrivateAccountAreFilteredOwnPostStays() {
        User viewer = user();
        User ok = user();
        User suspended = user();
        User priv = user();
        Post good = photo(ok);
        Post own = photo(viewer);
        Post hidden = photo(ok);
        hidden.setHiddenAt(Instant.now());
        posts.saveAndFlush(hidden);
        Post deleted = photo(ok);
        deleted.setDeletedAt(Instant.now());
        posts.saveAndFlush(deleted);
        Post fromSuspended = photo(suspended);
        suspended.setStatus(UserStatus.SUSPENDED);
        users.saveAndFlush(suspended);
        Post fromPrivate = photo(priv);
        ProfilePrivacy pp = new ProfilePrivacy();
        pp.setUserId(priv.getId());
        pp.setPrivateAccount(true);
        privacy.saveAndFlush(pp);
        rank.recompute();

        for (String scope : new String[] {"top", "latest"}) {
            List<Long> all = walk(viewer.getId(), scope);
            assertTrue(all.contains(good.getId()), scope + ": gorunur gonderi");
            assertTrue(all.contains(own.getId()), scope + ": kendi gonderisi gorunur");
            assertFalse(all.contains(hidden.getId()), scope + ": gizlenmis");
            assertFalse(all.contains(deleted.getId()), scope + ": silinmis");
            assertFalse(all.contains(fromSuspended.getId()), scope + ": askidaki yazar");
            assertFalse(all.contains(fromPrivate.getId()), scope + ": gizli hesap, takipci degil");
        }
    }
}
