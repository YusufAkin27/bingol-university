package edu.bingol.backend.post.mention;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PostMentionRepository extends JpaRepository<PostMention, PostMentionId> {

    /** Gonderinin etiketli kullanici kimlikleri (en cok 10 satir). */
    @Query("SELECT m.id.userId FROM PostMention m WHERE m.id.postId = :pid")
    List<Long> userIdsOf(@Param("pid") Long postId);

    /** Bir sayfadaki gonderilerin etiketleri: [postId, userId], etiketleme sirasiyla (sayfa boyutu x en cok 10). */
    @Query("SELECT m.id.postId, m.id.userId FROM PostMention m WHERE m.id.postId IN :ids "
            + "ORDER BY m.createdAt, m.id.userId")
    List<Object[]> pairsFor(@Param("ids") Collection<Long> postIds);

    @Modifying(flushAutomatically = true)
    @Query("DELETE FROM PostMention m WHERE m.id.postId = :pid AND m.id.userId IN :ids")
    int deleteFor(@Param("pid") Long postId, @Param("ids") Collection<Long> userIds);
}
