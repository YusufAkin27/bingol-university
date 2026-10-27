package edu.bingol.backend.messaging.media;

import edu.bingol.backend.common.RateLimiter;
import java.time.Duration;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Yonetici moderasyon onizlemesi (gizli ekler dahil). /api/admin/** yalnizca ADMIN'dir (SecurityConfig); GET olsa da
 * her erisim denetim kaydina yazilir (AuditRecorder.shouldAudit). Gorsel icerik kisitli: hiz siniri vardir.
 */
@RestController
@RequestMapping("/api/admin/media/attachments")
public class AdminMediaPreviewController {

    private final MessageAttachmentService service;
    private final RateLimiter limiter;

    public AdminMediaPreviewController(MessageAttachmentService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    @GetMapping("/{id}/preview")
    public ResponseEntity<Resource> preview(@PathVariable Long id, @RequestParam(defaultValue = "false") boolean thumb,
                                            @RequestHeader(value = HttpHeaders.RANGE, required = false) String range,
                                            HttpServletResponse resp, Authentication auth) {
        limiter.check("adminmedia:" + (auth == null ? "anon" : auth.getName()), 120, Duration.ofMinutes(1));
        return service.streamForAdmin(id, thumb, range, resp); // video: Range destekli, govde dogrudan yazilir
    }
}
