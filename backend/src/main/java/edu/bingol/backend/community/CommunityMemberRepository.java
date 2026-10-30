package edu.bingol.backend.community;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CommunityMemberRepository extends JpaRepository<CommunityMember, Long> {

    Optional<CommunityMember> findByCommunityIdAndUserId(Long communityId, Long userId);

    /** Sahip silinince devir adayi: verilen rollerdeki aktif uyeler, en eski katilan once. */
    List<CommunityMember> findByCommunityIdAndStatusAndRoleInOrderByJoinedAtAscIdAsc(
            Long communityId, CommunityMember.Status status, Collection<CommunityMember.Role> roles);

    long countByCommunityIdAndStatus(Long communityId, CommunityMember.Status status);

    /** Uye listesi / bekleyen istekler: id'ye gore artan, engellenenler haric. */
    @Query("""
            SELECT m FROM CommunityMember m
            WHERE m.communityId = :cid AND m.status = :status AND m.id > :cursor AND m.userId NOT IN :excluded
              AND m.userId IN (SELECT u.id FROM User u WHERE u.status <> edu.bingol.backend.user.UserStatus.DELETED)
            ORDER BY m.id
            """)
    List<CommunityMember> page(@Param("cid") Long communityId, @Param("status") CommunityMember.Status status,
                               @Param("cursor") long cursor, @Param("excluded") Collection<Long> excluded,
                               Pageable page);

    /** Bildirim hedefleri: topluluktaki aktif uyelerin id'leri. */
    @Query("SELECT m.userId FROM CommunityMember m WHERE m.communityId = :cid AND m.status = :status"
            + " AND m.userId IN (SELECT u.id FROM User u WHERE u.status <> edu.bingol.backend.user.UserStatus.DELETED)")
    List<Long> userIdsByStatus(@Param("cid") Long communityId, @Param("status") CommunityMember.Status status,
                               Pageable page);

    /** Aktif moderator + sahip id'leri. */
    @Query("SELECT m.userId FROM CommunityMember m WHERE m.communityId = :cid AND m.status = :status AND m.role <> :member")
    List<Long> moderatorIds(@Param("cid") Long communityId, @Param("status") CommunityMember.Status status,
                            @Param("member") CommunityMember.Role member);

    /** Uyeliklerim (aktif), uyelik id'sine gore azalan imec. */
    @Query("SELECT m FROM CommunityMember m WHERE m.userId = :uid AND m.status = :status AND m.id < :cursor ORDER BY m.id DESC")
    List<CommunityMember> mine(@Param("uid") Long userId, @Param("status") CommunityMember.Status status,
                               @Param("cursor") long cursor, Pageable page);

    /** Verilen topluluklardaki aktif uye sayilari: [communityId, count]. */
    @Query("SELECT m.communityId, COUNT(m) FROM CommunityMember m WHERE m.communityId IN :ids AND m.status = :status"
            + " AND m.userId IN (SELECT u.id FROM User u WHERE u.status <> edu.bingol.backend.user.UserStatus.DELETED)"
            + " GROUP BY m.communityId")
    List<Object[]> countByCommunity(@Param("ids") Collection<Long> communityIds,
                                    @Param("status") CommunityMember.Status status);

    /** Bir topluluktaki verilen kullanicilarin uyelik kayitlari (yazar rol etiketi icin tek sorgu). */
    List<CommunityMember> findByCommunityIdAndUserIdIn(Long communityId, Collection<Long> userIds);

    /** Verilen topluluklardaki benim uyelik kayitlarim. */
    List<CommunityMember> findByUserIdAndCommunityIdIn(Long userId, Collection<Long> communityIds);
}
