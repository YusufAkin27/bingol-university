package edu.bingol.backend.messaging.room;

import static org.junit.jupiter.api.Assertions.assertEquals;

import edu.bingol.backend.messaging.ConversationMember;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserStatus;
import jakarta.persistence.EntityManager;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;

/** purgeInactiveUsers native sorgusu (H2): tur basina en cok 200 pasif uyelik duser, kalani sonraki tura kalir. */
@DataJpaTest
class ChatRoomLinkPurgeInactiveTest {

    @Autowired ChatRoomLinkRepository links;
    @Autowired EntityManager em;

    @Test
    void purgesAtMost200PerRoundAndKeepsActiveMembers() {
        ChatRoomLink link = new ChatRoomLink();
        link.setKind(RoomKind.values()[0]);
        link.setRefId(1L);
        link.setConversationId(500L);
        em.persist(link);

        for (int i = 0; i < 250; i++) {
            em.persist(member(user("pasif" + i, UserStatus.SUSPENDED)));
        }
        User active = user("aktif", UserStatus.ACTIVE);
        em.persist(member(active));
        em.flush();
        em.clear();

        assertEquals(200, links.purgeInactiveUsers(Instant.now()));
        assertEquals(50, links.purgeInactiveUsers(Instant.now()));
        assertEquals(0, links.purgeInactiveUsers(Instant.now()));

        Long activeLeft = em.createQuery("select count(m) from ConversationMember m where m.leftAt is null", Long.class)
                .getSingleResult();
        assertEquals(1L, activeLeft);
    }

    private User user(String name, UserStatus status) {
        User u = new User();
        u.setEmail(name + "@example.com");
        u.setPasswordHash("x");
        u.setDisplayName(name);
        u.setStatus(status);
        em.persist(u);
        em.flush();
        return u;
    }

    private ConversationMember member(User u) {
        return ConversationMember.of(500L, u.getId(), ConversationMember.Role.MEMBER);
    }
}
