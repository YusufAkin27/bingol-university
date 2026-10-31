package edu.bingol.backend.post.follow;

import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Gizli hesap kapısı: içeriği (gönderi, takipçi/takip listesi) kimin görebileceğini TEK yerde karar verir.
 * Kural: hesap herkese açıksa herkes; gizliyse yalnız sahibi ve KABUL EDİLMİŞ takipçileri (bekleyen istek sayılmaz).
 * Düz SQL (H2 ve PostgreSQL ortak); toplu sorgular tek istekte.
 */
@Component
public class PrivateAccountGate {

    public static final String NONE = "NONE";
    public static final String REQUESTED = "REQUESTED";
    public static final String FOLLOWING = "FOLLOWING";
    public static final String SELF = "SELF";

    /** Bir hedefin bakana göre ilişki özeti. */
    public record Relation(boolean isPrivate, String followState, boolean locked) {}

    private final NamedParameterJdbcTemplate jdbc;

    public PrivateAccountGate(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public boolean isPrivate(Long userId) {
        return userId != null && !privateAmong(List.of(userId)).isEmpty();
    }

    /** ids içinden gizli hesaplar. */
    public Set<Long> privateAmong(Collection<Long> ids) {
        if (ids == null || ids.isEmpty()) {
            return Set.of();
        }
        return new HashSet<>(jdbc.queryForList(
                "SELECT user_id FROM profile_privacy WHERE private_account = TRUE AND user_id IN (:ids)",
                new MapSqlParameterSource("ids", ids), Long.class));
    }

    /** Bakan, sahibin içeriğini görebilir mi (sahip kendisi, herkese açık hesap ya da kabul edilmiş takipçi). */
    public boolean canSeeContent(Long viewer, Long owner) {
        return lockedAmong(viewer, List.of(owner)).isEmpty();
    }

    /** owners içinden içeriği bakana KAPALI olanlar (gizli ve bakan ne sahibi ne kabul edilmiş takipçisi). */
    public Set<Long> lockedAmong(Long viewer, Collection<Long> owners) {
        Set<Long> priv = privateAmong(owners);
        if (priv.isEmpty()) {
            return Set.of();
        }
        Set<Long> locked = new HashSet<>(priv);
        if (viewer != null) {
            locked.remove(viewer);
            if (!locked.isEmpty()) {
                locked.removeAll(followedAmong(viewer, locked));
            }
        }
        return locked;
    }

    /** İlişki özeti: gizlilik, takip durumu (SELF | FOLLOWING | REQUESTED | NONE) ve kilit. Toplu (en çok 3 sorgu). */
    public Map<Long, Relation> relations(Long viewer, Collection<Long> ids) {
        Map<Long, Relation> out = new HashMap<>();
        if (ids == null || ids.isEmpty()) {
            return out;
        }
        Set<Long> priv = privateAmong(ids);
        Set<Long> following = viewer == null ? Set.of() : followedAmong(viewer, ids);
        Set<Long> requested = viewer == null || priv.isEmpty() ? Set.of() : requestedAmong(viewer, priv);
        for (Long id : ids) {
            boolean self = id.equals(viewer);
            boolean isPriv = priv.contains(id);
            String state = self ? SELF : following.contains(id) ? FOLLOWING : requested.contains(id) ? REQUESTED : NONE;
            out.put(id, new Relation(isPriv, state, isPriv && !self && !following.contains(id)));
        }
        return out;
    }

    public Relation relation(Long viewer, Long id) {
        return relations(viewer, List.of(id)).get(id);
    }

    /** viewer'ın KABUL EDİLMİŞ takip ettikleri (ids içinden). */
    Set<Long> followedAmong(Long viewer, Collection<Long> ids) {
        return new HashSet<>(jdbc.queryForList(
                "SELECT followee_id FROM user_follow WHERE follower_id = :viewer AND followee_id IN (:ids)",
                new MapSqlParameterSource("viewer", viewer).addValue("ids", ids), Long.class));
    }

    /** viewer'ın bekleyen isteklerinin hedefleri (ids içinden). */
    Set<Long> requestedAmong(Long viewer, Collection<Long> ids) {
        return new HashSet<>(jdbc.queryForList(
                "SELECT target_id FROM follow_request WHERE requester_id = :viewer AND target_id IN (:ids)",
                new MapSqlParameterSource("viewer", viewer).addValue("ids", ids), Long.class));
    }
}
