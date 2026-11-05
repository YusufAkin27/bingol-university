package edu.bingol.backend.forum.moderation;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Forum sessize alma (tek yonlu, bakan tarafindan). Engelden farki: karsi taraf bizi gormeye devam eder, mesajlasma /
 * profil etkilenmez; yalniz forum listelerinde/yorumlarinda/aramasinda o kullanicinin icerigi bizden gizlenir.
 * Gizleme kararini listeleyen moduller {@link #mutedIds} / {@link #isMuted} ile SUNUCUDA verir.
 */
@Service
public class ForumMuteService {

    /** Bir kullanicinin sessize alabilecegi en fazla kisi (sorgu ve bellek tavani). */
    static final int MAX_MUTES = 500;

    public record MutedUser(Long userId, String displayName, String avatarUrl, Instant mutedAt) {}

    public record MutePage(List<MutedUser> items, String nextCursor) {}

    private final ForumUserMuteRepository mutes;
    private final UserRepository users;

    public ForumMuteService(ForumUserMuteRepository mutes, UserRepository users) {
        this.mutes = mutes;
        this.users = users;
    }

    /** Idempotent: zaten sessizdeyse sessizce basarili. */
    @Transactional
    public void mute(Long me, Long target) {
        if (me.equals(target)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "FORUM_CANNOT_MUTE_SELF", "Kendinizi sessize alamazsınız.");
        }
        if (users.findById(target).filter(User::isActive).isEmpty()) {
            throw new ApiException(HttpStatus.NOT_FOUND, "FORUM_MUTE_USER_NOT_FOUND", "Kullanıcı bulunamadı.");
        }
        if (mutes.existsByUserIdAndMutedUserId(me, target)) {
            return;
        }
        if (mutes.countByUserId(me) >= MAX_MUTES) {
            throw new ApiException(HttpStatus.CONFLICT, "FORUM_MUTE_LIMIT", "En fazla 500 kullanıcıyı sessize alabilirsiniz.",
                    String.valueOf(MAX_MUTES));
        }
        try {
            mutes.saveAndFlush(new ForumUserMute(me, target));
        } catch (org.springframework.dao.DataIntegrityViolationException e) {
            // cift dokunus yarisi: PK zaten var -> amac gerceklesmis
        }
    }

    @Transactional
    public void unmute(Long me, Long target) {
        mutes.remove(me, target);
    }

    public boolean isMuted(Long viewerId, Long authorId) {
        return viewerId != null && authorId != null && mutes.existsByUserIdAndMutedUserId(viewerId, authorId);
    }

    /** Bakanin sessize aldigi kullanici kimlikleri (liste/arama sorgularinda dislamak icin; en fazla {@value #MAX_MUTES}). */
    public Set<Long> mutedIds(Long viewerId) {
        return viewerId == null ? Set.of() : Set.copyOf(mutes.mutedIds(viewerId));
    }

    /** Sessize aldiklarim, yeniden eskiye. cursor = sayfa numarasi (opak kabul edilir), size en cok 50. */
    @Transactional(readOnly = true)
    public MutePage list(Long me, String cursor, int size) {
        int sz = Math.min(Math.max(size, 1), 50);
        int page = 0;
        try {
            page = cursor == null || cursor.isBlank() ? 0 : Math.max(0, Integer.parseInt(cursor.trim()));
        } catch (NumberFormatException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "FORUM_MOD_BAD_CURSOR", "Geçersiz sayfa imleci.");
        }
        List<ForumUserMute> rows = mutes.page(me, PageRequest.of(page, sz + 1));
        boolean more = rows.size() > sz;
        List<ForumUserMute> cut = more ? rows.subList(0, sz) : rows;
        Map<Long, User> byId = new HashMap<>();
        users.findAllById(cut.stream().map(ForumUserMute::getMutedUserId).toList()).forEach(u -> byId.put(u.getId(), u));
        List<MutedUser> items = cut.stream().filter(m -> byId.containsKey(m.getMutedUserId()))
                .map(m -> new MutedUser(m.getMutedUserId(), byId.get(m.getMutedUserId()).getDisplayName(), null,
                        m.getCreatedAt())).toList();
        return new MutePage(items, more ? String.valueOf(page + 1) : null);
    }
}
