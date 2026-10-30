package edu.bingol.backend.community.category;

import jakarta.persistence.Column;
import edu.bingol.backend.common.cache.CacheInvalidationListener;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Yonetici panelinden yonetilen kulup kategorisi. community.category bu tablonun key degerini tasir. */
@Entity
@EntityListeners(CacheInvalidationListener.class)
@Table(name = "community_category")
@Getter
@Setter
public class CommunityCategory {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** Degismez, benzersiz anahtar (kulup satirinda saklanan deger). */
    @Column(name = "category_key", nullable = false, unique = true, length = 40)
    private String key;

    @Column(nullable = false, length = 80)
    private String nameTr;

    @Column(nullable = false, length = 80)
    private String nameEn;

    @Column(nullable = false, length = 80)
    private String nameAr;

    @Column(length = 40)
    private String icon;

    @Column(nullable = false)
    private int sortOrder;

    @Column(nullable = false)
    private boolean active = true;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();
}
