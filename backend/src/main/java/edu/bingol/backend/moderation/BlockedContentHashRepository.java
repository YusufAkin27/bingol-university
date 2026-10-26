package edu.bingol.backend.moderation;

import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface BlockedContentHashRepository extends JpaRepository<BlockedContentHash, String> {

    @Query("SELECT h FROM BlockedContentHash h WHERE (:cursor IS NULL OR h.sha256 > :cursor) ORDER BY h.sha256 ASC")
    List<BlockedContentHash> page(@Param("cursor") String cursor, Pageable pageable);
}
