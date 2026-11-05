package edu.bingol.backend.auth.oauth;

import edu.bingol.backend.export.DataExporter;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * KVKK disa aktarim: hesaba bagli Google/Apple kimlikleri (saglayici, saglayicidaki e-posta, baglanma/son giris ani).
 * Saglayici kullanici kimligi (sub) disari VERILMEZ (kimlik dogrulama ayrintisi; kullaniciya yararsiz, sizma riski).
 */
@Configuration
class OAuthExporters {

    @Bean
    DataExporter authIdentitiesExporter(AuthIdentityRepository identities) {
        return DataExporter.of("authIdentities", uid -> {
            List<Map<String, Object>> items = identities.findByUserIdOrderByCreatedAtAsc(uid).stream().map(i -> {
                Map<String, Object> m = new LinkedHashMap<>();
                m.put("provider", i.getProvider().name());
                m.put("email", i.getEmail());
                m.put("emailIsPrivate", i.isEmailIsPrivate());
                m.put("linkedAt", i.getCreatedAt().toString());
                m.put("lastLoginAt", i.getLastLoginAt() == null ? null : i.getLastLoginAt().toString());
                return m;
            }).toList();
            return Map.of("identities", items);
        });
    }
}
