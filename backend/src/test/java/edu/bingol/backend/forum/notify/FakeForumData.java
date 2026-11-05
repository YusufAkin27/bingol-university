package edu.bingol.backend.forum.notify;

import edu.bingol.backend.i18n.Lang;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.TreeSet;

/** Birim testleri icin bellek ici forum verisi + tekrar defteri (ForumNotifyReader + ForumNotifyLedger). */
class FakeForumData implements ForumNotifyReader, ForumNotifyLedger {

    final Map<Long, TopicInfo> topics = new HashMap<>();
    final Map<Long, CommentInfo> comments = new HashMap<>();
    final Map<Long, Map<Lang, String>> categories = new HashMap<>();
    final Map<String, Integer> aliases = new HashMap<>();
    final Set<String> topicOff = new HashSet<>();
    final Map<Long, Set<Long>> followers = new HashMap<>();
    final Set<String> mutes = new HashSet<>(); // "muter:muted"
    final Set<Long> topicsWithImage = new HashSet<>();
    final Set<String> seen = new HashSet<>();

    @Override
    public Optional<TopicInfo> topic(long topicId) {
        return Optional.ofNullable(topics.get(topicId));
    }

    @Override
    public Optional<CommentInfo> comment(long commentId) {
        return Optional.ofNullable(comments.get(commentId));
    }

    @Override
    public String categoryName(long categoryId, Lang lang) {
        Map<Lang, String> m = categories.get(categoryId);
        return m == null ? null : m.getOrDefault(lang, m.get(Lang.TR));
    }

    @Override
    public Integer anonAlias(long topicId, long userId) {
        return aliases.get(topicId + ":" + userId);
    }

    @Override
    public boolean topicNotificationsOff(long topicId, long userId) {
        return topicOff.contains(topicId + ":" + userId);
    }

    @Override
    public List<Long> notifyingFollowers(long topicId, int limit) {
        List<Long> out = new ArrayList<>();
        for (Long id : new TreeSet<>(followers.getOrDefault(topicId, Set.of()))) {
            if (out.size() < limit) {
                out.add(id);
            }
        }
        return out;
    }

    @Override
    public boolean muted(long muterId, long mutedId) {
        return mutes.contains(muterId + ":" + mutedId);
    }

    @Override
    public Set<Long> mutersAmong(Collection<Long> muterIds, long mutedId) {
        Set<Long> out = new HashSet<>();
        for (Long m : muterIds) {
            if (muted(m, mutedId)) {
                out.add(m);
            }
        }
        return out;
    }

    @Override
    public boolean topicHasImage(long topicId) {
        return topicsWithImage.contains(topicId);
    }

    @Override
    public boolean firstTime(String kind, long targetId, long actorId, long recipientId) {
        return seen.add(kind + ":" + targetId + ":" + actorId + ":" + recipientId);
    }
}
