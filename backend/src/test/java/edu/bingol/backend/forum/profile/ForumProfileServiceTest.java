package edu.bingol.backend.forum.profile;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.forum.ForumTestDb;
import edu.bingol.backend.forum.profile.ForumProfileService.ProfilePage;
import edu.bingol.backend.forum.profile.ForumProfileService.SavedItem;
import edu.bingol.backend.forum.profile.ForumProfileService.Summary;
import edu.bingol.backend.forum.topic.dto.TopicSummary;
import edu.bingol.backend.forum.topic.spi.ForumMuteLookup;
import edu.bingol.backend.forum.topic.spi.ForumTopicSummaries;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.post.follow.PrivateAccountGate;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.jdbc.core.JdbcTemplate;

/** Profil kapilari ve anonimlik: baskasinin profili bos/kilitli/anonimsiz; kendi profilim anonim dahil. */
class ForumProfileServiceTest {

    private JdbcTemplate jdbc;
    private ForumProfileService service;
    private final UserRepository users = mock(UserRepository.class);
    private final BlockService blocks = mock(BlockService.class);
    private final PrivateAccountGate gate = mock(PrivateAccountGate.class);
    private final ForumMuteLookup muteLookup = mock(ForumMuteLookup.class);
    private final Set<Long> invisibleTopics = new HashSet<>();
    private final Map<Long, Object> commentViews = new HashMap<>();

    private static TopicSummary summary(long id) {
        return new TopicSummary(id, "t" + id, "", null, null, null, null, 0, 0, false, false, false, null, 0, false,
                false, false, false, false, "ACTIVE");
    }

    @SuppressWarnings("unchecked")
    @BeforeEach
    void setUp() {
        jdbc = ForumTestDb.create();
        ForumTopicSummaries summaries = (ids, viewer) -> ids.stream().filter(i -> !invisibleTopics.contains(i))
                .map(ForumProfileServiceTest::summary).toList();
        ForumProfileComments comments = (ids, viewer) -> {
            Map<Long, Object> out = new HashMap<>();
            ids.forEach(i -> {
                if (commentViews.containsKey(i)) {
                    out.put(i, commentViews.get(i));
                }
            });
            return out;
        };
        ObjectProvider<ForumTopicSummaries> sp = mock(ObjectProvider.class);
        when(sp.getObject()).thenReturn(summaries);
        ObjectProvider<ForumProfileComments> cp = mock(ObjectProvider.class);
        when(cp.getIfAvailable()).thenReturn(comments);
        ObjectProvider<ForumMuteLookup> mp = mock(ObjectProvider.class);
        when(mp.getIfAvailable()).thenReturn(muteLookup);
        service = new ForumProfileService(new ForumProfileRepository(jdbc), sp, cp, mp, blocks, gate, users,
                tools.jackson.databind.json.JsonMapper.builder().build());

        when(muteLookup.mutedBy(anyLong())).thenReturn(Set.of());
        when(gate.canSeeContent(anyLong(), anyLong())).thenReturn(true);
        when(blocks.isBlocked(anyLong(), anyLong())).thenReturn(false);
        user(1, UserStatus.ACTIVE); // sahip
        user(2, UserStatus.ACTIVE); // bakan

        ForumTestDb.topic(jdbc, 10, 1, false, "Acik", "x", "ACTIVE", false, "2026-11-01 10:00:00");
        ForumTestDb.topic(jdbc, 11, 1, true, "Gizli", "x", "ACTIVE", false, "2026-11-01 11:00:00");
        ForumTestDb.comment(jdbc, 30, 10, 1, false, "adli yorum", "ACTIVE", false, "2026-11-02 10:00:00");
        ForumTestDb.comment(jdbc, 31, 10, 1, true, "anonim yorum", "ACTIVE", false, "2026-11-02 11:00:00");
        commentViews.put(30L, Map.of("id", 30));
        commentViews.put(31L, Map.of("id", 31));
    }

    private void user(long id, UserStatus status) {
        User u = new User();
        u.setId(id);
        u.setStatus(status);
        when(users.findById(id)).thenReturn(Optional.of(u));
    }

    private static List<Long> topicIds(ProfilePage<TopicSummary> p) {
        return p.items().stream().map(TopicSummary::id).toList();
    }

    @Test
    void myProfileIncludesAnonymousContent() {
        assertEquals(List.of(11L, 10L), topicIds(service.myTopics(1L, null, null)));
        List<Map<String, Object>> mine = service.myComments(1L, null, null).items();
        assertEquals(2, mine.size());
        assertEquals("Acik", mine.get(0).get("topicTitle"));
        assertEquals(10L, ((Number) mine.get(0).get("topicId")).longValue());
    }

    @Test
    void othersSeeOnlyNonAnonymousContent() {
        assertEquals(List.of(10L), topicIds(service.userTopics(2L, 1L, null, null)));
        List<Map<String, Object>> theirs = service.userComments(2L, 1L, null, null).items();
        assertEquals(1, theirs.size());
        assertEquals(30, ((Number) theirs.get(0).get("id")).intValue()); // CommentView alanlari DUZ
        Summary s = service.userSummary(2L, 1L);
        assertEquals(1, s.topicCount());
        assertEquals(1, s.commentCount());
        assertNull(s.locked());
    }

