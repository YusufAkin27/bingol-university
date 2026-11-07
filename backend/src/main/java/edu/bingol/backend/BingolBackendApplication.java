package edu.bingol.backend;

import edu.bingol.backend.config.StartupProfiler;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

// @Scheduled etkinlestirmesi config/SchedulingEnabledConfig'te (app.scheduling.enabled; testlerde kapali)
@SpringBootApplication
@ConfigurationPropertiesScan
public class BingolBackendApplication {

    public static void main(String[] args) {
        SpringApplication app = new SpringApplication(BingolBackendApplication.class);
        // STARTUP_PROFILE=true: soguk acilis adimlari olculur ve hazir olunca loglanir (varsayilan kapali)
        var startup = StartupProfiler.startupOrNull();
        if (startup != null) {
            app.setApplicationStartup(startup);
        }
        app.run(args);
    }
}
