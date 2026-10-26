package edu.bingol.backend.notification;

import edu.bingol.backend.export.DataExporter;
import edu.bingol.backend.notification.dto.NotificationDtos.NotificationView;
import java.util.List;
import java.util.Map;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * KVKK disa aktarim: ayrintili tercihler (sessiz saat + alt turler), bildirim kutusu (son 500) ve cihazlar.
 * Cihaz token'lari disari verilmez (yalnizca platform ve son 6 karakter).
 */
@Configuration
class NotificationExporters {

    @Bean
    DataExporter notificationSettingsExporter(NotificationPrefService prefs) {
        return DataExporter.of("notificationSettings", prefs::get);
    }

    @Bean
    DataExporter notificationInboxExporter(NotificationRepository notifications) {
        return DataExporter.of("notifications", uid -> {
            List<NotificationView> items = notifications.findTop500ByUserIdOrderByIdDesc(uid).stream()
                    .map(NotificationView::of).toList();
            return Map.of("count", items.size(), "items", items);
        });
    }

    @Bean
    DataExporter notificationDevicesExporter(DeviceService devices) {
        return DataExporter.of("devices", devices::list);
    }
}
