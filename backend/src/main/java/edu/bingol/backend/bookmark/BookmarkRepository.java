package edu.bingol.backend.bookmark;

import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface BookmarkRepository extends JpaRepository<Bookmark, Long> {

    boolean existsByUserIdAndTargetTypeAndTargetId(Long userId, BookmarkTarget type, Long targetId);

    long countByUserId(Long userId);

    /** Yeni -> eski (id sirasi kaydedilme sirasidir); cursor'dan eski kayitlar (ilk sayfa icin Long.MAX_VALUE). */
    @Query("select b from Bookmark b where b.userId = :uid and b.targetType = :type "
            + "and b.id < :cursor order by b.id desc")
    List<Bookmark> page(@Param("uid") Long uid, @Param("type") BookmarkTarget type,
                        @Param("cursor") Long cursor, Pageable pageable);

    @Query("select b.targetId from Bookmark b where b.userId = :uid and b.targetType = :type order by b.id desc")
    List<Long> targetIds(@Param("uid") Long uid, @Param("type") BookmarkTarget type, Pageable pageable);

    /** Eszamanli cift PUT'ta bile hata vermez (PostgreSQL ON CONFLICT). */
    @Modifying
    @Query(value = "INSERT INTO bookmark (user_id, target_type, target_id, created_at) "
            + "VALUES (:uid, :type, :tid, now()) ON CONFLICT (user_id, target_type, target_id) DO NOTHING",
            nativeQuery = true)
    int insertIfAbsent(@Param("uid") Long uid, @Param("type") String type, @Param("tid") Long targetId);

    @Modifying
    @Query("delete from Bookmark b where b.userId = :uid and b.targetType = :type and b.targetId = :tid")
    int remove(@Param("uid") Long uid, @Param("type") BookmarkTarget type, @Param("tid") Long targetId);
}
