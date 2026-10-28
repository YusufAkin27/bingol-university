package edu.bingol.backend.devseed;

import org.springframework.context.annotation.Profile;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

/** Üretimde tohum profili açıksa uygulama başlamaz (bilinen test şifreli hesaplar üretime sızmasın). */
@Component
@Profile("prod")
public class DevSeedProdGuard {

    public DevSeedProdGuard(Environment env) {
        for (String p : env.getActiveProfiles()) {
            if ("seed".equalsIgnoreCase(p)) {
                throw new IllegalStateException("Uretimde 'seed' profili acik olamaz (SPRING_PROFILES_ACTIVE).");
            }
        }
    }
}
