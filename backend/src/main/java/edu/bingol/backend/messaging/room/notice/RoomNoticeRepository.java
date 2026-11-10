package edu.bingol.backend.messaging.room.notice;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface RoomNoticeRepository extends JpaRepository<RoomNotice, Long> {

    @Query("SELECT n FROM RoomNotice n WHERE n.conversationId = :cid AND n.deletedAt IS NULL AND n.hiddenAt IS NULL "
            + "AND n.id < :before ORDER BY n.id DESC")
    List<RoomNotice> page(@Param("cid") Long cid, @Param("before") long before, Pageable p);

    @Query("SELECT n FROM RoomNotice n WHERE n.conversationId = :cid AND n.pinned = TRUE AND n.deletedAt IS NULL "
            + "AND n.hiddenAt IS NULL ORDER BY n.id DESC")
    List<RoomNotice> pinned(@Param("cid") Long cid, Pageable p);

    @Query("SELECT COUNT(n) FROM RoomNotice n WHERE n.conversationId = :cid AND n.deletedAt IS NULL AND n.hiddenAt IS NULL")
    long countLive(@Param("cid") Long cid);

    @Query("SELECT COUNT(n) FROM RoomNotice n WHERE n.conversationId = :cid AND n.pinned = TRUE AND n.deletedAt IS NULL "
            + "AND n.hiddenAt IS NULL")
    long countPinned(@Param("cid") Long cid);

    /** Tekil kayit: zaten gorulduyse 0 (H2 + PostgreSQL uyumlu NOT EXISTS). Es zamanli cakisma PK ile engellenir. */
    @Transactional
    @Modifying
    @Query(value = "INSERT INTO room_notice_seen (notice_id, user_id, seen_at) SELECT :nid, :uid, :at "
            + "WHERE NOT EXISTS (SELECT 1 FROM room_notice_seen WHERE notice_id = :nid AND user_id = :uid)",
            nativeQuery = true)
    int insertSeen(@Param("nid") Long noticeId, @Param("uid") Long userId, @Param("at") Instant at);

    @Transactional
    @Modifying
    @Query("UPDATE RoomNotice n SET n.seenCount = n.seenCount + 1 WHERE n.id = :id")
    int bumpSeen(@Param("id") Long id);

    @Query(value = "SELECT notice_id FROM room_notice_seen WHERE user_id = :uid AND notice_id IN (:ids)", nativeQuery = true)
    List<Long> seenAmong(@Param("uid") Long userId, @Param("ids") Collection<Long> ids);

    @Transactional
    @Modifying
    @Query(value = "DELETE FROM room_notice_seen WHERE user_id = :uid", nativeQuery = true)
    int deleteSeenOf(@Param("uid") Long userId);

    @Query("SELECT m.userId FROM edu.bingol.backend.messaging.ConversationMember m WHERE m.conversationId = :cid "
            + "AND m.leftAt IS NULL AND m.userId > :after ORDER BY m.userId")
    List<Long> memberIdsAfter(@Param("cid") Long cid, @Param("after") long after, Pageable p);

    @Query("SELECT c.title FROM edu.bingol.backend.messaging.Conversation c WHERE c.id = :cid")
    java.util.Optional<String> conversationTitle(@Param("cid") Long cid);

    @Query("SELECT n FROM RoomNotice n WHERE n.authorId = :uid AND n.deletedAt IS NULL ORDER BY n.id DESC")
    List<RoomNotice> authoredBy(@Param("uid") Long uid, Pageable p);
}
