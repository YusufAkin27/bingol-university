package edu.bingol.backend.post;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * A06#2: gece sayac onarimi id araligi parcalariyla calisir (tek dev UPDATE 8 sn statement_timeout'a takiliyordu);
 * beğenisi olmayan ama sayaci &gt; 0 olan satir da duzelir; user_follow_stats de onarilir; hata JobMonitor'a gorunur.
 */
@SpringBootTest
class PostCounterRepairJobTest {

    @Autowired JdbcTemplate jdbc;
    @Autowired UserRepository users;
    @Autowired PostRepository posts;

    private User user() {
        User u = new User();
        u.setEmail("cr" + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Kisi");
        u.setEmailVerified(true);
        return users.saveAndFlush(u);
    }

    private Post post(User author, int likeCount) {
        Post p = new Post();
        p.setAuthorId(author.getId());
        p.setBody("x");
        p.setLikeCount(likeCount);
        return posts.saveAndFlush(p);
    }

    private void like(Long postId, Long userId) {
        jdbc.update("INSERT INTO post_like (post_id, user_id, created_at) VALUES (?, ?, CURRENT_TIMESTAMP)", postId, userId);
    }

    private int likeCount(Post p) {
        return posts.findById(p.getId()).orElseThrow().getLikeCount();
    }

    @Test
    void repairsDriftedCountersAcrossManyChunks() {
        User a = user();
        User b = user();
        List<Post> ps = new ArrayList<>();
        for (int i = 0; i < 7; i++) {
            ps.add(post(a, 0));
        }
        like(ps.get(0).getId(), a.getId());
        like(ps.get(0).getId(), b.getId());
        like(ps.get(5).getId(), b.getId());
        // 3. gonderi: begenisi yok ama sayac 4 (hayalet); 6.: sayac dogru
        jdbc.update("UPDATE post SET like_count = 4 WHERE id = ?", ps.get(3).getId());
        jdbc.update("UPDATE post SET like_count = 1 WHERE id = ?", ps.get(5).getId());

        PostCounterRepairJob job = new PostCounterRepairJob(jdbc, mock(SchedulerLock.class), 2); // 2'lik parca
        job.repair();

        assertEquals(2, likeCount(ps.get(0)));
        assertEquals(0, likeCount(ps.get(3)), "begenisi olmayan ama sayaci > 0 olan satir sifirlanir");
        assertEquals(1, likeCount(ps.get(5)));
        assertEquals(0, likeCount(ps.get(6)));
    }

    @Test
    void repairsFollowStats() {
        User a = user();
        User b = user();
        jdbc.update("INSERT INTO user_follow (follower_id, followee_id, created_at) VALUES (?, ?, CURRENT_TIMESTAMP)",
                a.getId(), b.getId());
        jdbc.update("INSERT INTO user_follow_stats (user_id, follower_count, following_count) VALUES (?, 9, 9)", a.getId());
        jdbc.update("INSERT INTO user_follow_stats (user_id, follower_count, following_count) VALUES (?, 9, 9)", b.getId());

        new PostCounterRepairJob(jdbc, mock(SchedulerLock.class), 2).repair();

        assertEquals(0, jdbc.queryForObject("SELECT follower_count FROM user_follow_stats WHERE user_id = ?", Integer.class, a.getId()));
        assertEquals(1, jdbc.queryForObject("SELECT following_count FROM user_follow_stats WHERE user_id = ?", Integer.class, a.getId()));
        assertEquals(1, jdbc.queryForObject("SELECT follower_count FROM user_follow_stats WHERE user_id = ?", Integer.class, b.getId()));
        assertEquals(0, jdbc.queryForObject("SELECT following_count FROM user_follow_stats WHERE user_id = ?", Integer.class, b.getId()));
    }

    @Test
    void failedChunkIsNotSwallowed() {
        JdbcTemplate broken = mock(JdbcTemplate.class);
        when(broken.queryForList(any(String.class), any(Class.class))).thenReturn(List.of());
        when(broken.queryForObject(any(String.class), any(Class.class))).thenReturn(10L);
        when(broken.execute(any(ConnectionCallback.class))).thenThrow(new org.springframework.dao.QueryTimeoutException("57014"));
        PostCounterRepairJob job = new PostCounterRepairJob(broken, mock(SchedulerLock.class), 5);
        assertThrows(IllegalStateException.class, job::repair);
    }
}
