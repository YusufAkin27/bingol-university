package edu.bingol.backend.config;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * {@code @Scheduled} islerinin acilmasi tek yerde ve ayarlidir: {@code app.scheduling.enabled} (varsayilan {@code true},
 * yani uretim davranisi degismez). Test profili kapatir: her Spring baglami ~50 zamanlayici isi baslatir (mail/push/presence
 * yoklamalari, Redis olmadan her turda baglanti hatasi) ve onbellekte tutulan tum baglamlarda test sonuna kadar kosar;
 * isleri dogrudan cagiran testler etkilenmez.
 */
@Configuration(proxyBeanMethods = false)
@ConditionalOnProperty(name = "app.scheduling.enabled", havingValue = "true", matchIfMissing = true)
@EnableScheduling
public class SchedulingEnabledConfig {
}
