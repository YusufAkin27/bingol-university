package edu.bingol.backend.forum.poll;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ForumPollRepository extends JpaRepository<ForumPoll, Long> {

    Optional<ForumPoll> findByTopicId(Long topicId);

    List<ForumPoll> findByTopicIdIn(Collection<Long> topicIds);
}
