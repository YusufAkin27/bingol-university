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

    @Query("SELECT d FROM DepartmentChatRoom d, ChatRoomLink l WHERE l.refId = d.id "
            + "AND l.kind = edu.bingol.backend.messaging.room.RoomKind.DEPARTMENT AND l.conversationId = :cid")
    Optional<DepartmentChatRoom> findByConversationId(@Param("cid") Long conversationId);

    java.util.List<DepartmentChatRoom> findByDeptKeyIn(java.util.Collection<String> deptKeys);

    java.util.List<DepartmentChatRoom> findAllByOrderByNameAsc(org.springframework.data.domain.Pageable page);

    /** Yaristan guvenli ekleme: anahtar varsa 0 doner, hata firlatmaz (cagiran islem rollback-only olmasin). */
    @Transactional
    @Modifying
    @Query(value = "INSERT INTO department_chat_room (dept_key, name, created_at) VALUES (:k, :n, :at) "
            + "ON CONFLICT (dept_key) DO NOTHING", nativeQuery = true)
    int insertIfAbsent(@Param("k") String deptKey, @Param("n") String name, @Param("at") Instant at);
}
