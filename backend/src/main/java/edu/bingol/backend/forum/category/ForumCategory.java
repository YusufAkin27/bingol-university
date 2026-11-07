package edu.bingol.backend.forum.category;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Forum kategorisi (yonetici tarafindan yonetilir; arsivlenen kategoriye yeni konu acilamaz). */
@Entity
@Table(name = "forum_category")
@Getter
@Setter
public class ForumCategory {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 60, unique = true)
    private String slug;

    @Column(nullable = false, length = 80)
    private String nameTr;

    @Column(nullable = false, length = 80)
    private String nameEn;

    @Column(nullable = false, length = 80)
    private String nameAr;

    /** Mantiksal grup ({@code forum_category_group.group_key}); bos = grupsuz (listede "Diger"). */
    @Column(length = 30)
    private String groupKey;

    @Column(nullable = false)
    private int sortOrder;

    @Column(nullable = false)
    private boolean active = true;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
