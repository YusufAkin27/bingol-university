package edu.bingol.backend.unitnews;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.Getter;
import lombok.Setter;

/** Alt sitenin bir bolumu (/bolumler/&lt;slug&gt;/); nameKey profildeki bolumle eslesme anahtaridir. */
@Entity
@Table(name = "unit_department", uniqueConstraints = @UniqueConstraint(columnNames = {"sourceCode", "slug"}))
@Getter
@Setter
public class UnitDepartment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 20)
    private String sourceCode;

    @Column(nullable = false, length = 160)
    private String slug;

    @Column(nullable = false, length = 200)
    private String name;

    @Column(nullable = false, length = 200)
    private String nameKey;

    /** Bolumun kendi duyuru akisi (/bolumler_/x/duyurular/); yoksa null. */
    @Column(length = 200)
    private String feedPath;
}
