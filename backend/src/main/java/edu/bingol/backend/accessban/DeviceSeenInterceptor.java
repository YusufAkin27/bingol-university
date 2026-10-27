package edu.bingol.backend.accessban;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * Kimlikli (JWT) /api/** isteklerinde: (1) kullanici engeli kontrolu (token iptali ile birlikte ikinci savunma;
 * onbellek gecikmesine karsi), (2) cihaz/IP kaydinin seyrek ve asenkron yazimi.
 */
@Component
public class DeviceSeenInterceptor implements HandlerInterceptor {

    private final ClientContexts contexts;
    private final AccessGuard guard;
    private final DeviceLogService devices;

    public DeviceSeenInterceptor(ClientContexts contexts, AccessGuard guard, DeviceLogService devices) {
        this.contexts = contexts;
        this.guard = guard;
        this.devices = devices;
    }

    @Override
    public boolean preHandle(HttpServletRequest req, HttpServletResponse res, Object handler) {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        if (a != null && a.getPrincipal() instanceof Long uid) {
            ClientContext ctx = contexts.of(req);
            guard.require(ctx, uid, req.getRequestURI());
            devices.touch(uid, ctx);
        }
        return true;
    }
}
