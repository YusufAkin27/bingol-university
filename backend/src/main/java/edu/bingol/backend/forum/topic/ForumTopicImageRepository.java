package edu.bingol.backend.forum.topic;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ForumTopicImageRepository extends JpaRepository<ForumTopicImage, Long> {

    /** Konularin gorselleri (konu, sira, kimlik sirali); ust sinir: konu basina 4 gorsel x en fazla 60 konu. */
    @Query("SELECT i FROM ForumTopicImage i WHERE i.topicId IN :ids ORDER BY i.topicId, i.position, i.id")
    List<ForumTopicImage> forTopics(@Param("ids") Collection<Long> topicIds);
}
