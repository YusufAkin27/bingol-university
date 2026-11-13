package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;

import edu.bingol.backend.messaging.room.ChatRoomLink;
import edu.bingol.backend.messaging.room.RoomKind;
import java.time.Instant;
import org.hibernate.Session;
import org.hibernate.SessionFactory;
import org.hibernate.cfg.Configuration;
import org.junit.jupiter.api.Test;
import org.springframework.data.jpa.repository.Query;

/** QA: arsiv cubugu sayaci (countArchived) listeyle (page archived=true) ayni kumeyi saymali: mesajsiz acik bolum odasi dahil. */
class DepartmentArchivedCountTest {

    @Test
    void archivedCountIncludesEmptyOpenDepartmentRoomButNotClosedOrEmptyClub() throws Exception {
        try (SessionFactory factory = new Configuration()
                .addAnnotatedClass(Conversation.class)
                .addAnnotatedClass(ConversationMember.class)
                .addAnnotatedClass(ChatRoomLink.class)
                .setProperty("hibernate.connection.url", "jdbc:h2:mem:dept-archived-count;DB_CLOSE_DELAY=-1")
                .setProperty("hibernate.hbm2ddl.auto", "create-drop")
                .buildSessionFactory(); Session session = factory.openSession()) {
            var tx = session.beginTransaction();
            room(session, RoomKind.DEPARTMENT, 1L, null, false); // bos acik bolum odasi: sayilir
            room(session, RoomKind.COMMUNITY, 2L, 10L, false);   // mesajli: sayilir
            room(session, RoomKind.COMMUNITY, 3L, null, false);  // mesajsiz acik kulup odasi: canli page() listeler, sayilir
            room(session, RoomKind.DEPARTMENT, 4L, null, true);  // kapali bolum odasi: sayilmaz
            session.flush();
            String hql = ConversationRepository.class.getMethod("countArchived", Long.class).getAnnotation(Query.class).value();
            long n = session.createQuery(hql, Long.class).setParameter("uid", 7L).getSingleResult();
            assertEquals(3L, n);
            tx.rollback();
        }
    }

    private void room(Session s, RoomKind kind, long ref, Long last, boolean closed) {
        Conversation c = new Conversation();
        c.setCreatedBy(7L);
        c.setType(Conversation.Type.GROUP);
        c.setLastMessageId(last);
        s.persist(c);
        ConversationMember m = new ConversationMember();
        m.setConversationId(c.getId());
        m.setUserId(7L);
        m.setArchivedAt(Instant.now());
        s.persist(m);
        ChatRoomLink link = new ChatRoomLink();
        link.setKind(kind);
        link.setRefId(ref);
        link.setConversationId(c.getId());
        link.setClosed(closed);
        s.persist(link);
    }
}
