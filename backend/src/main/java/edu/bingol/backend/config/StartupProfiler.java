package edu.bingol.backend.config;

import java.time.Duration;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.boot.context.metrics.buffering.BufferingApplicationStartup;
import org.springframework.boot.context.metrics.buffering.StartupTimeline;
import org.springframework.context.ApplicationListener;
import org.springframework.core.metrics.ApplicationStartup;
import org.springframework.stereotype.Component;

/**
 * Soguk acilis olcumu (A10#12): {@code STARTUP_PROFILE=true} ile {@link BufferingApplicationStartup} acilir
 * ({@link edu.bingol.backend.BingolBackendApplication#main}) ve uygulama hazir olunca en yavas adimlar tek log satir
 * grubuyla yazilir. Varsayilan KAPALI (tampon bellek tutmaz, davranis degismez). Flyway sureleri icin:
 * {@code SELECT version, execution_time FROM flyway_schema_history ORDER BY execution_time DESC LIMIT 15}.
 */
@Component
public class StartupProfiler implements ApplicationListener<ApplicationReadyEvent> {

    private static final Logger log = LoggerFactory.getLogger(StartupProfiler.class);

    /** Tampon boyutu: ~500 bilesen x adimlar icin yeterli; tasarsa en eski adimlar atilmaz, yenileri yazilmaz. */
    static final int BUFFER_CAPACITY = 40_000;

    public static boolean enabled() {
        return Boolean.parseBoolean(System.getenv("STARTUP_PROFILE"));
    }

    /** Ana sinifin kullanacagi {@link ApplicationStartup}; kapaliyken null. */
    public static ApplicationStartup startupOrNull() {
        return enabled() ? new BufferingApplicationStartup(BUFFER_CAPACITY) : null;
    }

    @Override
    public void onApplicationEvent(ApplicationReadyEvent event) {
        ApplicationStartup startup = event.getApplicationContext().getApplicationStartup();
        if (!(startup instanceof BufferingApplicationStartup buffering)) {
            return;
        }
        try {
            for (String line : slowest(buffering.getBufferedTimeline(), 25)) {
                log.info("startup-profile {}", line);
            }
        } catch (RuntimeException e) {
            log.warn("startup-profile yazilamadi: {}", e.toString());
        }
    }

    /** En uzun {@code limit} adim ("sure ms  ad  [etiketler]"), yuvalanmis ust adimlar dahil. */
    static List<String> slowest(StartupTimeline timeline, int limit) {
        List<StartupTimeline.TimelineEvent> events = new ArrayList<>(timeline.getEvents());
        events.sort(Comparator.comparing(StartupTimeline.TimelineEvent::getDuration).reversed());
        List<String> out = new ArrayList<>();
        for (StartupTimeline.TimelineEvent e : events) {
            if (out.size() >= limit) {
                break;
            }
            StringBuilder tags = new StringBuilder();
            e.getStartupStep().getTags().forEach(t -> {
                if (t.getKey().equals("beanName") || t.getKey().equals("postProcessor") || t.getKey().equals("beanType")) {
                    tags.append(' ').append(t.getKey()).append('=').append(t.getValue());
                }
            });
            out.add(String.format("%6d ms  %s%s", e.getDuration().compareTo(Duration.ZERO) < 0 ? 0 : e.getDuration().toMillis(),
                    e.getStartupStep().getName(), tags));
        }
        return out;
    }
}
