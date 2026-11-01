package edu.bingol.backend.unitnews;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UnitSourceRepository extends JpaRepository<UnitSource, String> {

    /** Sabit, kucuk tablo (23 kaynak). */
    List<UnitSource> findAllByOrderByNameAsc();

    List<UnitSource> findByEnabledTrueOrderByCodeAsc();
}
