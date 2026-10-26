package edu.bingol.backend.community.extras;

import edu.bingol.backend.community.CommunityMember;
import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/** Uye listesi filtresi/arama ve toplu dagitim sorgulari (CommunityMemberRepository'ye dokunmadan). */
public interface ClubMemberQueryRepository extends JpaRepository<CommunityMember, Long> {

    /**
     * Filtreli uye sayfasi: id'ye gore artan imec. {@code anyRole} true ise rol filtresi uygulanmaz
     * ({@code role} yine de dolu verilmelidir). {@code pattern} bos ise ad filtresi yok; doluysa
     * {@code lower(ad) LIKE pattern ESCAPE '!'} (Texts.likePattern ile uretilir).
     */
    @Query("""
            SELECT m FROM CommunityMember m, User u
            WHERE u.id = m.userId AND m.communityId = :cid AND m.status = :status
              AND (:anyRole = TRUE OR m.role = :role)
              AND m.id > :cursor AND m.userId NOT IN :excluded
              AND u.status <> edu.bingol.backend.user.UserStatus.DELETED
              AND (:pattern = '' OR lower(u.displayName) LIKE :pattern ESCAPE '!')
            ORDER BY m.id
            """)
    List<CommunityMember> filtered(@Param("cid") Long communityId, @Param("status") CommunityMember.Status status,
                                   @Param("anyRole") boolean anyRole, @Param("role") CommunityMember.Role role,
                                   @Param("pattern") String pattern, @Param("cursor") long cursor,
                                   @Param("excluded") Collection<Long> excluded, Pageable page);

    /** Bildirim/oda dagitimi: ACTIVE uyeligi olan, hesabi ACTIVE kullanicilarin id'leri, kullanici id'sine gore artan. */
    @Query("SELECT m.userId FROM CommunityMember m, User u WHERE u.id = m.userId AND m.communityId = :cid "
            + "AND m.status = edu.bingol.backend.community.CommunityMember.Status.ACTIVE "
            + "AND u.status = edu.bingol.backend.user.UserStatus.ACTIVE AND m.userId > :after ORDER BY m.userId")
    List<Long> activeUserIdsAfter(@Param("cid") Long communityId, @Param("after") long afterUserId, Pageable page);
}
