package edu.bingol.backend.messaging;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ConversationAddBanRepository extends JpaRepository<ConversationAddBan, ConversationAddBan.Key> {

    /** {@code adderId}'in yeniden ekleyemeyecegi kullanicilar ({@code userIds} icinden; tek PK onekli sorgu). */
    @Query("SELECT b.userId FROM ConversationAddBan b WHERE b.adderId = :adder AND b.userId IN :ids")
    List<Long> bannedUsers(@Param("adder") Long adderId, @Param("ids") Collection<Long> userIds);
}
