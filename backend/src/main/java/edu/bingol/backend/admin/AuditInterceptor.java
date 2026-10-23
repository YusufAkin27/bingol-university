package edu.bingol.backend.admin;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

/** /api/admin/** altindaki GET disi istekleri (ve CSV disa aktarimini) istek bitince denetim kaydina yazar. */
@Component
public class AuditInterceptor implements HandlerInterceptor {

    private final AuditRecorder recorder;

    public AuditInterceptor(AuditRecorder recorder) {
        this.recorder = recorder;
    }

    @Override
    public void afterCompletion(HttpServletRequest req, HttpServletResponse res, Object handler, Exception ex) {
        if (!AuditRecorder.shouldAudit(req.getMethod(), req.getRequestURI())) {
            return;
        }
        // Yakalanmamis hata durumunda yanit kodu henuz 200 gorunebilir
        int status = ex != null && res.getStatus() < 400 ? 500 : res.getStatus();
        recorder.record(req, SecurityContextHolder.getContext().getAuthentication(), status);
    }
}
