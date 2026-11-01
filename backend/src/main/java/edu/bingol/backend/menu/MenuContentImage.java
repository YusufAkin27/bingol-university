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

/** Menu icerigine (yemek listesi ozeti) bagli gorsel: ayni menu ayni gorseli alir, menu degisince eslesme kalmaz. */
@Entity
@EntityListeners(CacheInvalidationListener.class)
@Table(name = "menu_content_image")
@Getter
@Setter
public class MenuContentImage {

    /** {@link MenuContentImages#hash} ciktisi. */
    @Id
    @Column(length = 64)
    private String contentHash;

    @Column(nullable = false, length = 500)
    private String imageUrl;

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();
}
