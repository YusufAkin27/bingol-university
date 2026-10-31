package edu.bingol.backend.admin;

import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.security.web.access.AccessDeniedHandlerImpl;
import org.springframework.stereotype.Component;

/**
 * Yetkisiz (403) yonetici istek denemelerini denetim kaydina yazar; yaniti varsayilan isleyiciye birakir.
 * Bu istekler DispatcherServlet'e hic ulasmadigi icin {@link AuditInterceptor} onlari goremez.
 */
@Component
public class AuditAccessDeniedHandler implements AccessDeniedHandler {

    private final AuditRecorder recorder;
    private final AccessDeniedHandler delegate = new AccessDeniedHandlerImpl();

    public AuditAccessDeniedHandler(AuditRecorder recorder) {
        this.recorder = recorder;
    }

    @Override
    public void handle(HttpServletRequest req, HttpServletResponse res, AccessDeniedException e)
            throws IOException, ServletException {
        String path = AdminPaths.of(req);
        if (path.startsWith("/api/admin/") && AuditRecorder.shouldAudit(req.getMethod(), path)) {
            recorder.record(req, SecurityContextHolder.getContext().getAuthentication(), HttpServletResponse.SC_FORBIDDEN);
        }
        delegate.handle(req, res, e);
    }
}
