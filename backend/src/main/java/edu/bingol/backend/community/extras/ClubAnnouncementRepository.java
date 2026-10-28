package edu.bingol.backend.community.extras;

import edu.bingol.backend.community.CommunityPost;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/** Duyuru (announcement=true) gonderileri icin sorgular; ayni varlik, ayri depo (modul oneki: bean adi cakismasin). */
public interface ClubAnnouncementRepository extends JpaRepository<CommunityPost, Long> {

    /** Silinmisler de sayilir: silip yeniden yazarak gunluk siniri asmak engellenir. */
    @Query("SELECT COUNT(p) FROM CommunityPost p WHERE p.communityId = :cid AND p.announcement = TRUE AND p.createdAt >= :since")
    long countSince(@Param("cid") Long communityId, @Param("since") Instant since);

    @Query("""
            SELECT p FROM CommunityPost p
            WHERE p.communityId = :cid AND p.announcement = TRUE AND p.deleted = FALSE AND p.hiddenAt IS NULL
              AND p.id < :cursor AND p.authorId NOT IN :excluded
            ORDER BY p.id DESC
            """)
    List<CommunityPost> page(@Param("cid") Long communityId, @Param("cursor") long cursor,
                             @Param("excluded") Collection<Long> excluded, Pageable page);

    List<CommunityPost> findByAuthorIdAndAnnouncementTrueAndDeletedFalse(Long authorId);
}
