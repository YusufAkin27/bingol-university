package edu.bingol.backend.campus;

import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/** Tum sorgular sinirlidir (Pageable): QueryRulesTest. LIKE desenleri cagiran tarafindan KACIRILMIS gelir (kacis {@code \}). */
public interface CampusPlaceRepository extends JpaRepository<CampusPlace, Long> {

    /**
     * Kullanici listesi/arama: yalniz aktif ve silinmemis. {@code category} bos dizge = hepsi. {@code contains} her zaman
     * dolu desen ('%' = hepsi). Siralama: ad onekle baslayanlar, sonra kelime onekiyle baslayanlar, sonra icerenler.
     */
    @Query("""
            select p from CampusPlace p
            where p.active = true and p.deletedAt is null
              and (:category = '' or p.category = :category)
              and (p.nameKey like :contains escape '\\' or p.unitsKey like :contains escape '\\')
            order by case when p.nameKey like :prefix escape '\\' then 0
                          when p.nameKey like :wordPrefix escape '\\' then 1
                          when p.nameKey like :contains escape '\\' then 2
                          else 3 end,
                     p.sortKey, p.nameKey, p.id
            """)
    List<CampusPlace> search(@Param("category") String category, @Param("contains") String contains,
                             @Param("prefix") String prefix, @Param("wordPrefix") String wordPrefix,
                             Pageable pageable);

    Optional<CampusPlace> findByIdAndActiveTrueAndDeletedAtIsNull(Long id);

    Optional<CampusPlace> findByIdAndDeletedAtIsNull(Long id);

    /** Yonetici listesi: pasifler dahil, silinmisler haric; sayfa tabanli. */
    @Query("""
            select p from CampusPlace p
            where p.deletedAt is null
              and (:category = '' or p.category = :category)
              and (p.nameKey like :contains escape '\\' or p.unitsKey like :contains escape '\\')
            order by p.sortKey, p.nameKey, p.id
            """)
    Page<CampusPlace> adminSearch(@Param("category") String category, @Param("contains") String contains,
                                  Pageable pageable);

    long countByDeletedAtIsNull();
}
