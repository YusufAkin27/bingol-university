package edu.bingol.backend.support.admin;

import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.support.admin.SupportAdminDtos.MergeResult;
import edu.bingol.backend.support.faq.FaqItem;
import edu.bingol.backend.support.faq.FaqRepository;
import edu.bingol.backend.support.feedback.Feedback;
import edu.bingol.backend.support.feedback.FeedbackRepository;
import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Geri bildirim silme/birlestirme ve SSS siralama (P12). Hepsi geri alinamaz; sebep AdminGuardPolicy ile zorunlu. */
@Service
public class FeedbackAdminService {

    private final FeedbackRepository feedback;
    private final FaqRepository faq;
    private final NotificationService notifications;

    public FeedbackAdminService(FeedbackRepository feedback, FaqRepository faq, NotificationService notifications) {
        this.feedback = feedback;
        this.faq = faq;
        this.notifications = notifications;
    }

    /** Geri bildirimi ve oylarini siler. */
    @Transactional
    public void delete(Long id, String reason) {
        Feedback f = find(id);
        feedback.deleteVotesOf(id);
        feedback.deleteById(f.getId());
        AuditContext.target("FEEDBACK", id).reason(reason)
                .summary("silindi; kategori=" + f.getCategory() + "; oy=" + f.getVoteCount());
    }

    /**
     * Kaynagi hedefe birlestirir: kaynagin oylari hedefe tasinir (cift oy sayilmaz), kaynak silinir, kaynak yazarina
     * bildirim gider. Kaynakta oy varsa hedef herkese acik panoda olmalidir (oylar baska turlu gorunmez olur).
     */
    @Transactional
    public MergeResult merge(Long sourceId, Long targetId, String reason) {
        if (sourceId.equals(targetId)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "FEEDBACK_MERGE_SAME", "Kaynak ve hedef aynı olamaz.");
        }
        Feedback source = find(sourceId);
        Feedback target = find(targetId);
        if (source.getVoteCount() > 0 && !target.isPublicVisible()) {
            throw new ApiException(HttpStatus.CONFLICT, "FEEDBACK_MERGE_TARGET_NOT_PUBLIC",
                    "Oyu olan öneri yalnızca herkese açık bir öneriyle birleştirilebilir.");
        }
        int moved = feedback.moveVotes(sourceId, targetId);
        feedback.deleteVotesOf(sourceId);
        feedback.recountVotes(targetId);
        feedback.deleteById(sourceId);
        int votes = feedback.findById(targetId).map(Feedback::getVoteCount).orElse(0);
        AuditContext.target("FEEDBACK", targetId).reason(reason)
                .summary("birleştirildi kaynak=" + sourceId + " taşınan oy=" + moved);
        notifications.sendLocalized(source.getUserId(), NotificationType.SYSTEM, "notif.feedback.merged.title", null,
                target.getSubject(), Map.of("feedbackId", String.valueOf(targetId)));
        return new MergeResult(sourceId, targetId, votes);
    }

    /**
     * SSS siralamasi: verilen kimlikler ayni dil + kategoride olmali; sortOrder sirayla 10, 20, 30... atanir
     * (arada bosluk: sonradan eklenenler araya girebilir). Kimlikler tekil olmali, en cok 200.
     */
    @Transactional
    public List<FaqItem> reorderFaq(List<Long> ids) {
        Set<Long> unique = new HashSet<>(ids);
        if (unique.size() != ids.size()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "FAQ_ORDER_INVALID", "Sıralama listesinde tekrar eden kayıt var.");
        }
        List<FaqItem> items = faq.findAllById(ids);
        if (items.size() != ids.size()) {
            throw new ApiException(HttpStatus.NOT_FOUND, "FAQ_NOT_FOUND", "Soru bulunamadı.");
        }
        FaqItem first = items.get(0);
        for (FaqItem i : items) {
            if (!i.getLang().equals(first.getLang()) || !i.getCategory().equals(first.getCategory())) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "FAQ_ORDER_INVALID",
                        "Yalnızca aynı dil ve kategorideki sorular birlikte sıralanabilir.");
            }
        }
        Map<Long, FaqItem> byId = new java.util.HashMap<>();
        items.forEach(i -> byId.put(i.getId(), i));
        int order = 10;
        Instant now = Instant.now();
        for (Long id : ids) {
            FaqItem i = byId.get(id);
            i.setSortOrder(order);
            i.setUpdatedAt(now);
            order += 10;
        }
        faq.saveAll(items);
        AuditContext.target("FAQ", null).summary("sıralama " + first.getLang() + "/" + first.getCategory() + " n=" + ids.size());
        return ids.stream().map(byId::get).toList();
    }

    private Feedback find(Long id) {
        return feedback.findById(id).orElseThrow(() ->
                new ApiException(HttpStatus.NOT_FOUND, "FEEDBACK_NOT_FOUND", "Geri bildirim bulunamadı."));
    }
}
