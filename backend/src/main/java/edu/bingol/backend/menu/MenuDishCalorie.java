package edu.bingol.backend.menu;

import edu.bingol.backend.common.cache.CacheInvalidationListener;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/**
 * Yemek adina bagli son bilinen kalori: tarihe ozel satiri ({@link MenuItemCalorie}) olmayan gunlerde, orn. senkronla
 * gelen gelecek ay menusunde, ayni isimli yemegin kalorisi bununla dolar.
 */
@Entity
@EntityListeners(CacheInvalidationListener.class)
@Table(name = "menu_dish_calorie")
@Getter
@Setter
public class MenuDishCalorie {

    /** {@link MenuItemKey#of} ile normalize edilmis yemek adi. */
    @Id
    @Column(length = 300)
    private String itemKey;

    @Column(nullable = false, length = 300)
    private String itemName;

    @Column(nullable = false)
    private int kcal;

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();

    @Column(length = 80)
    private String updatedBy;
}
