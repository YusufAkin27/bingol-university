package edu.bingol.backend.auth.twofactor;

import edu.bingol.backend.export.DataExporter;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * KVKK disa aktarim: kullanicinin kendi 2FA durumu ve guvenilen cihaz etiketleri. Ham cihaz kimligi de cihaz
 * ozeti de (HMAC) YOKTUR; yalniz etiket (platform/surum) ve zamanlar.
 */
@Configuration
class TwoFactorExporters {

    @Bean
    DataExporter twoFactorExporter(UserRepository users, TwoFactorDeviceRepository devices) {
        return DataExporter.of("twoFactor", uid -> {
            User u = users.findById(uid).orElse(null);
            List<Map<String, Object>> items = devices.findByUserIdOrderByLastUsedAtDesc(uid).stream().map(d -> {
                Map<String, Object> m = new LinkedHashMap<>();
                m.put("label", d.getLabel());
                m.put("createdAt", d.getCreatedAt().toString());
                m.put("lastUsedAt", d.getLastUsedAt().toString());
                return m;
            }).toList();
            Map<String, Object> out = new LinkedHashMap<>();
            out.put("enabled", u != null && u.isTwoFactorEnabled());
            out.put("enabledAt", u == null || u.getTwoFactorEnabledAt() == null ? null : u.getTwoFactorEnabledAt().toString());
            out.put("trustedDeviceCount", items.size());
            out.put("trustedDevices", items);
            return out;
        });
    }
}
