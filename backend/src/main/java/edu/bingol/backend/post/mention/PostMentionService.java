package edu.bingol.backend.post.mention;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.post.PostDtos.MentionView;
import edu.bingol.backend.post.follow.UserFollowRepository;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Gonderi etiketleme (mention) kurallari. Etiketleyen her zaman gonderinin yazaridir ve yalniz TAKIP ETTIGI (kabul
 * edilmis takip) kisileri etiketleyebilir; etiketlenen ACTIVE olmali, arada engel olmamali, kimse kendini etiketleyemez,
 * en cok {@link #MAX_MENTIONS} kisi. Gecersiz her durum tek genel hata ile reddedilir (422 POST_MENTION_INVALID;
 * hangi kimligin neden gecersiz oldugu sizdirilmaz). Bildirimi PostService gonderir (burada yok).
 */
@Service
public class PostMentionService {

    public static final int MAX_MENTIONS = 10;

    private final PostMentionRepository mentions;
    private final UserRepository users;
    private final UserFollowRepository follows;
    private final BlockService blocks;

    public PostMentionService(PostMentionRepository mentions, UserRepository users, UserFollowRepository follows,
                              BlockService blocks) {
        this.mentions = mentions;
        this.users = users;
        this.follows = follows;
        this.blocks = blocks;
    }

    /**
     * Istek listesini dogrular ve tekillestirir (sira korunur). {@code raw == null}: alan hic gonderilmedi, {@code null}
     * doner (duzenlemede "degistirme" anlami). {@code keep}: gonderide zaten etiketli olanlar; bunlar yeniden
     * dogrulanmaz (sonradan takipten cikma/engel gonderiyi duzenlemeyi bozmasin; gorunum zaten sizdirmaz).
     */
    @Transactional(readOnly = true)
    public List<Long> validate(Long authorId, List<Long> raw, Collection<Long> keep) {
        if (raw == null) {
            return null;
        }
        Set<Long> ids = new LinkedHashSet<>();
        for (Long id : raw) {
            if (id == null || id <= 0) {
                throw invalid();
            }
            ids.add(id);
        }
        if (ids.size() > MAX_MENTIONS) {
            throw invalid();
        }
        Set<Long> kept = keep == null ? Set.of() : new HashSet<>(keep);
        List<Long> fresh = ids.stream().filter(i -> !kept.contains(i)).toList();
        if (fresh.isEmpty()) {
            return new ArrayList<>(ids);
        }
        if (fresh.contains(authorId)) {
            throw invalid(); // kendini etiketleyemez
        }
        Map<Long, User> found = new HashMap<>();
        users.findAllById(fresh).forEach(u -> found.put(u.getId(), u));
        Set<Long> followed = new HashSet<>(follows.followedAmong(authorId, fresh));
        for (Long id : fresh) {
            User u = found.get(id);
            if (u == null || u.getStatus() != UserStatus.ACTIVE || !followed.contains(id)
                    || blocks.isBlocked(authorId, id)) {
                throw invalid();
            }
        }
        return new ArrayList<>(ids);
    }

    /** Gonderinin etiket listesini yeniden yazar; YENI eklenen kullanicilari (bildirim icin) sirayla doner. */
    @Transactional
    public List<Long> replace(Long postId, List<Long> ids) {
        Set<Long> current = new HashSet<>(mentions.userIdsOf(postId));
        Set<Long> target = new LinkedHashSet<>(ids);
        List<Long> gone = current.stream().filter(i -> !target.contains(i)).toList();
        if (!gone.isEmpty()) {
            mentions.deleteFor(postId, gone);
        }
        List<Long> added = target.stream().filter(i -> !current.contains(i)).toList();
        if (!added.isEmpty()) {
            mentions.saveAll(added.stream().map(u -> new PostMention(postId, u)).toList());
            mentions.flush();
        }
        return added;
    }

    @Transactional(readOnly = true)
    public List<Long> idsOf(Long postId) {
        return mentions.userIdsOf(postId);
    }

    /**
     * Bir sayfadaki gonderilerin etiketleri, BAKANA gore suzulmus: pasif/silinmis hesap ve bakanla arasinda engel olan
     * kullanici listeden cikar. Gonderi basina bos liste de doner (anahtar yoksa bos sayilir).
     */
    @Transactional(readOnly = true)
    public Map<Long, List<MentionView>> viewsFor(Long viewerId, Collection<Long> postIds) {
        if (postIds.isEmpty()) {
            return Map.of();
        }
        List<Object[]> pairs = mentions.pairsFor(postIds);
        if (pairs.isEmpty()) {
            return Map.of();
        }
        Set<Long> userIds = new HashSet<>();
        for (Object[] p : pairs) {
            userIds.add((Long) p[1]);
        }
        Map<Long, User> byId = new HashMap<>();
        users.findAllById(userIds).forEach(u -> byId.put(u.getId(), u));
        Set<Long> hidden = viewerId == null ? Set.of() : blocks.hiddenFrom(viewerId);
        Map<Long, List<MentionView>> out = new HashMap<>();
        for (Object[] p : pairs) {
            Long postId = (Long) p[0];
            Long uid = (Long) p[1];
            User u = byId.get(uid);
            if (u == null || u.getStatus() != UserStatus.ACTIVE || hidden.contains(uid)
                    || u.getDisplayName() == null || u.getDisplayName().isBlank()) {
                continue;
            }
            out.computeIfAbsent(postId, k -> new ArrayList<>()).add(new MentionView(uid, u.getDisplayName()));
        }
        return out;
    }

    private static ApiException invalid() {
        return new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "POST_MENTION_INVALID",
                "Etiketlenen kişi geçersiz. Yalnızca takip ettiğiniz kişileri etiketleyebilirsiniz.");
    }
}
