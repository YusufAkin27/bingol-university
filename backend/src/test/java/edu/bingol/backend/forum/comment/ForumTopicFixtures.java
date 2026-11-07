package edu.bingol.backend.forum.comment;

import edu.bingol.backend.forum.topic.ForumTopic;
import jakarta.persistence.EntityManager;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/** Test yardimcisi: A'nin ForumTopic entity'siyle konu ekler (A'nin servisleri olmadan). */
final class ForumTopicFixtures {

    private ForumTopicFixtures() {}

    static ForumTopic topic(EntityManager em, PlatformTransactionManager tm, Long authorId, boolean anonymous) {
        ForumTopic t = new ForumTopic();
        t.setUserId(authorId);
        t.setCategoryId(1L);
        t.setTitle("Baslik");
        t.setBody("Aciklama");
        t.setAnonymous(anonymous);
        new TransactionTemplate(tm).executeWithoutResult(st -> {
            em.persist(t);
            em.flush();
        });
        return t;
    }
}
