package edu.bingol.backend.appinfo;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Yoneticinin duzenleyebildigi uygulama ayari (anahtar-deger). Anahtarlar migration ile tohumlanir. */
@Entity
@Table(name = "app_setting")
@Getter
@Setter
public class AppSetting {

    @Id
    @Column(name = "setting_key", length = 64)
    private String key;

    @Column(name = "setting_value", nullable = false, length = 1000)
    private String value = "";

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();
}
