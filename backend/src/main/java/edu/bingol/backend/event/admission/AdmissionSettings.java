package edu.bingol.backend.event.admission;

import edu.bingol.backend.appinfo.AppSettingRepository;
import org.springframework.stereotype.Component;

/** Etkinlik acma/alim ayarlari (app_setting). Gecersiz/eksik deger varsayilana duser; yonetici panelinden degisir. */
@Component
public class AdmissionSettings {

    static final String REQUIRE_APPROVAL = "events_require_approval";
    static final String MAX_OPEN = "event_max_open_per_user";
    static final String DAILY_LIMIT = "event_daily_create_limit";

    private final AppSettingRepository repo;

    public AdmissionSettings(AppSettingRepository repo) {
        this.repo = repo;
    }

    /** Varsayilan false: bagimsiz etkinlikler yonetici onayi beklemez. */
    public boolean requireApproval() {
        return repo.findById(REQUIRE_APPROVAL).map(s -> "true".equalsIgnoreCase(s.getValue().trim())).orElse(false);
    }

    /**
     * Ayni anda acik etkinlik ust siniri; 0 = sinirsiz. FINAL-ALL: varsayilan 0. P05 sinirlari uygulamaya aldi
     * (K14) ama eski mobil surumler (2.0.5/2.0.6) bu 409/429 yanitlarini beklemiyordu; sinir yonetici ayariyla
     * (`app_setting` {@value #MAX_OPEN}) bilincli acilir, kod varsayilani eski davranisi korur.
     */
    public int maxOpenPerUser() {
        return intOf(MAX_OPEN, 0);
    }

    /** Gunluk (Europe/Istanbul) acma siniri; 0 = sinirsiz (varsayilan 0, bkz. {@link #maxOpenPerUser()}). */
    public int dailyCreateLimit() {
        return intOf(DAILY_LIMIT, 0);
    }

    private int intOf(String key, int def) {
        return repo.findById(key).map(s -> {
            try {
                return Math.max(0, Integer.parseInt(s.getValue().trim()));
            } catch (NumberFormatException e) {
                return def;
            }
        }).orElse(def);
    }
}
