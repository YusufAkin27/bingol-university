package edu.bingol.backend.forum.notify;

import java.util.Collection;
import java.util.HashMap;
import java.util.Map;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Forum bildirim tercihleri (okuma + kismi guncelleme). Moderasyon bildirimi kapatilamaz. */
@Service
public class ForumNotificationPrefService {

    /** API goruntusu: {@code {all, topicComments, commentReplies, likes, followedTopics}}. */
    public record PrefsView(boolean all, boolean topicComments, boolean commentReplies, boolean likes,
                            boolean followedTopics) {
        static PrefsView of(ForumNotificationPref p) {
            return new PrefsView(p.isAllEnabled(), p.isTopicComments(), p.isCommentReplies(), p.isLikes(),
                    p.isFollowedTopics());
        }
    }

    /** Kismi guncelleme: null alan degismez. */
    public record PrefsUpdate(Boolean all, Boolean topicComments, Boolean commentReplies, Boolean likes,
                              Boolean followedTopics) {}

    private final ForumNotificationPrefRepository prefs;

    public ForumNotificationPrefService(ForumNotificationPrefRepository prefs) {
        this.prefs = prefs;
    }

    @Transactional(readOnly = true)
    public PrefsView get(Long userId) {
        return PrefsView.of(prefs.findById(userId).orElseGet(() -> ForumNotificationPref.defaults(userId)));
    }

    @Transactional
    public PrefsView update(Long userId, PrefsUpdate r) {
        ForumNotificationPref p = prefs.findById(userId).orElseGet(() -> ForumNotificationPref.defaults(userId));
        if (r.all() != null) p.setAllEnabled(r.all());
        if (r.topicComments() != null) p.setTopicComments(r.topicComments());
        if (r.commentReplies() != null) p.setCommentReplies(r.commentReplies());
        if (r.likes() != null) p.setLikes(r.likes());
        if (r.followedTopics() != null) p.setFollowedTopics(r.followedTopics());
        p.setModeration(true); // kapatilamaz
        p.setUpdatedAt(java.time.Instant.now());
        prefs.save(p);
        return PrefsView.of(p);
    }

    /** Toplu: satiri olmayanlar haritada yoktur (= hepsi acik). */
    @Transactional(readOnly = true)
    public Map<Long, ForumNotificationPref> byUser(Collection<Long> userIds) {
        Map<Long, ForumNotificationPref> out = new HashMap<>();
        if (userIds == null || userIds.isEmpty()) {
            return out;
        }
        prefs.findByUserIdIn(userIds).forEach(p -> out.put(p.getUserId(), p));
        return out;
    }
}
