package edu.bingol.backend.config;

import edu.bingol.backend.accessban.DeviceSeenInterceptor;
import edu.bingol.backend.admin.AdminGuardInterceptor;
import edu.bingol.backend.admin.AuditInterceptor;
import edu.bingol.backend.admin.rbac.AdminPermissionInterceptor;
import edu.bingol.backend.analytics.ActivityInterceptor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/** MVC interceptor kayitlari: yonetici denetim kaydi ve kimlikli kullanici aktiflik takibi. */
@Configuration
public class ApiWebMvcConfig implements WebMvcConfigurer {

    private final AuditInterceptor audit;
    private final AdminGuardInterceptor adminGuard;
    private final AdminPermissionInterceptor adminPermission;
    private final ActivityInterceptor activity;
    private final DeviceSeenInterceptor deviceSeen;

    public ApiWebMvcConfig(AuditInterceptor audit, AdminGuardInterceptor adminGuard,
                           AdminPermissionInterceptor adminPermission, ActivityInterceptor activity,
                           DeviceSeenInterceptor deviceSeen) {
        this.audit = audit;
        this.adminGuard = adminGuard;
        this.adminPermission = adminPermission;
        this.activity = activity;
        this.deviceSeen = deviceSeen;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(audit).addPathPatterns("/api/admin/**");
        // P16 izin matrisi: reddedilen istek de denetim kaydina girer; hiz siniri tuketilmeden once calisir
        registry.addInterceptor(adminPermission).addPathPatterns("/api/admin/**");
        // Yazma hiz siniri + kritik islemlerde sebep zorunlulugu (denetimden SONRA: reddedilen istek de kayda girer)
        registry.addInterceptor(adminGuard).addPathPatterns("/api/admin/**");
        registry.addInterceptor(activity).addPathPatterns("/api/**");
        // Kullanici engeli (ikinci savunma) + cihaz/IP gecmisi; yonetici uclari haric
        registry.addInterceptor(deviceSeen).addPathPatterns("/api/**").excludePathPatterns("/api/admin/**");
    }
}
