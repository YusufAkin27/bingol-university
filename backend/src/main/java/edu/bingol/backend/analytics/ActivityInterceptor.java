package edu.bingol.backend.analytics;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

/** /api/** altindaki kimlikli (JWT) isteklerde {@link ActivityTracker#touch}; istek bittikten sonra calisir. */
@Component
public class ActivityInterceptor implements HandlerInterceptor {

    private final ActivityTracker tracker;

    public ActivityInterceptor(ActivityTracker tracker) {
        this.tracker = tracker;
    }

    @Override
    public void afterCompletion(HttpServletRequest req, HttpServletResponse res, Object handler, Exception ex) {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        // Basic auth yoneticisinin principal'i Long degildir; yalnizca JWT'li kullanicilar izlenir
        if (a != null && a.getPrincipal() instanceof Long id && res.getStatus() != 401) {
            tracker.touch(id);
        }
    }
}
