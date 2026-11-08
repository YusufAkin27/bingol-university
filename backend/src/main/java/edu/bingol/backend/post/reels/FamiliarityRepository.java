package edu.bingol.backend.post.reels;

import edu.bingol.backend.post.Post;
import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;

/** Keşfet tanışıklık sinyalleri (aday yazar kümesi başına tek sorgu; üst düzey arayüz, bean: familiarityRepository). */
public interface FamiliarityRepository extends Repository<Post, Long> {

    /** Adaylardan beni takip edenler (karşılıklı takip sinyali). */
    @Query("SELECT f.id.a FROM UserFollow f WHERE f.id.b = :uid AND f.id.a IN :authors")
    List<Long> followingMe(@Param("uid") Long userId, @Param("authors") Collection<Long> authors);

    /** Adaylardan benimle kabul edilmiş, aktif birebir sohbeti olanlar. */
    @Query("SELECT DISTINCT m2.userId FROM ConversationMember m1, ConversationMember m2, Conversation c "
            + "WHERE c.id = m1.conversationId AND c.type = edu.bingol.backend.messaging.Conversation.Type.DIRECT "
            + "AND m2.conversationId = m1.conversationId AND m1.userId = :uid AND m2.userId IN :authors "
            + "AND m1.leftAt IS NULL AND m2.leftAt IS NULL "
            + "AND m1.requestState = edu.bingol.backend.messaging.ConversationMember.RequestState.ACCEPTED "
            + "AND m2.requestState = edu.bingol.backend.messaging.ConversationMember.RequestState.ACCEPTED")
    List<Long> directContacts(@Param("uid") Long userId, @Param("authors") Collection<Long> authors);

    /** Aday yazar başına ortak aktif kulüp sayısı: [authorId, count]. */
    @Query("SELECT m2.userId, COUNT(DISTINCT m1.communityId) FROM CommunityMember m1, CommunityMember m2 "
            + "WHERE m1.communityId = m2.communityId AND m1.userId = :uid AND m2.userId IN :authors "
            + "AND m1.status = edu.bingol.backend.community.CommunityMember.Status.ACTIVE "
            + "AND m2.status = edu.bingol.backend.community.CommunityMember.Status.ACTIVE GROUP BY m2.userId")
    List<Object[]> sharedClubCounts(@Param("uid") Long userId, @Param("authors") Collection<Long> authors);

    /** Takip ettiklerimin takip ettiği adaylar: [authorId, kaç tanıdığım takip ediyor]. */
    @Query("SELECT f2.id.b, COUNT(f1) FROM UserFollow f1, UserFollow f2 WHERE f1.id.a = :uid AND f2.id.a = f1.id.b "
            + "AND f2.id.b IN :authors AND f2.id.b <> :uid GROUP BY f2.id.b")
    List<Object[]> friendOfFriendCounts(@Param("uid") Long userId, @Param("authors") Collection<Long> authors);

    /** Aynı bölümden adaylar. */
    @Query("SELECT u.id FROM User u, User v WHERE v.id = :uid AND u.id IN :authors "
            + "AND u.department IS NOT NULL AND u.department = v.department")
    List<Long> sameDepartment(@Param("uid") Long userId, @Param("authors") Collection<Long> authors);

    /** Aynı fakülteden adaylar. */
    @Query("SELECT u.id FROM User u, User v WHERE v.id = :uid AND u.id IN :authors "
            + "AND u.faculty IS NOT NULL AND u.faculty = v.faculty")
    List<Long> sameFaculty(@Param("uid") Long userId, @Param("authors") Collection<Long> authors);
}
