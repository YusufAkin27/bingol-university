package edu.bingol.backend.post.social;

import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.post.PostDtos.MentionView;
import edu.bingol.backend.post.spi.PostExtrasLookup;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** PostView/CommentView sosyal ekleri: savedByMe (yalniz bakan), mentions, hashtags. Toplu, N+1'siz. */
@Service
public class PostExtrasService implements PostExtrasLookup {

    private final PostSaveRepository saves;
    private final PostMentionRepository mentions;
    private final PostHashtagRepository links;
    private final UserRepository users;
    private final BlockService blocks;

    public PostExtrasService(PostSaveRepository saves, PostMentionRepository mentions, PostHashtagRepository links,
                             UserRepository users, BlockService blocks) {
        this.saves = saves;
        this.mentions = mentions;
        this.links = links;
        this.users = users;
        this.blocks = blocks;
    }

    @Override
    @Transactional(readOnly = true)
    public Map<Long, Extras> postExtras(Long viewerId, Collection<Long> postIds) {
        if (postIds == null || postIds.isEmpty()) {
            return Map.of();
        }
        Set<Long> saved = new HashSet<>(saves.savedAmong(viewerId, postIds));
        Map<Long, List<MentionView>> m = mentionViews(viewerId, mentions.ofPosts(postIds).stream()
                .map(x -> new Pair(x.getPostId(), x.getUserId())).toList());
        Map<Long, List<String>> tags = new HashMap<>();
        for (Object[] row : links.displaysOf(postIds)) {
            tags.computeIfAbsent((Long) row[0], k -> new ArrayList<>()).add((String) row[1]);
        }
        Map<Long, Extras> out = new HashMap<>();
        for (Long id : postIds) {
            out.put(id, new Extras(saved.contains(id), m.getOrDefault(id, List.of()), tags.getOrDefault(id, List.of())));
        }
        return out;
    }

    @Override
    @Transactional(readOnly = true)
    public Map<Long, List<MentionView>> commentMentions(Long viewerId, Collection<Long> commentIds) {
        if (commentIds == null || commentIds.isEmpty()) {
            return Map.of();
        }
        return mentionViews(viewerId, mentions.ofComments(commentIds).stream()
                .map(x -> new Pair(x.getCommentId(), x.getUserId())).toList());
    }

    private record Pair(Long owner, Long userId) {}

    /** Etiketlenenler: bakanla engel iliskisi olmayan ve aktif kullanicilar. */
    private Map<Long, List<MentionView>> mentionViews(Long viewerId, List<Pair> pairs) {
        if (pairs.isEmpty()) {
            return Map.of();
        }
        Set<Long> hidden = blocks.hiddenFrom(viewerId);
        Map<Long, User> byId = new HashMap<>();
        users.findAllById(pairs.stream().map(Pair::userId).collect(java.util.stream.Collectors.toSet()))
                .forEach(u -> byId.put(u.getId(), u));
        Map<Long, List<MentionView>> out = new HashMap<>();
        for (Pair p : pairs) {
            User u = byId.get(p.userId());
            if (u == null || !u.isActive() || (hidden != null && hidden.contains(u.getId()))) {
                continue;
            }
            out.computeIfAbsent(p.owner(), k -> new ArrayList<>()).add(new MentionView(u.getId(), u.getDisplayName()));
        }
        return out;
    }
}