    @Test
    void blockedMutedInactiveAndUnknownOwnersLookEmptyNotMissing() {
        when(blocks.isBlocked(2L, 1L)).thenReturn(true);
        assertTrue(service.userTopics(2L, 1L, null, null).items().isEmpty());
        assertNull(service.userTopics(2L, 1L, null, null).locked());
        assertEquals(0, service.userSummary(2L, 1L).topicCount());
        when(blocks.isBlocked(2L, 1L)).thenReturn(false);

        when(muteLookup.mutedBy(2L)).thenReturn(Set.of(1L));
        assertTrue(service.userTopics(2L, 1L, null, null).items().isEmpty());
        when(muteLookup.mutedBy(2L)).thenReturn(Set.of());

        user(1, UserStatus.SUSPENDED);
        assertTrue(service.userComments(2L, 1L, null, null).items().isEmpty());
        assertTrue(service.userTopics(2L, 999L, null, null).items().isEmpty());
    }

    @Test
    void privateAccountIsLockedForNonFollowers() {
        when(gate.canSeeContent(2L, 1L)).thenReturn(false);
        ProfilePage<TopicSummary> p = service.userTopics(2L, 1L, null, null);
        assertTrue(p.items().isEmpty());
        assertEquals(Boolean.TRUE, p.locked());
        assertEquals(Boolean.TRUE, service.userComments(2L, 1L, null, null).locked());
        Summary s = service.userSummary(2L, 1L);
        assertEquals(0, s.topicCount());
        assertEquals(Boolean.TRUE, s.locked());
        // kendi profilim kapidan etkilenmez
        assertEquals(2, service.myTopics(1L, null, null).items().size());
    }

    @Test
    void invisibleTopicsAreDroppedByTheSummariesSpiAndPagingStillAdvances() {
        invisibleTopics.add(11L);
        ProfilePage<TopicSummary> p = service.myTopics(1L, null, 1);
        assertTrue(p.items().isEmpty()); // 11 gorunmez
        assertFalse(p.nextCursor() == null); // ama imlec ilerler: ikinci sayfa 10'u getirir
        assertEquals(List.of(10L), topicIds(service.myTopics(1L, p.nextCursor(), 1)));
    }

    @Test
    void savedMixesTopicsAndCommentsAndDropsInvisibleOnes() {
        jdbc.update("INSERT INTO forum_bookmark (user_id, target_type, target_id, created_at) VALUES "
                + "(2, 'TOPIC', 10, TIMESTAMP '2026-11-04 10:00:00'), "
                + "(2, 'COMMENT', 30, TIMESTAMP '2026-11-04 11:00:00'), "
                + "(2, 'COMMENT', 31, TIMESTAMP '2026-11-04 12:00:00'), "
                + "(2, 'TOPIC', 11, TIMESTAMP '2026-11-04 13:00:00')");
        invisibleTopics.add(11L);
        commentViews.remove(31L); // yorum gorunmez
        // kaydedilen yorumun KONUSU gorunmezse (engel/sessize alma) yorum da dusulur
        jdbc.update("INSERT INTO forum_bookmark (user_id, target_type, target_id, created_at) VALUES "
                + "(2, 'COMMENT', 32, TIMESTAMP '2026-11-04 14:00:00')");
        ForumTestDb.topic(jdbc, 12, 5, false, "Baskasi", "x", "ACTIVE", false, "2026-11-01 12:00:00");
        ForumTestDb.comment(jdbc, 32, 12, 5, false, "baska konu yorumu", "ACTIVE", false, "2026-11-02 12:00:00");
        commentViews.put(32L, Map.of("id", 32));
        invisibleTopics.add(12L);
        List<SavedItem> items = service.saved(2L, null, null).items();
        assertEquals(2, items.size());
        assertEquals("COMMENT", items.get(0).type());
        assertEquals(10L, items.get(0).topic().id()); // yorumun bagli konusunun karti
        assertEquals(30, ((Number) items.get(0).comment().get("id")).intValue());
        assertEquals("Acik", items.get(0).comment().get("topicTitle"));
        assertEquals("TOPIC", items.get(1).type());
        assertNull(items.get(1).comment());
        assertEquals(10L, items.get(1).topic().id());
        assertTrue(service.saved(9L, null, null).items().isEmpty());
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM forum_bookmark WHERE user_id = 9", Integer.class));
    }

    @Test
    void followingListsOnlyFollowedVisibleTopics() {
        jdbc.update("INSERT INTO forum_topic_follow (topic_id, user_id, notify, follow, created_at) VALUES "
                + "(10, 2, TRUE, TRUE, TIMESTAMP '2026-11-04 10:00:00'), (11, 2, FALSE, FALSE, TIMESTAMP '2026-11-04 11:00:00')");
        assertEquals(List.of(10L), topicIds(service.following(2L, null, null)));
    }

    @Test
    void sizeIsClamped() {
        assertEquals(1, service.myTopics(1L, null, 1).items().size());
        assertTrue(ForumProfileService.clamp(1000) <= ForumProfileService.MAX_SIZE);
    }
}
