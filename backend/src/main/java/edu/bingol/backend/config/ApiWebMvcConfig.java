package edu.bingol.backend.config;

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

    public ApiWebMvcConfig(AuditInterceptor audit, ActivityInterceptor activity) {
        this.audit = audit;
        this.activity = activity;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(audit).addPathPatterns("/api/admin/**");
        registry.addInterceptor(activity).addPathPatterns("/api/**");
    }
}
