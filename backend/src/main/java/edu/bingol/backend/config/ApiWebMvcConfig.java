package edu.bingol.backend.config;

import edu.bingol.backend.accessban.DeviceSeenInterceptor;
import edu.bingol.backend.admin.AuditInterceptor;
import edu.bingol.backend.analytics.ActivityInterceptor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/** MVC interceptor kayitlari: yonetici denetim kaydi ve kimlikli kullanici aktiflik takibi. */
@Configuration
public class ApiWebMvcConfig implements WebMvcConfigurer {

    private final AuditInterceptor audit;
    private final ActivityInterceptor activity;
    private final DeviceSeenInterceptor deviceSeen;

    public ApiWebMvcConfig(AuditInterceptor audit, ActivityInterceptor activity, DeviceSeenInterceptor deviceSeen) {
        this.audit = audit;
        this.activity = activity;
        this.deviceSeen = deviceSeen;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(audit).addPathPatterns("/api/admin/**");
        registry.addInterceptor(activity).addPathPatterns("/api/**");
        // Kullanici engeli (ikinci savunma) + cihaz/IP gecmisi; yonetici uclari haric
        registry.addInterceptor(deviceSeen).addPathPatterns("/api/**").excludePathPatterns("/api/admin/**");
    }
}
