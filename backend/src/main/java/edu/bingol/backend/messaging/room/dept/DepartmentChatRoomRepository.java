package edu.bingol.backend.messaging.room.dept;

import java.time.Instant;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface DepartmentChatRoomRepository extends JpaRepository<DepartmentChatRoom, Long> {

    Optional<DepartmentChatRoom> findByDeptKey(String deptKey);

    java.util.List<DepartmentChatRoom> findAllByOrderByNameAsc(org.springframework.data.domain.Pageable page);

    /** Yaristan guvenli ekleme: anahtar varsa 0 doner, hata firlatmaz (cagiran islem rollback-only olmasin). */
    @Transactional
    @Modifying
    @Query(value = "INSERT INTO department_chat_room (dept_key, name, created_at) VALUES (:k, :n, :at) "
            + "ON CONFLICT (dept_key) DO NOTHING", nativeQuery = true)
    int insertIfAbsent(@Param("k") String deptKey, @Param("n") String name, @Param("at") Instant at);

    /**
     * Tum bolum odalarinin ozeti (uye sayisi + :uid uyeligi). Oda sayisi katalogla sinirlidir (~600); yine de
     * ust sinir 1000. Indeks: chat_room_link (kind, ref_id) benzersiz, conversation_member (conversation_id).
     */
    @Query(value = """
            SELECT d.dept_key AS deptKey, d.id AS roomId, l.conversation_id AS conversationId, l.closed AS closed,
                   (SELECT count(*) FROM conversation_member m
                     WHERE m.conversation_id = l.conversation_id AND m.left_at IS NULL) AS memberCount,
                   EXISTS (SELECT 1 FROM conversation_member m
                     WHERE m.conversation_id = l.conversation_id AND m.user_id = :uid AND m.left_at IS NULL) AS joined
              FROM department_chat_room d
              LEFT JOIN chat_room_link l ON l.kind = 'DEPARTMENT' AND l.ref_id = d.id
             ORDER BY d.id LIMIT 1000
            """, nativeQuery = true)
    java.util.List<DepartmentChatStats> statsFor(@Param("uid") Long userId);
}
