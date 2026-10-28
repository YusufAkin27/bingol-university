package edu.bingol.backend.moderation.admin;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ModerationReasonTemplateRepository extends JpaRepository<ModerationReasonTemplate, Long> {

    List<ModerationReasonTemplate> findByKindOrderBySortOrderAscIdAsc(String kind);

    Optional<ModerationReasonTemplate> findByKindAndCode(String kind, String code);

    long countByKind(String kind);
}
