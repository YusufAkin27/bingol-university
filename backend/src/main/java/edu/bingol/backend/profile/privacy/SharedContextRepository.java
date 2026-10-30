package edu.bingol.backend.profile.privacy;

import java.util.Collection;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * "Ortak baglam" sorgulari: iki kullanicinin ayni kulupte (ACTIVE), ayni sohbette (ayrilmamis) veya ayni
 * etkinlige RSVP'li olmasi. Diger modullerin depolarina bagimli olmamak icin duz SQL (yalnizca okuma).
 * Not: PostgreSQL ve H2 ortak SQL'i kullanir; testlerde Mockito ile taklit edilir.
 */
@Repository
public class SharedContextRepository {

    private static final String SHARED = """
            SELECT DISTINCT o.uid FROM (
              SELECT b.user_id AS uid FROM community_member a JOIN community_member b
                ON a.community_id = b.community_id
               WHERE a.user_id = :viewer AND a.status = 'ACTIVE' AND b.status = 'ACTIVE' AND b.user_id IN (:owners)
              UNION
              SELECT b.user_id FROM conversation_member a JOIN conversation_member b
                ON a.conversation_id = b.conversation_id
               WHERE a.user_id = :viewer AND a.left_at IS NULL AND b.left_at IS NULL AND b.user_id IN (:owners)
              UNION
              SELECT b.user_id FROM event_rsvp a JOIN event_rsvp b ON a.event_id = b.event_id
               WHERE a.user_id = :viewer AND b.user_id IN (:owners)
            ) o
            """;

    /** SHARED'in ters yonu: tek bir sahip (owner) ile ortak baglami olan bakanlar (viewers icinden), tek sorgu. */
    private static final String SHARED_VIEWERS = """
            SELECT DISTINCT o.uid FROM (
              SELECT a.user_id AS uid FROM community_member a JOIN community_member b
                ON a.community_id = b.community_id
               WHERE b.user_id = :owner AND a.status = 'ACTIVE' AND b.status = 'ACTIVE' AND a.user_id IN (:viewers)
              UNION
              SELECT a.user_id FROM conversation_member a JOIN conversation_member b
                ON a.conversation_id = b.conversation_id
               WHERE b.user_id = :owner AND a.left_at IS NULL AND b.left_at IS NULL AND a.user_id IN (:viewers)
              UNION
              SELECT a.user_id FROM event_rsvp a JOIN event_rsvp b ON a.event_id = b.event_id
               WHERE b.user_id = :owner AND a.user_id IN (:viewers)
            ) o
            """;

    private final NamedParameterJdbcTemplate jdbc;

    public SharedContextRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** viewers icinden, owner ile ortak baglami olanlar (toplu; bakan basina sorgu yok). */
    public Set<Long> viewersSharingWith(Long ownerId, Collection<Long> viewers) {
        if (viewers.isEmpty()) {
            return Set.of();
        }
        return new HashSet<>(jdbc.queryForList(SHARED_VIEWERS,
                new MapSqlParameterSource(Map.of("owner", ownerId, "viewers", viewers)), Long.class));
    }

    /** owners icinden, viewer ile ortak baglami olanlar. */
    public Set<Long> sharedWith(Long viewerId, Collection<Long> owners) {
        if (owners.isEmpty()) {
            return Set.of();
        }
        return new HashSet<>(jdbc.queryForList(SHARED,
                new MapSqlParameterSource(Map.of("viewer", viewerId, "owners", owners)), Long.class));
    }
}
