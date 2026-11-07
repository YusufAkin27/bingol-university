package edu.bingol.backend.forum.category;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/** Forum kategori grubu (V1480): kategori secicide bolum basligi. Sabit anahtar, uc dilde ad, sira. */
@Entity
@Table(name = "forum_category_group")
@Getter
@Setter
public class ForumCategoryGroup {

    @Id
    @Column(name = "group_key", length = 30)
    private String groupKey;

    @Column(nullable = false, length = 80)
    private String nameTr;

    @Column(nullable = false, length = 80)
    private String nameEn;

    @Column(nullable = false, length = 80)
    private String nameAr;

    @Column(nullable = false)
    private int sortOrder;
}
