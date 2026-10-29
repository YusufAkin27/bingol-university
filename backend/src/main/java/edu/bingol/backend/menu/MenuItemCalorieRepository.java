package edu.bingol.backend.menu;

import java.time.LocalDate;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MenuItemCalorieRepository extends JpaRepository<MenuItemCalorie, Long> {

    List<MenuItemCalorie> findByMenuDate(LocalDate date);

    /** Sinirli aralik (cagiranlar aralik sinirini zorlar: ay ya da en cok 366 gun). */
    List<MenuItemCalorie> findByMenuDateBetween(LocalDate from, LocalDate to);
}
