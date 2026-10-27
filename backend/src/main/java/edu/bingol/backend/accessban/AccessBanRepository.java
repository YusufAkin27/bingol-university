package edu.bingol.backend.accessban;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AccessBanRepository extends JpaRepository<AccessBan, Long> {

    /** Onbellek yuklemesi: etkin ve suresi dolmamis engeller. */
    @Query("SELECT b FROM AccessBan b WHERE b.active = TRUE AND (b.expiresAt IS NULL OR b.expiresAt > :now)")
    List<AccessBan> findLive(@Param("now") Instant now);

    @Query("SELECT b FROM AccessBan b WHERE b.kind = :kind AND b.banValue = :value AND b.active = TRUE "
            + "AND (b.expiresAt IS NULL OR b.expiresAt > :now)")
    Optional<AccessBan> findLiveByValue(@Param("kind") String kind, @Param("value") String value,
                                        @Param("now") Instant now);

    @Query("SELECT b.banValue FROM AccessBan b WHERE b.kind = :kind AND b.banValue IN :values AND b.active = TRUE "
            + "AND (b.expiresAt IS NULL OR b.expiresAt > :now)")
    List<String> findLiveValues(@Param("kind") String kind, @Param("values") Collection<String> values,
                                @Param("now") Instant now);
}
