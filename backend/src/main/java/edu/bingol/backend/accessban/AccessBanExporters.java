package edu.bingol.backend.accessban;

import edu.bingol.backend.export.DataExporter;
import java.util.List;
import java.util.Map;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** KVKK disa aktarim: kullanicinin kendi cihaz/IP gecmisi (ham cihaz kimligi YOK; yalnizca 8 karakterlik ozet). */
@Configuration
class AccessBanExporters {

    @Bean
    DataExporter accessHistoryExporter(UserDeviceLogRepository logs) {
        return DataExporter.of("accessHistory", uid -> {
            List<Map<String, Object>> items = logs.findByUserIdOrderByLastSeenAtDesc(uid).stream().map(l -> {
                Map<String, Object> m = new java.util.LinkedHashMap<>();
                m.put("deviceSummary", UserDeviceLog.NO_DEVICE.equals(l.getDeviceHash()) ? null
                        : ClientContexts.shortHash(l.getDeviceHash()));
                m.put("platform", l.getPlatform());
                m.put("appVersion", l.getAppVersion());
                m.put("ip", l.getIp());
                m.put("firstSeenAt", l.getFirstSeenAt().toString());
                m.put("lastSeenAt", l.getLastSeenAt().toString());
                m.put("lastEvent", l.getLastEvent());
                m.put("seenCount", l.getSeenCount());
                return m;
            }).toList();
            return Map.of("retentionDays", 90, "count", items.size(), "items", items);
        });
    }
}
