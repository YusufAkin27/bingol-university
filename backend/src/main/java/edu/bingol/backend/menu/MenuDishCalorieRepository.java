package edu.bingol.backend.menu;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MenuDishCalorieRepository extends JpaRepository<MenuDishCalorie, String> {

    /** Cagiranlar anahtar listesini sinirli parcalarla verir. */
    List<MenuDishCalorie> findByItemKeyIn(Collection<String> keys);
}
