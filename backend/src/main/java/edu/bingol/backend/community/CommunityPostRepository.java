package edu.bingol.backend.community;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CommunityPostRepository extends JpaRepository<CommunityPost, Long> {

    Optional<CommunityPost> findByIdAndCommunityIdAndDeletedFalse(Long id, Long communityId);

    /** Gorselli yazilar: hesap/kulup silinirken dosyalari temizlemek icin. */
    List<CommunityPost> findByAuthorIdAndImageUrlIsNotNull(Long authorId);

    List<CommunityPost> findByCommunityIdAndImageUrlIsNotNull(Long communityId);

    long countByCommunityIdAndPinnedTrueAndDeletedFalse(Long communityId);

    /** Sabitli yazilar (en fazla 3), yeniden eskiye; engellenen yazarlar haric. */
    @Query("""
            SELECT p FROM CommunityPost p
            WHERE p.communityId = :cid AND p.pinned = TRUE AND p.deleted = FALSE AND p.hiddenAt IS NULL AND p.authorId NOT IN :excluded
            ORDER BY p.id DESC
            """)
    List<CommunityPost> pinned(@Param("cid") Long communityId, @Param("excluded") Collection<Long> excluded);

    /** Akis: sabitlenmemis yazilar, id'ye gore azalan imec; engellenen yazarlar haric. */
    @Query("""
            SELECT p FROM CommunityPost p
            WHERE p.communityId = :cid AND p.pinned = FALSE AND p.deleted = FALSE AND p.hiddenAt IS NULL
              AND p.id < :cursor AND p.authorId NOT IN :excluded
            ORDER BY p.id DESC
            """)
    List<CommunityPost> feed(@Param("cid") Long communityId, @Param("cursor") long cursor,
                             @Param("excluded") Collection<Long> excluded, Pageable page);
}
