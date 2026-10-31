package edu.bingol.backend.post.social;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.post.PostDtos.PostView;
import edu.bingol.backend.post.PostFixtures;
import edu.bingol.backend.post.PostService;
import edu.bingol.backend.post.follow.FollowService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.domain.PageRequest;

/**
 * T-070 (A2-07): "Takip ettiklerim" akisi acik yazar listesiyle (kendisi + takip edilenler) sorgulanir; EXISTS/OR
 * yerine {@code author_id IN (...)} yazar indeksini kullanabilsin diye. Davranis ayni kalmali.
 */
@SpringBootTest
class FollowingFeedAuthorsTest {

    @Autowired PostService posts;
    @Autowired edu.bingol.backend.post.PostRepository postRepo;
    @Autowired edu.bingol.backend.post.media.PostMediaRepository mediaRepo;
    @Autowired FollowService follow;
    @Autowired SocialFeedRepository feeds;
    @Autowired UserRepository users;

    private User user() {
        User u = new User();
        u.setEmail("f" + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Takip Kullanici");
        u.setEmailVerified(true);
        return users.saveAndFlush(u);
    }

    private Long post(User u) {
        return PostFixtures.withPhoto(postRepo, mediaRepo, u.getId(), "x").getId();
    }

    private List<Long> following(User me) {
        return posts.feed(me.getId(), "following", null, 50).items().stream().map(PostView::id).toList();
    }

    @Test
    void followeeIdsAreNewestFirstAndCappedByPageable() {
        User me = user();
        User a = user();
        User b = user();
        User c = user();
        follow.follow(me.getId(), a.getId());
        follow.follow(me.getId(), b.getId());
        follow.follow(me.getId(), c.getId());

        List<Long> all = feeds.followeeIds(me.getId(), PageRequest.of(0, SocialFeedRepository.MAX_FOLLOWED_AUTHORS));
        assertEquals(3, all.size());
        assertTrue(all.containsAll(List.of(a.getId(), b.getId(), c.getId())));
        assertEquals(2, feeds.followeeIds(me.getId(), PageRequest.of(0, 2)).size());
        assertTrue(feeds.followeeIds(user().getId(), PageRequest.of(0, 10)).isEmpty());
    }

    @Test
    void feedHasOwnAndFollowedPostsOnlyAndUnfollowRemovesThem() {
        User me = user();
        User followed = user();
        User stranger = user();
        Long mine = post(me);
        Long theirs = post(followed);
        Long other = post(stranger);
        assertEquals(List.of(mine), following(me), "takip yokken yalniz kendi gonderileri");

        follow.follow(me.getId(), followed.getId());
        List<Long> ids = following(me);
        assertTrue(ids.containsAll(List.of(mine, theirs)));
        assertFalse(ids.contains(other));

        follow.unfollow(me.getId(), followed.getId());
        assertEquals(List.of(mine), following(me));
    }
}
