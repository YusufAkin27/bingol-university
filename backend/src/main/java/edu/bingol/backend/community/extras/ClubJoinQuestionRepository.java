package edu.bingol.backend.community.extras;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ClubJoinQuestionRepository extends JpaRepository<ClubJoinQuestion, Long> {

    List<ClubJoinQuestion> findByCommunityIdOrderBySortOrderAsc(Long communityId);
}
