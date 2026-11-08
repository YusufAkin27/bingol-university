package edu.bingol.backend.forum;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;

import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.forum.comment.ForumComment;
import edu.bingol.backend.forum.comment.ForumCommentRepository;
import edu.bingol.backend.forum.poll.ForumPoll;
import edu.bingol.backend.forum.poll.ForumPollOption;
import edu.bingol.backend.forum.poll.ForumPollOptionRepository;
import edu.bingol.backend.forum.poll.ForumPollRepository;
import edu.bingol.backend.forum.topic.ForumTopic;
import edu.bingol.backend.forum.topic.ForumTopicRepository;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

/** Forum sayac onarimi: sapmis satir duzelir, dogru satira ve like_boost'a dokunulmaz, bayrak kapaliyken zamanlayici islemez. */
@SpringBootTest
class ForumCounterRepairJobTest {

    @Autowired JdbcTemplate jdbc;
    @Autowired ForumTopicRepository topics;
    @Autowired ForumCommentRepository comments;
    @Autowired ForumPollRepository polls;
    @Autowired ForumPollOptionRepository options;

    private ForumTopic topic(int cc, int lc, int bc, int boost) {
        ForumTopic t = new ForumTopic();
        t.setUserId(1L);
        t.setCategoryId(1L);
        t.setTitle("t");
        t.setBody("b");
        t.setCommentCount(cc);
        t.setLikeCount(lc);
        t.setBookmarkCount(bc);
        t.setLikeBoost(boost);
        return topics.saveAndFlush(t);
    }

    private ForumComment comment(long topicId, Long parent, int likes, int replies, boolean live) {
        ForumComment c = new ForumComment();
        c.setTopicId(topicId);
        c.setUserId(1L);
        c.setParentCommentId(parent);
        c.setBody("c");
        c.setLikeCount(likes);
        c.setReplyCount(replies);
        if (!live) {
            c.setDeletedAt(Instant.now());
        }
        return comments.saveAndFlush(c);
    }

    private int q(String sql, Object... a) {
        return jdbc.queryForObject(sql, Integer.class, a);
    }

    @Test
    void repairsDriftOnlyWhereNeeded() {
        ForumTopic bad = topic(9, 9, 9, 77);
        ForumTopic good = topic(1, 1, 1, 5);
        ForumComment top = comment(bad.getId(), null, 4, 5, true);
        comment(bad.getId(), top.getId(), 0, 0, true);
        comment(bad.getId(), top.getId(), 0, 0, false); // yer tutucu: yorum sayisina girmez
        ForumComment ok = comment(good.getId(), null, 1, 0, true);
        jdbc.update("INSERT INTO forum_topic_like (topic_id, user_id, created_at) VALUES (?, 2, CURRENT_TIMESTAMP)", bad.getId());
        jdbc.update("INSERT INTO forum_topic_like (topic_id, user_id, created_at) VALUES (?, 2, CURRENT_TIMESTAMP)", good.getId());
        jdbc.update("INSERT INTO forum_bookmark (user_id, target_type, target_id, created_at) VALUES (2, 'TOPIC', ?, CURRENT_TIMESTAMP)", good.getId());
        jdbc.update("INSERT INTO forum_comment_like (comment_id, user_id, created_at) VALUES (?, 2, CURRENT_TIMESTAMP)", ok.getId());
        jdbc.update("INSERT INTO forum_comment_like (comment_id, user_id, created_at) VALUES (?, 2, CURRENT_TIMESTAMP)", top.getId());
        jdbc.update("INSERT INTO forum_comment_like (comment_id, user_id, created_at) VALUES (?, 3, CURRENT_TIMESTAMP)", top.getId());

        ForumPoll p = new ForumPoll();
        p.setTopicId(bad.getId());
        p = polls.saveAndFlush(p);
        ForumPollOption o1 = option(p.getId(), 0, 8);
        ForumPollOption o2 = option(p.getId(), 1, 1);
        jdbc.update("INSERT INTO forum_poll_vote (poll_id, user_id, option_id, created_at) VALUES (?, 2, ?, CURRENT_TIMESTAMP)", p.getId(), o2.getId());

        long goodVersionBefore = q("SELECT COUNT(*) FROM forum_topic WHERE id = ?", good.getId());
        new ForumCounterRepairJob(jdbc, mock(SchedulerLock.class), 2, true).repair();

        assertEquals(2, q("SELECT comment_count FROM forum_topic WHERE id = ?", bad.getId()));
        assertEquals(1, q("SELECT like_count FROM forum_topic WHERE id = ?", bad.getId()));
        assertEquals(0, q("SELECT bookmark_count FROM forum_topic WHERE id = ?", bad.getId()));
        assertEquals(77, q("SELECT like_boost FROM forum_topic WHERE id = ?", bad.getId()), "like_boost'a dokunulmaz");
        assertEquals(1, q("SELECT comment_count FROM forum_topic WHERE id = ?", good.getId()));
        assertEquals(5, q("SELECT like_boost FROM forum_topic WHERE id = ?", good.getId()));
        assertEquals(2, q("SELECT like_count FROM forum_comment WHERE id = ?", top.getId()));
        assertEquals(1, q("SELECT like_count FROM forum_comment WHERE id = ?", ok.getId()));
        assertEquals(1, q("SELECT reply_count FROM forum_comment WHERE id = ?", top.getId()), "bant disi 5 -> 1");
        assertEquals(0, q("SELECT vote_count FROM forum_poll_option WHERE id = ?", o1.getId()));
        assertEquals(1, q("SELECT vote_count FROM forum_poll_option WHERE id = ?", o2.getId()));
        assertEquals(1, goodVersionBefore);
    }

    @Test
    void replyCountInsideAmbiguousBandIsLeftAlone() {
        ForumTopic t = topic(1, 0, 0, 0);
        ForumComment top = comment(t.getId(), null, 0, 2, true); // 1 canli + 1 yer tutucu cocuk: 1..2 bandi
        comment(t.getId(), top.getId(), 0, 0, true);
        comment(t.getId(), top.getId(), 0, 0, false);
        new ForumCounterRepairJob(jdbc, mock(SchedulerLock.class), 5000, true).repair();
        assertEquals(2, q("SELECT reply_count FROM forum_comment WHERE id = ?", top.getId()));
    }

    @Test
    void disabledFlagDoesNothingOnSchedule() {
        SchedulerLock lock = mock(SchedulerLock.class);
        new ForumCounterRepairJob(jdbc, lock, 5000, false).scheduled();
        verifyNoInteractions(lock);
    }

    private ForumPollOption option(Long pollId, int pos, int votes) {
        ForumPollOption o = new ForumPollOption();
        o.setPollId(pollId);
        o.setText("o" + pos);
        o.setPosition(pos);
        o.setVoteCount(votes);
        return options.saveAndFlush(o);
    }
}
