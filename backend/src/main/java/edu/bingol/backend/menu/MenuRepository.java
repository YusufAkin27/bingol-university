package edu.bingol.backend.menu;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MenuRepository extends JpaRepository<MenuDay, Long> {

    Optional<MenuDay> findByMenuDate(LocalDate date);

    List<MenuDay> findByMenuDateBetweenOrderByMenuDate(LocalDate from, LocalDate to);
}
