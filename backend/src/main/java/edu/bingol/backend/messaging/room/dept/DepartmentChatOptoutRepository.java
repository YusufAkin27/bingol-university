package edu.bingol.backend.messaging.room.dept;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface DepartmentChatOptoutRepository extends JpaRepository<DepartmentChatOptout, DepartmentChatOptout.Key> {

    boolean existsByUserIdAndDeptKey(Long userId, String deptKey);

    List<DepartmentChatOptout> findByUserId(Long userId);

    @Transactional
    @Modifying
    @Query("DELETE FROM DepartmentChatOptout o WHERE o.userId = :uid AND o.deptKey = :k")
    int deleteOne(@Param("uid") Long userId, @Param("k") String deptKey);
}
