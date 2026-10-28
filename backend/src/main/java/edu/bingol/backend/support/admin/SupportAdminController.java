package edu.bingol.backend.support.admin;

import edu.bingol.backend.support.admin.SupportAdminDtos.AdminMessageView;
import edu.bingol.backend.support.admin.SupportAdminDtos.AdminTicketDetailView;
import edu.bingol.backend.support.admin.SupportAdminDtos.FaqOrderRequest;
import edu.bingol.backend.support.admin.SupportAdminDtos.MergeRequest;
import edu.bingol.backend.support.admin.SupportAdminDtos.MergeResult;
import edu.bingol.backend.support.admin.SupportAdminDtos.NoteRequest;
import edu.bingol.backend.support.admin.SupportAdminDtos.TicketPatch;
import edu.bingol.backend.support.faq.FaqController.FaqAdminView;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Destek tamamlama (P12; `/api/admin/**` yalniz ADMIN): talep yeniden acma/oncelik/atama/ic not/silme, geri bildirim
 * silme/birlestirme, SSS siralama. Silme ve birlestirme SEBEP ister (AdminGuardPolicy) ve geri alinamaz.
 * Okuma ucu (`GET /api/admin/support/tickets/{id}`) TicketController'da kalir ama ic notlari burada birlestirilir.
 */
@RestController
@RequestMapping("/api/admin")
public class SupportAdminController {

    private final SupportAdminService support;
    private final FeedbackAdminService feedback;

    public SupportAdminController(SupportAdminService support, FeedbackAdminService feedback) {
        this.support = support;
        this.feedback = feedback;
    }

    @PostMapping("/support/tickets/{id}/reopen")
    public AdminTicketDetailView reopen(@PathVariable Long id) {
        return support.reopen(id);
    }

    @PatchMapping("/support/tickets/{id}")
    public AdminTicketDetailView patch(@PathVariable Long id, @RequestBody TicketPatch p) {
        return support.update(id, p);
    }

    /** Ic not: musteriye gorunmez, bildirim/e-posta gitmez. */
    @PostMapping("/support/tickets/{id}/notes")
    @ResponseStatus(HttpStatus.CREATED)
    public AdminMessageView note(@PathVariable Long id, @Valid @RequestBody NoteRequest r, Authentication auth) {
        return support.addNote(id, adminId(auth), r.text());
    }

    /** Geri alinamaz; sebep (X-Admin-Reason ya da govdede reason) zorunlu. */
    @DeleteMapping("/support/tickets/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteTicket(@PathVariable Long id) {
        support.delete(id, edu.bingol.backend.admin.AuditContext.currentReason());
    }

    @DeleteMapping("/support/feedback/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteFeedback(@PathVariable Long id) {
        feedback.delete(id, edu.bingol.backend.admin.AuditContext.currentReason());
    }

    @PostMapping("/support/feedback/merge")
    public MergeResult merge(@Valid @RequestBody MergeRequest r) {
        return feedback.merge(r.sourceId(), r.targetId(), r.reason());
    }

    /** SSS sirasi: kimlikler ayni dil + kategoride, yeni sira = dizi sirasi. */
    @PutMapping("/faq/order")
    public List<FaqAdminView> faqOrder(@Valid @RequestBody FaqOrderRequest r) {
        return feedback.reorderFaq(r.ids()).stream().map(f -> new FaqAdminView(f.getId(), f.getLang(), f.getCategory(),
                f.getQuestion(), f.getAnswer(), f.getSortOrder(), f.isPublished())).toList();
    }

    static Long adminId(Authentication auth) {
        return auth != null && auth.getPrincipal() instanceof Long l ? l : null;
    }
}
