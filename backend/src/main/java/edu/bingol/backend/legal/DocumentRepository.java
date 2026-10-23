package edu.bingol.backend.legal;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface DocumentRepository extends JpaRepository<LegalDocument, Long> {

    List<LegalDocument> findByActiveTrue();

    Optional<LegalDocument> findByTypeAndLangAndActiveTrue(LegalType type, String lang);

    List<LegalDocument> findByTypeAndLangOrderByVersionDesc(LegalType type, String lang);

    @Query("SELECT COALESCE(MAX(d.version), 0) FROM LegalDocument d WHERE d.type = :type")
    int maxVersion(@Param("type") LegalType type);

    @Transactional
    @Modifying
    @Query("UPDATE LegalDocument d SET d.active = false WHERE d.type = :type AND d.active = true")
    int deactivate(@Param("type") LegalType type);
}
