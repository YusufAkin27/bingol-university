package edu.bingol.backend.post;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.post.PostDtos.AuthorView;
import edu.bingol.backend.post.PostDtos.MediaView;
import edu.bingol.backend.post.PostDtos.PostView;
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
        boolean admin = CurrentUser.isAdmin();

        List<PostView> out = new ArrayList<>(posts.size());
        for (Post p : posts) {
            PublicProfile a = byId.get(p.getAuthorId());
            AuthorView author = a == null ? new AuthorView(p.getAuthorId(), "", null, null)
                    : new AuthorView(a.id(), a.displayName(), a.avatarUrl(), a.department());
            boolean mine = p.getAuthorId().equals(viewerId);
            // Sade gonderi sozlesmesi: yorum/kaydet/etiket/bahsetme kaldirildi -> geriye uyumlu sabit degerler
            out.add(new PostView(p.getId(), author, p.getBody(), media.getOrDefault(p.getId(), List.of()),
                    p.getLikeCount(), 0, liked.contains(p.getId()), mine, mine, mine || admin,
                    p.getCreatedAt(), p.getEditedAt(), false, List.of(), List.of()));
        }
        return out;
    }

    public PostView assemble(Long viewerId, Post post) {
        return assemble(viewerId, List.of(post)).get(0);
    }

    private Map<Long, List<MediaView>> mediaFor(Collection<Long> postIds, Long viewerId) {
        Map<Long, List<MediaView>> all = new HashMap<>();
        mediaLookups.orderedStream().forEach(l -> all.putAll(l.viewsFor(postIds, viewerId)));
        // Yalniz ilk FOTOGRAF gosterilir: eski video/coklu gorselli gonderilerde fazlasi gizlenir (veri silinmez)
        Map<Long, List<MediaView>> firstImage = new HashMap<>();
        all.forEach((id, list) -> list.stream().filter(m -> "IMAGE".equals(m.kind())).findFirst()
                .ifPresent(m -> firstImage.put(id, List.of(m))));
        return firstImage;
    }

    private Set<Long> likedFor(Long viewerId, Collection<Long> postIds) {
        Set<Long> all = new HashSet<>();
        likeLookups.orderedStream().forEach(l -> all.addAll(l.likedPostIds(viewerId, postIds)));
        return all;
    }
}
