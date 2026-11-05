package edu.bingol.backend.forum.notify;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.forum.notify.ForumNotificationPrefService.PrefsUpdate;
import edu.bingol.backend.forum.notify.ForumNotificationPrefService.PrefsView;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class ForumNotificationPrefServiceTest {

    private final ForumNotificationPrefRepository repo = mock(ForumNotificationPrefRepository.class);
    private final ForumNotificationPrefService service = new ForumNotificationPrefService(repo);

    @Test
    void defaultsAreAllOnWhenNoRow() {
        when(repo.findById(7L)).thenReturn(Optional.empty());
        PrefsView v = service.get(7L);
        assertEquals(new PrefsView(true, true, true, true, true), v);
    }

    @Test
    void partialUpdateOnlyTouchesGivenFieldsAndModerationStaysOn() {
        ForumNotificationPref p = ForumNotificationPref.defaults(7L);
        p.setModeration(false); // bozuk veri: yine de kapatilamaz
        when(repo.findById(7L)).thenReturn(Optional.of(p));
        PrefsView v = service.update(7L, new PrefsUpdate(null, false, null, false, null));
        assertEquals(new PrefsView(true, false, true, false, true), v);
        ArgumentCaptor<ForumNotificationPref> saved = ArgumentCaptor.forClass(ForumNotificationPref.class);
        verify(repo).save(saved.capture());
        assertTrue(saved.getValue().isModeration());
    }

    @Test
    void allOffSilencesEveryKindExceptModeration() {
        ForumNotificationPref p = ForumNotificationPref.defaults(7L);
        p.setAllEnabled(false);
        for (ForumNotifyKind k : ForumNotifyKind.values()) {
            assertEquals(k == ForumNotifyKind.FORUM_MODERATION, k.allowed(p), k.name());
        }
        // satir yok: hepsi acik
        for (ForumNotifyKind k : ForumNotifyKind.values()) {
            assertTrue(k.allowed(null));
        }
    }

    @Test
    void eachKindIsGovernedByItsOwnToggle() {
        ForumNotificationPref p = ForumNotificationPref.defaults(7L);
        p.setTopicComments(false);
        assertFalse(ForumNotifyKind.FORUM_TOPIC_COMMENT.allowed(p));
        assertTrue(ForumNotifyKind.FORUM_COMMENT_REPLY.allowed(p));
        p.setCommentReplies(false);
        assertFalse(ForumNotifyKind.FORUM_COMMENT_REPLY.allowed(p));
        p.setLikes(false);
        assertFalse(ForumNotifyKind.FORUM_TOPIC_LIKE.allowed(p));
        assertFalse(ForumNotifyKind.FORUM_COMMENT_LIKE.allowed(p));
        assertTrue(ForumNotifyKind.FORUM_FOLLOWED_TOPIC_COMMENT.allowed(p));
        p.setFollowedTopics(false);
        assertFalse(ForumNotifyKind.FORUM_FOLLOWED_TOPIC_COMMENT.allowed(p));
        assertTrue(ForumNotifyKind.FORUM_MODERATION.allowed(p));
    }
}
