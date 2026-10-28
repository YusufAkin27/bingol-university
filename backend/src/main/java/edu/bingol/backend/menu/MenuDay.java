package edu.bingol.backend.menu;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.LocalDate;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(uniqueConstraints = @UniqueConstraint(columnNames = "menuDate"))
@Getter
@Setter
public class MenuDay {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private LocalDate menuDate;

    /** Yemekler, satir sonu ile ayrilmis. */
    @Column(nullable = false, length = 1000)
    private String items;

    /** Istege bagli menu fotografi (/files/covers/...); senkron dokunmaz. */
    @Column(length = 500)
    private String imageUrl;
}
