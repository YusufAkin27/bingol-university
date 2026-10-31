package edu.bingol.backend.profile;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Gorunen ad degisim gecmisi (T-060, V993): bekleme suresi hesabi + rapor izi eslestirme. Hesap silinince temizlenir. */
@Entity
@Table(name = "display_name_history")
@Getter
@Setter
public class DisplayNameChange {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false, length = 80)
    private String oldName;

    @Column(nullable = false, length = 80)
    private String newName;

    @Column(nullable = false)
    private Instant changedAt = Instant.now();
}
