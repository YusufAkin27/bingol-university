package edu.bingol.backend.menu;

import jakarta.persistence.Column;
import edu.bingol.backend.common.cache.CacheInvalidationListener;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.Instant;
import java.time.LocalDate;
import lombok.Getter;
import lombok.Setter;

/**
 * Bir gunun bir yemegi icin yonetici kalorisi. menu_day'den bagimsizdir: kaynak site senkronu bu tabloya dokunmaz,
 * (menuDate, itemKey) anahtari sayesinde satir yeniden yazilsa bile kalori korunur.
 */
@Entity
@EntityListeners(CacheInvalidationListener.class)
@Table(name = "menu_item_calorie", uniqueConstraints = @UniqueConstraint(columnNames = {"menuDate", "itemKey"}))
@Getter
@Setter
public class MenuItemCalorie {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private LocalDate menuDate;

    /** {@link MenuItemKey#of} ile normalize edilmis yemek adi. */
    @Column(nullable = false, length = 300)
    private String itemKey;

    /** Girildigi andaki gorunen yemek adi (denetim/okunurluk). */
    @Column(nullable = false, length = 300)
    private String itemName;

    @Column(nullable = false)
    private int kcal;

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();

    @Column(length = 80)
    private String updatedBy;
}
