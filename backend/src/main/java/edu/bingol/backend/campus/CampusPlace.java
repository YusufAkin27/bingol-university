package edu.bingol.backend.campus;

import edu.bingol.backend.common.cache.CacheInvalidationListener;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/**
 * Kampus ici bir yer (bina, yemekhane, kapi...). Yalniz bu tablodaki kayitlar kullaniciya sunulur (kampus disi arama yok).
 * Kisisel veri tutmaz. Sema: V1200.
 */
@Entity
@EntityListeners(CacheInvalidationListener.class)
@Table(name = "campus_place")
@Getter
@Setter
public class CampusPlace {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 120)
    private String name;

    /** {@link CampusText#normalize}: Turkce duyarsiz arama anahtari. */
    @Column(nullable = false, length = 160)
    private String nameKey;

    /** {@link CampusCategory#key()}. */
    @Column(nullable = false, length = 20)
    private String category;

    @Column(nullable = false)
    private double lat;

    @Column(nullable = false)
    private double lng;

    @Column(length = 300)
    private String summary;

    /** Medya hattindaki herkese acik goreli URL (/files/covers/...); yoksa null. */
    @Column(length = 200)
    private String photoKey;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String unitsJson = "[]";

    @Column(nullable = false, length = 2000)
    private String unitsKey = "";

    @Column(columnDefinition = "TEXT")
    private String footprintJson;

    @Column(nullable = false)
    private int sortKey;

    @Column(nullable = false)
    private boolean active = true;

    /** Birimin resmi web sayfasi (https, bingol.edu.tr alt alani) ya da null. */
    @Column(length = 300)
    private String webUrl;

    /** Ana yerleske disi birim: ana harita sinirlarinda gosterilmez. */
    @Column(nullable = false)
    private boolean remote;

    /** Tohum kaynagi ("harita:19"); elle eklenen yerlerde null. */
    @Column(length = 40)
    private String sourceRef;

    /** Yumusak silme zamani; dolu kayit hicbir uctan gorunmez. */
    private Instant deletedAt;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();
}
