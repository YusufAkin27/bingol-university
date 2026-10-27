package edu.bingol.backend.post.comment;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.reset;
import static org.mockito.Mockito.verify;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.FieldApiException;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.post.Post;
import edu.bingol.backend.post.PostRepository;
import edu.bingol.backend.post.comment.CommentDtos.CommentPage;
import edu.bingol.backend.post.comment.CommentDtos.CommentView;
import edu.bingol.backend.post.comment.CommentDtos.ReplyPage;
import edu.bingol.backend.post.notify.PostNotifier;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

/** Yorum/yanit kurallari: derinlik, sayaclar, silinmis yorum, siralama/imlec, engel, kufur, yetki, bildirim. */
@SpringBootTest
class PostCommentServiceTest {

    @Autowired
    PostCommentService service;
    @Autowired
    PostRepository posts;
    @Autowired
    PostCommentRepository comments;
    @Autowired
    UserRepository users;
    @Autowired
    BlockService blocks;
    @Autowired
    JdbcTemplate jdbc;

    @MockitoBean
    ContentGuard guard;
    @MockitoBean
    PostNotifier notifier;

    User owner;
    User a;
    User b;
    Post post;

    @BeforeEach
    void setUp() {
        reset(guard, notifier);
        owner = user("owner");
        a = user("a");
        b = user("b");
        post = newPost(owner);
    }

