package edu.bingol.backend.auth.session;

import edu.bingol.backend.export.DataExporter;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * KVKK disa aktarim: kullanicinin kendi oturum/cihaz kayitlari ("Cihazlarim"). Ham IP ve ham cihaz kimligi/ozeti
 * YOKTUR; yalniz cihaz adi, platform, surum, maskeli IP ve zamanlar.
 */
@Configuration
class SessionExporters {

    @Bean
    DataExporter sessionsExporter(UserSessionService sessions) {
        return DataExporter.of("sessions", uid -> {
            List<Map<String, Object>> items = sessions.active(uid).stream().map(s -> {
                Map<String, Object> m = new LinkedHashMap<>();
                m.put("client", s.getClient());
                m.put("platform", s.getPlatform());
                m.put("deviceName", s.getDeviceName());
                m.put("appVersion", s.getAppVersion());
                m.put("ipMasked", s.getIpMasked());
                m.put("createdAt", s.getCreatedAt().toString());
                m.put("lastUsedAt", s.getLastUsedAt().toString());
                return m;
            }).toList();
            Map<String, Object> out = new LinkedHashMap<>();
            out.put("activeSessionCount", items.size());
            out.put("sessions", items);
            return out;
        });
    }
}
