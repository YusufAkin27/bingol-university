package edu.bingol.backend.moderation.profanity;

import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ProfanityTermRepository extends JpaRepository<ProfanityTerm, Long> {

    boolean existsByKindAndTermNormalized(ProfanityTerm.Kind kind, String termNormalized);

    long countByKind(ProfanityTerm.Kind kind);

    List<ProfanityTerm> findAllByOrderByIdAsc();

    List<ProfanityTerm> findByKindOrderByIdAsc(ProfanityTerm.Kind kind);

    /** q: kucuk harfli '!' kacisli LIKE deseni ya da "" (filtre yok). */
    @Query("SELECT t FROM ProfanityTerm t WHERE t.kind = :kind AND (:q = '' OR LOWER(t.term) LIKE :q ESCAPE '!') "
            + "AND (:cursor IS NULL OR t.id < :cursor) ORDER BY t.id DESC")
    List<ProfanityTerm> page(@Param("kind") ProfanityTerm.Kind kind, @Param("q") String q,
                             @Param("cursor") Long cursor, Pageable pageable);
}