    User user(String prefix) {
        User u = new User();
        u.setEmail(prefix + "-" + UUID.randomUUID() + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName(prefix);
        u.setEmailVerified(true);
        return users.save(u);
    }

    Post newPost(User author) {
        Post p = new Post();
        p.setAuthorId(author.getId());
        p.setBody("gonderi");
        return posts.save(p);
    }

    int commentCount(Post p) {
        return jdbc.queryForObject("SELECT comment_count FROM post WHERE id = ?", Integer.class, p.getId());
    }

    int replyCount(Long id) {
        return jdbc.queryForObject("SELECT reply_count FROM post_comment WHERE id = ?", Integer.class, id);
    }

    CommentView add(User u, String text, Long parent) {
        return service.create(u.getId(), post.getId(), text, parent);
    }

    CommentPage list(User viewer, String sort, String cursor, int size) {
        return service.list(viewer.getId(), post.getId(), sort, cursor, size, false);
    }

    // ------------------------------------------------------------ derinlik

    @Test
    void depthRulesAndSiblingFallback() {
        CommentView c0 = add(a, "kok", null);
        assertEquals(0, c0.depth());
        assertEquals(c0.id(), c0.rootId());
        assertNull(c0.parentId());
        CommentView c1 = add(b, "yanit1", c0.id());
        CommentView c2 = add(a, "yanit2", c1.id());
        CommentView c3 = add(b, "yanit3", c2.id());
        assertEquals(1, c1.depth());
        assertEquals(2, c2.depth());
        assertEquals(3, c3.depth());
        assertEquals(c0.id(), c3.rootId());
        assertEquals(c2.id(), c3.parentId());

        // 4. seviye istendi: c3'un kardesi (parent = c2), replyToUser = c3 yazari
        CommentView c4 = add(a, "derin", c3.id());
        assertEquals(3, c4.depth());
        assertEquals(c2.id(), c4.parentId());
        assertEquals(c0.id(), c4.rootId());
        assertEquals(b.getId(), c4.replyToUser().id());
        assertEquals(2, replyCount(c2.id()));
        assertEquals(0, replyCount(c3.id()));
    }

    @Test
    void replyToUserIsParentAuthor() {
        CommentView c0 = add(a, "kok", null);
        CommentView c1 = add(b, "yanit", c0.id());
        assertEquals(a.getId(), c1.replyToUser().id());
        assertNull(c0.replyToUser());
    }

    @Test
    void parentMustBelongToSamePost() {
        CommentView c0 = add(a, "kok", null);
        Post other = newPost(owner);
        ApiException e = assertThrows(ApiException.class, () -> service.create(b.getId(), other.getId(), "x", c0.id()));
        assertEquals("COMMENT_PARENT_INVALID", e.code());
        e = assertThrows(ApiException.class, () -> add(b, "x", 999999L));
        assertEquals("COMMENT_PARENT_INVALID", e.code());
    }

    // ------------------------------------------------------------ dogrulama

    @Test
    void emptyAndTooLongRejected() {
        assertEquals("COMMENT_EMPTY", assertThrows(ApiException.class, () -> add(a, "   ", null)).code());
        assertEquals("COMMENT_EMPTY", assertThrows(ApiException.class, () -> add(a, null, null)).code());
        ApiException e = assertThrows(ApiException.class, () -> add(a, "x".repeat(1001), null));
        assertEquals("COMMENT_TOO_LONG", e.code());
        assertEquals(HttpStatus.BAD_REQUEST, e.status());
        assertEquals(0, commentCount(post));
        assertNotNull(add(a, "x".repeat(1000), null));
    }

    @Test
    void profanityRejectedAndNothingSaved() {
        doThrow(new FieldApiException(HttpStatus.UNPROCESSABLE_ENTITY, "CONTENT_PROFANITY", "x", "text"))
                .when(guard).assertClean(any(ContentGuard.Entity.class), eq("text"), anyLong(), anyString());
        FieldApiException e = assertThrows(FieldApiException.class, () -> add(a, "kotu", null));
        assertEquals(422, e.status().value());
        assertEquals(0, commentCount(post));
        assertTrue(comments.findAll().stream().noneMatch(c -> c.getPostId().equals(post.getId())));
    }

    // ------------------------------------------------------------ sayaclar ve silme

    @Test
    void countersOnAddAndDeleteLeaf() {
        CommentView c0 = add(a, "kok", null);
        CommentView r1 = add(b, "y1", c0.id());
        add(a, "y2", c0.id());
        assertEquals(3, commentCount(post));
        assertEquals(2, replyCount(c0.id()));

        service.delete(b.getId(), r1.id(), false);
        assertEquals(2, commentCount(post));
        assertEquals(1, replyCount(c0.id()));
        // ikinci silme: yok sayilir
        assertEquals("COMMENT_NOT_FOUND",
                assertThrows(ApiException.class, () -> service.delete(b.getId(), r1.id(), false)).code());
        assertEquals(2, commentCount(post));
    }

    @Test
    void deletedWithRepliesBecomesTombstoneAndVanishesWhenLastReplyGoes() {
        CommentView c0 = add(a, "kok", null);
        CommentView r1 = add(b, "y1", c0.id());

        service.delete(a.getId(), c0.id(), false);
        assertEquals(1, commentCount(post)); // yalniz y1 kaldi
        assertEquals(1, replyCount(c0.id())); // kok'un yanit sayisi korunur
        CommentPage page = list(b, "new", null, 20);
        assertEquals(1, page.items().size());
        CommentView t = page.items().get(0);
        assertTrue(t.deleted());
        assertNull(t.text());
        assertNull(t.author());
        assertFalse(t.canEdit());
        assertFalse(t.canDelete());
        assertEquals(1, t.previewReplies().size());
        assertEquals(r1.id(), t.previewReplies().get(0).id());
        // yanitlar hala okunur
        assertEquals(1, service.replies(b.getId(), c0.id(), null, 20, false).items().size());

        service.delete(b.getId(), r1.id(), false);
        assertEquals(0, commentCount(post));
        assertEquals(0, replyCount(c0.id()));
        assertTrue(list(b, "new", null, 20).items().isEmpty());
    }

    @Test
    void tombstoneChainCollapsesUpward() {
        CommentView c0 = add(a, "kok", null);
        CommentView c1 = add(b, "y1", c0.id());
        CommentView c2 = add(a, "y2", c1.id());
        service.delete(b.getId(), c1.id(), false); // c1 yanitli -> silindi kaydi
        service.delete(a.getId(), c0.id(), false); // c0 de silindi kaydi
        assertEquals(1, commentCount(post));
        service.delete(a.getId(), c2.id(), false); // zincir cozulur
        assertEquals(0, commentCount(post));
        assertEquals(0, replyCount(c1.id()));
        assertEquals(0, replyCount(c0.id()));
        assertTrue(list(a, "new", null, 20).items().isEmpty());
    }

    @Test
    void deleteAuthorization() {
        CommentView c0 = add(a, "kok", null);
        ApiException e = assertThrows(ApiException.class, () -> service.delete(b.getId(), c0.id(), false));
        assertEquals("COMMENT_FORBIDDEN", e.code());
        assertEquals(403, e.status().value());
        service.delete(owner.getId(), c0.id(), false); // gonderi sahibi
        assertEquals(0, commentCount(post));

        CommentView c1 = add(a, "kok2", null);
        service.delete(b.getId(), c1.id(), true); // yonetici
        assertEquals(0, commentCount(post));
    }

    @Test
    void updateOnlyByAuthorAndSetsEditedAt() {
        CommentView c0 = add(a, "kok", null);
        assertNull(c0.editedAt());
        assertEquals("COMMENT_FORBIDDEN",
                assertThrows(ApiException.class, () -> service.update(b.getId(), c0.id(), "x", false)).code());
        CommentView u = service.update(a.getId(), c0.id(), "yeni", false);
        assertEquals("yeni", u.text());
        assertNotNull(u.editedAt());
        assertTrue(u.mine());
        assertTrue(u.canEdit());
        service.delete(a.getId(), c0.id(), false);
        assertEquals("COMMENT_NOT_FOUND",
                assertThrows(ApiException.class, () -> service.update(a.getId(), c0.id(), "x", false)).code());
    }

    @Test
    void flagsForViewers() {
        CommentView c0 = add(a, "kok", null);
        CommentView seenByOwner = list(owner, "new", null, 5).items().get(0);
        assertFalse(seenByOwner.mine());
        assertFalse(seenByOwner.canEdit());
        assertTrue(seenByOwner.canDelete()); // gonderi sahibi
        CommentView seenByB = list(b, "new", null, 5).items().get(0);
        assertFalse(seenByB.canDelete());
        assertEquals(c0.id(), seenByB.id());
        assertEquals(1, list(b, "new", null, 5).total());
    }

    @Test
    void deletedPostHidesComments() {
        add(a, "kok", null);
        post.setDeletedAt(Instant.now());
        posts.save(post);
        assertEquals("POST_NOT_FOUND", assertThrows(ApiException.class, () -> list(b, "new", null, 5)).code());
        assertEquals("POST_NOT_FOUND", assertThrows(ApiException.class, () -> add(b, "x", null)).code());
    }

    // ------------------------------------------------------------ listeleme

    @Test
    void newSortPagesWithCursor() {
        List<Long> ids = new ArrayList<>();
        for (int i = 0; i < 5; i++) {
            ids.add(add(a, "c" + i, null).id());
        }
        List<Long> seen = new ArrayList<>();
        String cursor = null;
        int pages = 0;
        do {
            CommentPage p = list(b, "new", cursor, 2);
            p.items().forEach(v -> seen.add(v.id()));
            cursor = p.nextCursor();
            pages++;
        } while (cursor != null && pages < 10);
        assertEquals(3, pages);
        List<Long> expected = new ArrayList<>(ids);
        java.util.Collections.reverse(expected);
        assertEquals(expected, seen); // yeniden eskiye, tekrarsiz
    }

    @Test
    void badCursorRejected() {
        assertEquals("POST_CURSOR_INVALID",
                assertThrows(ApiException.class, () -> list(b, "new", "bozuk", 5)).code());
        assertEquals("POST_CURSOR_INVALID",
                assertThrows(ApiException.class, () -> list(b, "top", "n|2020-01-01T00:00:00Z|1", 5)).code());
    }

    @Test
    void topSortOrdersByReplyCountThenRecencyAndPages() {
        CommentView quiet = add(a, "sessiz", null);
        CommentView busy = add(a, "hareketli", null);
        CommentView mid = add(a, "orta", null);
        add(b, "y", busy.id());
        add(b, "y", busy.id());
        add(b, "y", mid.id());
        CommentView newest = add(a, "yeni", null);

        List<Long> seen = new ArrayList<>();
        String cursor = null;
        int pages = 0;
        do {
            CommentPage p = list(b, "top", cursor, 1);
            p.items().forEach(v -> seen.add(v.id()));
            cursor = p.nextCursor();
            pages++;
        } while (cursor != null && pages < 10);
        assertEquals(List.of(busy.id(), mid.id(), newest.id(), quiet.id()), seen);
    }

    @Test
    void previewRepliesAreOldestTwoAndRepliesPageAscending() {
        CommentView c0 = add(a, "kok", null);
        CommentView other = add(a, "kok2", null);
        CommentView r1 = add(b, "y1", c0.id());
        CommentView r2 = add(a, "y2", c0.id());
        CommentView r3 = add(b, "y3", c0.id());
        add(b, "z1", other.id());

        CommentPage p = list(owner, "top", null, 10);
        CommentView root = p.items().stream().filter(v -> v.id().equals(c0.id())).findFirst().orElseThrow();
        assertEquals(3, root.replyCount());
        assertEquals(List.of(r1.id(), r2.id()), root.previewReplies().stream().map(CommentView::id).toList());
        CommentView root2 = p.items().stream().filter(v -> v.id().equals(other.id())).findFirst().orElseThrow();
        assertEquals(1, root2.previewReplies().size());

        ReplyPage first = service.replies(owner.getId(), c0.id(), null, 2, false);
        assertEquals(List.of(r1.id(), r2.id()), first.items().stream().map(CommentView::id).toList());
        assertNotNull(first.nextCursor());
        ReplyPage second = service.replies(owner.getId(), c0.id(), first.nextCursor(), 2, false);
        assertEquals(List.of(r3.id()), second.items().stream().map(CommentView::id).toList());
        assertNull(second.nextCursor());
        assertNull(first.items().get(0).previewReplies());
    }

    @Test
    void blockedUsersAreHiddenBothWays() {
        add(a, "a-yorumu", null);
        CommentView bc = add(b, "b-yorumu", null);
        blocks.block(a.getId(), b.getId());
        List<Long> forA = list(a, "new", null, 20).items().stream().map(CommentView::id).toList();
        List<Long> forB = list(b, "new", null, 20).items().stream().map(v -> v.author().id()).toList();
        assertEquals(1, forA.size());
        assertFalse(forA.contains(bc.id()));
        assertEquals(List.of(b.getId()), forB); // B de A'nin yorumunu gormez
        // engel varken yanit da yazilamaz
        assertEquals("COMMENT_PARENT_INVALID",
                assertThrows(ApiException.class, () -> add(a, "x", bc.id())).code());
    }

    @Test
    void blockedPostAuthorMakesPostInvisible() {
        blocks.block(a.getId(), owner.getId());
        assertEquals("POST_NOT_FOUND", assertThrows(ApiException.class, () -> add(a, "x", null)).code());
    }

    // ------------------------------------------------------------ bildirim

    @Test
    void notificationsFireForCommentAndReply() {
        CommentView c0 = add(a, "kok", null);
        verify(notifier).onComment(a.getId(), post.getId(), owner.getId(), c0.id());
        CommentView r = add(b, "yanit", c0.id());
        verify(notifier).onReply(b.getId(), post.getId(), r.id(), a.getId(), a.getId());
    }

    @Test
    void notifierFailureDoesNotBreakComment() {
        doThrow(new RuntimeException("boom")).when(notifier).onComment(anyLong(), anyLong(), anyLong(), anyLong());
        CommentView c0 = add(a, "kok", null);
        assertNotNull(c0.id());
        assertEquals(1, commentCount(post));
    }

    @Test
    void noNotificationWhenRejected() {
        assertThrows(ApiException.class, () -> add(a, " ", null));
        verify(notifier, never()).onComment(anyLong(), anyLong(), anyLong(), anyLong());
    }

    // ------------------------------------------------------------ hesap silme

    @Test
    void purgeUserDeletesLeavesAndTombstonesParents() {
        CommentView mine0 = add(a, "benim kokum", null);
        CommentView reply = add(b, "baskasinin yaniti", mine0.id());
        CommentView mineLeaf = add(a, "yaprak", null);
        CommentView mineUnderOther = add(a, "baskasinin altinda", reply.id());
        assertEquals(4, commentCount(post));

        int n = service.purgeUser(a.getId());
        assertEquals(3, n);
        assertEquals(1, commentCount(post)); // yalniz b'nin yaniti
        CommentPage p = list(b, "new", null, 20);
        assertEquals(1, p.items().size()); // kok "silindi" kaydi (yanitli); yaprak yok
        assertTrue(p.items().get(0).deleted());
        assertEquals(mine0.id(), p.items().get(0).id());
        assertEquals(0, replyCount(reply.id()));
        assertNotNull(mineLeaf);
        assertNotNull(mineUnderOther);
    }
}
