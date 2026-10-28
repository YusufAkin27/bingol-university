package edu.bingol.backend.admin.chat.action;

import edu.bingol.backend.admin.AuditRepository;
import edu.bingol.backend.admin.AuditRepository.Details;
import edu.bingol.backend.admin.chat.action.ChatActionDtos.BulkItem;
import edu.bingol.backend.common.ClientIp;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Component;

/**
 * Toplu gizlemede her mesaj icin AYRI denetim satiri yazar (sanal yol /api/admin/messages/{id}/hide); boylece mesajin
 * kendi denetim gecmisinde (targetType=MESSAGE) toplu islem de gorunur. Istegin kendi satirini AuditInterceptor yazar.
 * Hata asla istegi bozmaz.
 */
@Component
public class ChatActionAuditWriter {

    private static final Logger log = LoggerFactory.getLogger(ChatActionAuditWriter.class);

    private final AuditRepository repo;
    private final ClientIp clientIp;

    public ChatActionAuditWriter(AuditRepository repo, ClientIp clientIp) {
        this.repo = repo;
        this.clientIp = clientIp;
    }

    public void bulkHide(HttpServletRequest req, Authentication auth, String reason, List<BulkItem> items) {
        Long adminId = auth != null && auth.getPrincipal() instanceof Long l ? l : null;
        String fallback = adminId == null && auth != null ? "basic-admin" : null;
        String ip = clientIp.of(req);
        String rid = MDC.get("requestId");
        for (BulkItem it : items) {
            try {
                String summary = "toplu gizleme" + (it.ok() ? ": basarili" : ": basarisiz " + it.error());
                repo.insert(adminId, fallback, "POST", "/api/admin/messages/" + it.id() + "/hide", it.status(), ip,
                        new Details("MESSAGE", String.valueOf(it.id()), reason, summary, rid));
            } catch (RuntimeException e) {
                log.warn("Toplu gizleme denetim satiri yazilamadi: mesaj={} {}", it.id(), e.toString());
            }
        }
    }
}
