package edu.bingol.backend.post.social;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.post.PostDtos.PostView;
import edu.bingol.backend.post.PostFixtures;
import edu.bingol.backend.post.PostService;
import edu.bingol.backend.profile.privacy.Audience;
import edu.bingol.backend.profile.privacy.ProfilePrivacy;
import edu.bingol.backend.profile.privacy.ProfilePrivacyRepository;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.domain.PageRequest;

/**
 * A06#5: bolum akisi, "following" gibi ACIK yazar listesiyle (once bolum yazarlari, sonra author_id IN) sorgulanir;
 * boylece plan tum gonderi tablosunu zaman tersine gezip suzmez. Davranis (T-053 bolum gizliligi dahil) ayni kalir.
 */
@SpringBootTest
class DepartmentFeedAuthorsTest {

    @Autowired PostService posts;
    @Autowired edu.bingol.backend.post.PostRepository postRepo;
    @Autowired edu.bingol.backend.post.media.PostMediaRepository mediaRepo;
    @Autowired SocialFeedRepository feeds;
    @Autowired UserRepository users;
    @Autowired ProfilePrivacyRepository privacy;

    private User user(String dept) {
        User u = new User();
        u.setEmail("d" + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Bolum Kullanici");
        u.setEmailVerified(true);
        u.setDepartment(dept);
        return users.saveAndFlush(u);
    }

    private void hideDepartment(User u) {
        ProfilePrivacy p = new ProfilePrivacy();
        p.setUserId(u.getId());
        p.setDepartmentAudience(Audience.ONLY_ME);
        privacy.saveAndFlush(p);
    }

    private Long post(User u) {
        return PostFixtures.withPhoto(postRepo, mediaRepo, u.getId(), "x").getId();
    }

    @Test
    void authorListHasSameDepartmentActiveVisibleUsersOnly() {
        String dept = "Bol-" + UUID.randomUUID().toString().substring(0, 6);
        User me = user(dept);
        User mate = user(dept);
        User hidden = user(dept);
        hideDepartment(hidden);
        User suspended = user(dept);
        suspended.setStatus(UserStatus.SUSPENDED);
        users.saveAndFlush(suspended);
        User other = user("Baska-" + UUID.randomUUID().toString().substring(0, 6));

        List<Long> authors = feeds.departmentAuthors(me.getId(), dept, PageRequest.of(0, 100));
        assertTrue(authors.containsAll(List.of(me.getId(), mate.getId())));
        assertFalse(authors.contains(hidden.getId()), "bolumunu gizleyen yazar bolum akisinda yer almaz (T-053)");
        assertFalse(authors.contains(suspended.getId()));
        assertFalse(authors.contains(other.getId()));
        assertEquals(1, feeds.departmentAuthors(me.getId(), dept, PageRequest.of(0, 1)).size(), "sinir uygulanir");

        // gizleyen kisinin kendi bolum akisinda kendi gonderileri her zaman gorunur
        assertTrue(feeds.departmentAuthors(hidden.getId(), dept, PageRequest.of(0, 100)).contains(hidden.getId()));
    }

    @Test
    void departmentFeedStillShowsMatesAndHidesHiddenDepartmentAuthors() {
        String dept = "Bol-" + UUID.randomUUID().toString().substring(0, 6);
        User me = user(dept);
        User mate = user(dept);
        User hidden = user(dept);
        hideDepartment(hidden);
        Long pMate = post(mate);
        Long pHidden = post(hidden);
        Long pMine = post(me);
        List<Long> ids = posts.feed(me.getId(), "department", null, 20).items().stream().map(PostView::id).toList();
        assertTrue(ids.containsAll(List.of(pMate, pMine)));
        assertFalse(ids.contains(pHidden));
    }
}
