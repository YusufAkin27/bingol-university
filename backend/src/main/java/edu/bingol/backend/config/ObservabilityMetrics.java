package edu.bingol.backend.config;

import edu.bingol.backend.mail.MailService;
import edu.bingol.backend.notification.PushDispatcher;
import io.micrometer.core.instrument.FunctionCounter;
import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.binder.MeterBinder;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.LongSupplier;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.user.SimpUser;
import org.springframework.messaging.simp.user.SimpUserRegistry;

/**
 * Ozel uygulama metrikleri (Prometheus). Var olan sayaclari okur; is mantigina dokunmaz.
 * Giris basarisizligi, engellenen erisim, gonderi/yorum ve medya yukleme sureleri icin ayri sayac yoktur:
 * bunlar {@code http_server_requests_seconds_*} (uri/status/method etiketleri) uzerinden sorgulanir
 * (bkz. docs/OBSERVABILITY.md).
 */
@Configuration(proxyBeanMethods = false)
public class ObservabilityMetrics {

    /** Mail kuyrugu sayilari her kazimada DB'ye vurmasin diye kisa sure onbellege alinir. */
    static final long MAIL_CACHE_MS = 15_000;

    @Bean
    MeterBinder pushMetrics(ObjectProvider<PushDispatcher> push) {
        return registry -> {
            PushDispatcher p = push.getIfAvailable();
            if (p == null) {
                return;
            }
            FunctionCounter.builder("bu.push.delivered", p, PushDispatcher::deliveredCount)
                    .description("FCM'e basariyla iletilen push sayisi").register(registry);
            FunctionCounter.builder("bu.push.failures", p, PushDispatcher::failureCount)
                    .description("Basarisiz push gonderimi (kuyruk dolu dahil)").register(registry);
            FunctionCounter.builder("bu.push.dropped", p, PushDispatcher::droppedCount)
                    .description("Kuyruk dolu oldugu icin dusurulen push (cihaz basina)").register(registry);
            FunctionCounter.builder("bu.push.retries", p, PushDispatcher::retryCount)
                    .description("Push yeniden deneme sayisi").register(registry);
        };
    }

    @Bean
    MeterBinder mailOutboxMetrics(ObjectProvider<MailService> mail) {
        return registry -> {
            MailService m = mail.getIfAvailable();
            if (m == null) {
                return;
            }
            CachedStats cache = new CachedStats(m, System::currentTimeMillis);
            for (String status : new String[] {"pending", "failed", "dead"}) {
                Gauge.builder("bu.mail.outbox", cache, c -> c.value(status))
                        .tag("status", status).description("mail_outbox kayit sayisi (duruma gore)")
                        .register(registry);
            }
        };
    }

    @Bean
    MeterBinder websocketMetrics(ObjectProvider<SimpUserRegistry> users) {
        return registry -> {
            SimpUserRegistry r = users.getIfAvailable();
            if (r == null) {
                return;
            }
            Gauge.builder("bu.websocket.users", r, SimpUserRegistry::getUserCount)
                    .description("Bu sunucuda bagli STOMP kullanicisi").register(registry);
            Gauge.builder("bu.websocket.sessions", r, ObservabilityMetrics::sessions)
                    .description("Bu sunucuda acik STOMP oturumu").register(registry);
        };
    }

    static double sessions(SimpUserRegistry r) {
        long n = 0;
        for (SimpUser u : r.getUsers()) {
            n += u.getSessions().size();
        }
        return n;
    }

    /** MailService.queueStats() sonucunu kisa sure tutar. */
    static final class CachedStats {
        private record Snap(long at, MailService.QueueStats stats) {}

        private final MailService mail;
        private final LongSupplier clock;
        private final AtomicReference<Snap> snap = new AtomicReference<>();

        CachedStats(MailService mail, LongSupplier clock) {
            this.mail = mail;
            this.clock = clock;
        }

        double value(String status) {
            long now = clock.getAsLong();
            Snap s = snap.get();
            if (s == null || now - s.at() > MAIL_CACHE_MS) {
                try {
                    s = new Snap(now, mail.queueStats());
                    snap.set(s);
                } catch (RuntimeException e) {
                    // DB gecici erisilemezse kazima patlamasin: son bilinen deger (yoksa NaN)
                    if (s == null) {
                        return Double.NaN;
                    }
                }
            }
            MailService.QueueStats q = s.stats();
            return switch (status) {
                case "pending" -> q.pending();
                case "failed" -> q.failed();
                case "dead" -> q.dead();
                default -> Double.NaN;
            };
        }
    }
}
