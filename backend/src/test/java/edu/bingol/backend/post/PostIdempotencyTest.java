package edu.bingol.backend.post;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.post.PostDtos.CreatePostRequest;
import edu.bingol.backend.post.PostDtos.PostView;
import edu.bingol.backend.post.media.PostMediaRepository;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

/** QA-P-07: POST /posts Idempotency-Key: ayni anahtar ikinci gonderi uretmez, ayni gonderiyi dondurur. */
@SpringBootTest
class PostIdempotencyTest {

    @Autowired PostService service;
    @Autowired PostRepository posts;
    @Autowired UserRepository users;
    @Autowired PostMediaRepository mediaRepo;

    private User user() {
        User u = new User();
        u.setEmail("i" + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Idem");
        u.setEmailVerified(true);
        return users.saveAndFlush(u);
    }

    private Long media(User u) {
        return PostFixtures.media(mediaRepo, u.getId(), null, "IMAGE").getId();
    }

    @Test
    void sameKeyReplaysSamePostAndDoesNotDuplicate() {
        User a = user();
        String key = "key-" + UUID.randomUUID();
        Long m = media(a);
        PostView first = service.create(a.getId(), new CreatePostRequest("merhaba", List.of(m)), key);
        PostView replay = service.replayByKey(a.getId(), key);
        assertEquals(first.id(), replay.id());
        assertEquals(1, posts.findAll().stream()
                .filter(p -> a.getId().equals(p.getAuthorId())).count());
    }

    @Test
    void sameKeyReplaysMultiPhotoPostWithAllMediaInOrder() {
        User a = user();
        String key = "key-" + UUID.randomUUID();
        Long m1 = media(a);
        Long m2 = media(a);
        PostView first = service.create(a.getId(), new CreatePostRequest("iki kare", List.of(m2, m1)), key);
        PostView replay = service.replayByKey(a.getId(), key);
        assertEquals(first.id(), replay.id());
        assertEquals(List.of(m2, m1), replay.media().stream().map(PostDtos.MediaView::id).toList());
    }

    @Test
    void unknownKeyOrNoKeyReplaysNothingAndKeysAreScopedPerUser() {
        User a = user();
        User b = user();
        String key = "key-" + UUID.randomUUID();
        assertNull(service.replayByKey(a.getId(), key));
        assertNull(service.replayByKey(a.getId(), null));
        PostView pa = service.create(a.getId(), new CreatePostRequest("a", List.of(media(a))), key);
        assertNull(service.replayByKey(b.getId(), key)); // baska kullanicinin anahtari sizmaz
        PostView pb = service.create(b.getId(), new CreatePostRequest("b", List.of(media(b))), key);
        assertNotEquals(pa.id(), pb.id());
    }

    @Test
    void invalidKeyIs400AndDeletedPostKeyCannotBeReused() {
        User a = user();
        ApiException bad = assertThrows(ApiException.class, () -> service.replayByKey(a.getId(), "x"));
        assertEquals("IDEMPOTENCY_KEY_INVALID", bad.code());
        String key = "key-" + UUID.randomUUID();
        PostView p = service.create(a.getId(), new CreatePostRequest("sil", List.of(media(a))), key);
        service.delete(a.getId(), p.id(), false);
        ApiException reused = assertThrows(ApiException.class, () -> service.replayByKey(a.getId(), key));
        assertEquals("IDEMPOTENCY_KEY_REUSED", reused.code());
    }
}
