package edu.bingol.backend.menu;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MenuRepository extends JpaRepository<MenuDay, Long> {

    Optional<MenuDay> findByMenuDate(LocalDate date);

    List<MenuDay> findByMenuDateBetweenOrderByMenuDate(LocalDate from, LocalDate to);

    /** Yakalama isi ve bakim karari icin: bir aralikta kac gunluk menu var (COUNT, satir cekmez). */
    long countByMenuDateBetween(LocalDate from, LocalDate to);

    /** Eski gorsel alanini tasimak icin (yalniz gorselli gunler: kucuk kume). */
    List<MenuDay> findByImageUrlIsNotNull();
}
