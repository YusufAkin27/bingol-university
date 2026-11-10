package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;

import edu.bingol.backend.messaging.room.ChatRoomLink;
import edu.bingol.backend.messaging.room.RoomKind;
import java.time.Instant;
import java.util.List;
import org.hibernate.Session;
import org.hibernate.SessionFactory;
import org.hibernate.cfg.Configuration;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.Query;

class DepartmentConversationPageTest {
    @Test
    void pagesEmptyClubEventDepartmentRoomsAndPreservesMembershipAndShadowVisibility() throws Exception {
        try (SessionFactory factory = new Configuration()
                .addAnnotatedClass(Conversation.class)
                .addAnnotatedClass(ConversationMember.class)
                .addAnnotatedClass(ChatRoomLink.class)
                .setProperty("hibernate.connection.url", "jdbc:h2:mem:department-page;DB_CLOSE_DELAY=-1")
                .setProperty("hibernate.hbm2ddl.auto", "create-drop")
                .buildSessionFactory(); Session session = factory.openSession()) {
            var tx = session.beginTransaction();
            Conversation message = room(session, RoomKind.COMMUNITY, 1L, 100L, null, false);
            Conversation emptyA = room(session, RoomKind.DEPARTMENT, 2L, null, null, false);
            Conversation emptyB = room(session, RoomKind.COMMUNITY, 3L, null, null, false);
            Conversation emptyC = room(session, RoomKind.EVENT, 4L, null, null, false);
            plain(session); // birebir/grup: oda baglantisi yok, mesaj gelene kadar listelenmez
            room(session, RoomKind.DEPARTMENT, 5L, null, Instant.now(), false);
            room(session, RoomKind.DEPARTMENT, 6L, 200L, null, true);
            session.flush();
            String hql = ConversationRepository.class.getMethod("page", Long.class, Long.class, boolean.class, Pageable.class)
                    .getAnnotation(Query.class).value();
            assertEquals(List.of(message.getId(), emptyA.getId(), emptyB.getId(), emptyC.getId()), page(session, hql, null, 10));
            assertEquals(List.of(emptyA.getId(), emptyB.getId(), emptyC.getId()), page(session, hql, 100L, 10));
            assertEquals(List.of(emptyB.getId(), emptyC.getId()), page(session, hql, -emptyA.getId(), 10));
            tx.rollback();
        }
    }

    private List<Long> page(Session s, String hql, Long cursor, int size) {
        return s.createQuery(hql, Conversation.class).setParameter("uid", 7L)
                .setParameter("cursor", cursor).setParameter("archived", false).setMaxResults(size)
                .getResultList().stream().map(Conversation::getId).toList();
    }

    /** Oda baglantisi olmayan, mesajsiz normal sohbet. */
    private Conversation plain(Session s) {
        Conversation c = new Conversation();
        c.setCreatedBy(7L);
        c.setType(Conversation.Type.GROUP);
        s.persist(c);
        ConversationMember m = new ConversationMember();
        m.setConversationId(c.getId());
        m.setUserId(7L);
        s.persist(m);
        return c;
    }

    private Conversation room(Session s, RoomKind kind, long ref, Long last, Instant leftAt, boolean shadowed) {
        Conversation c = new Conversation();
        c.setCreatedBy(7L);
        c.setType(Conversation.Type.GROUP);
        c.setLastMessageId(last);
        c.setShadowed(shadowed);
        s.persist(c);
        ConversationMember m = new ConversationMember();
        m.setConversationId(c.getId());
        m.setUserId(7L);
        m.setLeftAt(leftAt);
        s.persist(m);
        ChatRoomLink link = new ChatRoomLink();
        link.setKind(kind);
        link.setRefId(ref);
        link.setConversationId(c.getId());
        s.persist(link);
        return c;
    }
}
