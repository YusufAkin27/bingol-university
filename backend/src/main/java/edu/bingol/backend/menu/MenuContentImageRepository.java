package edu.bingol.backend.menu;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MenuContentImageRepository extends JpaRepository<MenuContentImage, String> {

    /** Cagiranlar ozet listesini sinirli parcalarla verir. */
    List<MenuContentImage> findByContentHashIn(Collection<String> hashes);
}
