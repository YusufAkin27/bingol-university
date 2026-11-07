package edu.bingol.backend.post;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.post.PostDtos.AuthorView;
import edu.bingol.backend.post.PostDtos.MediaView;
import edu.bingol.backend.post.PostDtos.PostView;
import edu.bingol.backend.post.spi.PostSaveLookup;
import edu.bingol.backend.post.PostDtos.VideoView;
import edu.bingol.backend.post.popularity.UserPopularityService;
import edu.bingol.backend.post.spi.PostLikeLookup;
import edu.bingol.backend.post.spi.PostMediaLookup;
import edu.bingol.backend.profile.dto.ProfileDtos.PublicProfile;
import edu.bingol.backend.profile.privacy.PublicProfileMapper;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Component;

/** Gönderileri toplu (N+1'siz) PostView'a çevirir: yazar profili (gizlilik+engel), medya, beğeni durumu. */
@Component
public class PostViewAssembler {

    private final UserRepository users;
    private final PublicProfileMapper profiles;
    private final ObjectProvider<PostMediaLookup> mediaLookups;
    private final ObjectProvider<PostLikeLookup> likeLookups;

    public PostViewAssembler(UserRepository users, PublicProfileMapper profiles,
                             ObjectProvider<PostMediaLookup> mediaLookups, ObjectProvider<PostLikeLookup> likeLookups) {
        this.users = users;
        this.profiles = profiles;
        this.mediaLookups = mediaLookups;
        this.likeLookups = likeLookups;
    }

    /** Bakanin kaydettikleri (KS-BE2; setter: kurucu imzasi degismesin, yoksa savedByMe false). */
    private ObjectProvider<PostSaveLookup> saveLookups;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setSaveLookups(ObjectProvider<PostSaveLookup> saveLookups) {
        this.saveLookups = saveLookups;
    }

    /** Etiketler (V1310; setter: kurucu imzasi degismesin, yoksa mentions bos liste). */
    private edu.bingol.backend.post.mention.PostMentionService mentionService;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setMentionService(edu.bingol.backend.post.mention.PostMentionService mentionService) {
        this.mentionService = mentionService;
    }

    /** Gosterim puani ve yazar populerligi (setter: kurucu imzasi degismesin; yoksa alanlar null). */
    private PostRankProperties rankProps;
    private UserPopularityService popularity;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setRankProps(PostRankProperties rankProps) {
        this.rankProps = rankProps;
    }

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setPopularity(UserPopularityService popularity) {
        this.popularity = popularity;
    }

    public List<PostView> assemble(Long viewerId, List<Post> posts) {
        if (posts.isEmpty()) {
            return List.of();
        }
        List<Long> postIds = posts.stream().map(Post::getId).toList();
        Set<Long> authorIds = posts.stream().map(Post::getAuthorId).collect(Collectors.toCollection(HashSet::new));
        List<User> authors = users.findAllById(authorIds);
        Map<Long, PublicProfile> byId = profiles.mapAll(viewerId, authors).stream()
                .collect(Collectors.toMap(PublicProfile::id, Function.identity(), (a, b) -> a));
        Map<Long, List<MediaView>> media = mediaFor(postIds, viewerId);
        Set<Long> liked = likedFor(viewerId, postIds);
        PostSaveLookup saves = saveLookups == null ? null : saveLookups.getIfAvailable();
        Set<Long> saved = saves == null ? Set.of() : saves.savedPostIds(viewerId, postIds);
        boolean admin = CurrentUser.isAdmin();
        Map<Long, UserPopularityService.Snapshot> pops = popularityOf(authorIds);
        Map<Long, List<PostDtos.MentionView>> mentions = mentionService == null ? Map.of()
                : mentionService.viewsFor(viewerId, postIds);

        List<PostView> out = new ArrayList<>(posts.size());
        for (Post p : posts) {
            PublicProfile a = byId.get(p.getAuthorId());
            UserPopularityService.Snapshot pop = pops.get(p.getAuthorId());
            Integer followers = pop == null ? null : pop.followerCount();
            AuthorView author = a == null ? new AuthorView(p.getAuthorId(), "", null, null, followers,
                    pop == null ? null : pop.score())
                    : new AuthorView(a.id(), a.displayName(), a.avatarUrl(), a.department(), followers,
                            pop == null ? null : pop.score());
            boolean mine = p.getAuthorId().equals(viewerId);
            List<MediaView> mv = media.getOrDefault(p.getId(), List.of());
            MediaView first = mv.isEmpty() ? null : mv.get(0);
            boolean video = first != null && "VIDEO".equals(first.kind());
            VideoView vv = video ? new VideoView(first.id(), first.url(), first.thumbUrl(), first.durationMs(),
                    first.width(), first.height()) : null;
            Integer viewCount = video ? p.getViewCount() : null;
            Integer score = rankProps == null ? null : PostRank.displayScore(rankProps, p.getLikeCount(),
                    followers == null ? 0 : followers, video ? p.getViewCount() : 0, video ? p.avgCompletion() : 0);
            out.add(new PostView(p.getId(), author, p.getBody(), mv,
                    p.getLikeCount(), liked.contains(p.getId()), mine, mine, mine || admin,
                    p.getCreatedAt(), p.getEditedAt(), video ? Post.KIND_VIDEO : Post.KIND_PHOTO, vv, viewCount,
                    score, p.getCommentCount(), saved.contains(p.getId()),
                    mentions.getOrDefault(p.getId(), List.of())));
        }
        return out;
    }

    private Map<Long, UserPopularityService.Snapshot> popularityOf(Collection<Long> authorIds) {
        if (popularity == null) {
            return Map.of();
        }
        try {
            return popularity.forUsers(authorIds);
        } catch (RuntimeException e) {
            return Map.of(); // populerlik gosterimi akisi asla dusurmez
        }
    }

    public PostView assemble(Long viewerId, Post post) {
        return assemble(viewerId, List.of(post)).get(0);
    }

    private Map<Long, List<MediaView>> mediaFor(Collection<Long> postIds, Long viewerId) {
        Map<Long, List<MediaView>> all = new HashMap<>();
        mediaLookups.orderedStream().forEach(l -> all.putAll(l.viewsFor(postIds, viewerId)));
        // Gonderi = 1..10 sirali fotograf ya da 1 video; liste position sirasindadir (media[0] = ilk medya)
        all.values().removeIf(List::isEmpty);
        return all;
    }

    private Set<Long> likedFor(Long viewerId, Collection<Long> postIds) {
        Set<Long> all = new HashSet<>();
        likeLookups.orderedStream().forEach(l -> all.addAll(l.likedPostIds(viewerId, postIds)));
        return all;
    }
}
