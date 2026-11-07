package edu.bingol.backend.post;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.post.PostDtos.CreatePostRequest;
import edu.bingol.backend.post.PostDtos.PostView;
import edu.bingol.backend.post.comment.CommentDtos.CommentView;
import edu.bingol.backend.post.comment.CommentDtos.CreateCommentRequest;
import edu.bingol.backend.post.comment.PostCommentService;
import edu.bingol.backend.post.like.PostLikeService;
import edu.bingol.backend.post.media.PostMediaRepository;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

/** Gonderi ayarlari (V1670): begeni sayisini gizle + yorumlari kapat (olusturma, PATCH, sayac gizleme, 403 COMMENTS_DISABLED). */
@SpringBootTest
class PostSettingsTest {

    @Autowired PostService service;
    @Autowired PostCommentService comments;
    @Autowired PostLikeService likes;
    @Autowired PostViewAssembler assembler;
    @Autowired PostRepository posts;
    @Autowired PostMediaRepository mediaRepo;
    @Autowired UserRepository users;

    private User user(String name) {
        User u = new User();
        u.setEmail(name + "-" + UUID.randomUUID() + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName(name);
        u.setEmailVerified(true);
        return users.saveAndFlush(u);
    }

    private PostView create(User a, Boolean hide, Boolean noComments) {
        Long m = PostFixtures.media(mediaRepo, a.getId(), null, "IMAGE").getId();
        return service.create(a.getId(), new CreatePostRequest("ayar", List.of(m), null, hide, noComments));
    }

    private static String code(Runnable r) {
        return assertThrows(ApiException.class, r::run).code();
    }

    @Test
    void defaultsAreFalseAndOldRequestShapeStillWorks() {
        User a = user("a");
        Long m = PostFixtures.media(mediaRepo, a.getId(), null, "IMAGE").getId();
        PostView v = service.create(a.getId(), new CreatePostRequest("eski", List.of(m)));
        assertFalse(v.hideLikeCount());
        assertFalse(v.commentsDisabled());
        assertNotNull(v.likeCount());
    }

    @Test
    void createWithSettingsPersistsThem() {
        User a = user("a");
        PostView v = create(a, true, true);
        assertTrue(v.hideLikeCount());
        assertTrue(v.commentsDisabled());
        Post p = posts.findById(v.id()).orElseThrow();
        assertTrue(p.isHideLikeCount());
        assertTrue(p.isCommentsDisabled());
    }

    @Test
    void hiddenLikeCountIsVisibleOnlyToOwner() {
        User a = user("a");
        User b = user("b");
        PostView v = create(a, true, null);
        likes.like(b.getId(), v.id());

        PostView owner = service.get(a.getId(), v.id());
        assertEquals(1, owner.likeCount());
        PostView other = service.get(b.getId(), v.id());
        assertNull(other.likeCount(), "baskasina sayi sizmaz");
        assertTrue(other.likedByMe(), "kendi durumu gorunur");
        assertTrue(other.hideLikeCount());
        assertNull(assembler.assemble(null, posts.findById(v.id()).orElseThrow()).likeCount(), "anonim");
        assertNull(likes.like(b.getId(), v.id()).likeCount(), "PUT /like yaniti da sizdirmaz");
        assertNull(likes.unlike(b.getId(), v.id()).likeCount());
        assertEquals(0, likes.listLikers(v.id(), b.getId(), null, 10).total());
        assertEquals(0, posts.findById(v.id()).orElseThrow().getLikeCount()); // unlike sonrasi ic sayac gercek
    }

    @Test
    void patchSettingsOwnerOnlyAndPartial() {
        User a = user("a");
        User b = user("b");
        PostView v = create(a, null, null);
        assertEquals("POST_FORBIDDEN", code(() -> service.updateSettings(b.getId(), v.id(), true, true)));
        PostView u = service.updateSettings(a.getId(), v.id(), true, null);
        assertTrue(u.hideLikeCount());
        assertFalse(u.commentsDisabled(), "null alan degismez");
        PostView u2 = service.updateSettings(a.getId(), v.id(), null, true);
        assertTrue(u2.hideLikeCount());
        assertTrue(u2.commentsDisabled());
        PostView u3 = service.updateSettings(a.getId(), v.id(), false, false);
        assertFalse(u3.hideLikeCount());
        assertFalse(u3.commentsDisabled());
    }

    @Test
    void commentsDisabledBlocksNewCommentReplyAndCommentLikeButOwnerCanDelete() {
        User a = user("a");
        User b = user("b");
        PostView v = create(a, null, null);
        CommentView c = comments.create(b.getId(), v.id(), new CreateCommentRequest("once", null));
        service.updateSettings(a.getId(), v.id(), null, true);

        assertEquals("COMMENTS_DISABLED", code(() -> comments.create(b.getId(), v.id(), new CreateCommentRequest("x", null))));
        assertEquals("COMMENTS_DISABLED", code(() -> comments.create(b.getId(), v.id(), new CreateCommentRequest("x", c.id()))));
        assertEquals("COMMENTS_DISABLED", code(() -> comments.create(a.getId(), v.id(), new CreateCommentRequest("x", null))),
                "sahibi de kapali gonderiye yorum yazamaz");
        assertEquals("COMMENTS_DISABLED", code(() -> comments.like(a.getId(), c.id())));

        // mevcut yorumlar okunur, sayac ayni
        assertEquals(1, comments.list(b.getId(), v.id(), "new", null, 10).items().size());
        PostView after = service.get(b.getId(), v.id());
        assertTrue(after.commentsDisabled());
        assertEquals(1, after.commentCount());

        // sahibi baskasinin yorumunu siler (canDelete true), yazar silemez degil ama baskasi silemez
        assertTrue(comments.list(a.getId(), v.id(), "new", null, 10).items().get(0).canDelete());
        User x = user("x");
        assertEquals("COMMENT_FORBIDDEN", code(() -> comments.delete(x.getId(), c.id(), false)));
        comments.delete(a.getId(), c.id(), false);
        assertEquals(0, service.get(a.getId(), v.id()).commentCount());

        // yeniden acinca yorum yazilir
        service.updateSettings(a.getId(), v.id(), null, false);
        assertNotNull(comments.create(b.getId(), v.id(), new CreateCommentRequest("tekrar", null)));
    }
}
