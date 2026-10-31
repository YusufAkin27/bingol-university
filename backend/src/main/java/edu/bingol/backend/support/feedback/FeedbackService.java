package edu.bingol.backend.support.feedback;

import edu.bingol.backend.admin.rbac.PermissionAwareMasking;
import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.moderation.profanity.ContentGuard.Entity;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.support.feedback.FeedbackDtos.AdminFeedbackPage;
import edu.bingol.backend.support.feedback.FeedbackDtos.AdminFeedbackView;
import edu.bingol.backend.support.feedback.FeedbackDtos.CreateFeedbackRequest;
import edu.bingol.backend.support.feedback.FeedbackDtos.FeedbackPage;
import edu.bingol.backend.support.feedback.FeedbackDtos.FeedbackView;
import edu.bingol.backend.support.feedback.FeedbackDtos.SuggestionPage;
import edu.bingol.backend.support.feedback.FeedbackDtos.SuggestionView;
import edu.bingol.backend.support.feedback.FeedbackDtos.UpdateFeedbackRequest;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class FeedbackService {

    private final FeedbackRepository repo;
    private final UserRepository users;
    private final NotificationService notifications;

    /** Herkese acik metin denetimi (istege bagli: guard'siz kurulan testler icin). */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private ContentGuard guard;

    public FeedbackService(FeedbackRepository repo, UserRepository users, NotificationService notifications) {
        this.repo = repo;
        this.users = users;
        this.notifications = notifications;
    }

    @Transactional
    public Feedback create(Long userId, CreateFeedbackRequest r) {
        Feedback f = new Feedback();
        f.setUserId(userId);
        f.setCategory(r.category());
        f.setSubject(r.subject().trim());
        f.setMessage(r.message().trim());
        f.setAppVersion(blankToNull(r.appVersion()));
        f.setPlatform(r.platform());
        return repo.save(f);
    }

    public FeedbackPage mine(Long userId, Long cursor, int size) {
        int s = CursorPage.clampSize(size);
        CursorPage<FeedbackView> page = CursorPage.of(repo.mine(userId, cursor, PageRequest.of(0, s + 1)), s,
                Feedback::getId, FeedbackView::of);
        return new FeedbackPage(page.items(), page.nextCursor());
    }

    /** sort: "top" (en cok oy) veya "new" (en yeni). */
    public SuggestionPage board(Long userId, String sort, int page, int size) {
        Sort order = "new".equals(sort) ? Sort.by(Sort.Order.desc("id"))
                : Sort.by(Sort.Order.desc("voteCount"), Sort.Order.desc("id"));
        Page<Feedback> result = repo.findByPublicVisibleTrue(
                PageRequest.of(Math.max(page, 0), CursorPage.clampSize(size), order));
        Set<Long> voted = result.isEmpty() ? Set.of()
                : Set.copyOf(repo.votedAmong(userId, result.getContent().stream().map(Feedback::getId).toList()));
        List<SuggestionView> items = result.getContent().stream()
                .map(f -> new SuggestionView(f.getId(), f.getSubject(), f.getMessage(), f.getStatus(),
                        f.getAdminResponse(), f.getVoteCount(), voted.contains(f.getId()), f.getCreatedAt().toString()))
                .toList();
        return new SuggestionPage(items, result.getNumber(), result.getTotalPages(), result.getTotalElements());
    }

    /** Oy ver (idempotent): yalnizca herkese acik onerilere. */
    @Transactional
    public void vote(Long userId, Long feedbackId) {
        requirePublic(feedbackId);
        if (repo.insertVote(feedbackId, userId) == 1) {
            repo.addVotes(feedbackId, 1);
        }
    }

    @Transactional
    public void unvote(Long userId, Long feedbackId) {
        requirePublic(feedbackId);
        if (repo.deleteVote(feedbackId, userId) == 1) {
            repo.addVotes(feedbackId, -1);
        }
    }

    // --- yonetici ---

    public AdminFeedbackPage adminList(Feedback.Status status, Feedback.Category category, Long cursor, int size) {
        int s = CursorPage.clampSize(size);
        List<Feedback> rows = repo.admin(status, category, cursor, PageRequest.of(0, s + 1));
        List<Feedback> pageRows = rows.size() > s ? rows.subList(0, s) : rows;
        Map<Long, User> byId = users.findAllById(pageRows.stream().map(Feedback::getUserId).distinct().toList())
                .stream().collect(Collectors.toMap(User::getId, Function.identity()));
        CursorPage<AdminFeedbackView> page = CursorPage.of(rows, s, Feedback::getId, f -> new AdminFeedbackView(
                f.getId(), f.getUserId(),
                PermissionAwareMasking.email(byId.containsKey(f.getUserId()) ? byId.get(f.getUserId()).getEmail() : null),
                f.getCategory(), f.getSubject(), f.getMessage(), f.getStatus(), f.getAdminResponse(),
                f.isPublicVisible(), f.getVoteCount(), f.getAppVersion(), f.getPlatform(), f.getCreatedAt().toString()));
        return new AdminFeedbackPage(page.items(), page.nextCursor());
    }

    @Transactional
    public Feedback adminUpdate(Long id, UpdateFeedbackRequest r) {
        Feedback f = repo.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "FEEDBACK_NOT_FOUND", "Geri bildirim bulunamadı."));
        boolean notify = false;
        if (r.status() != null && r.status() != f.getStatus()) {
            f.setStatus(r.status());
            notify = true;
        }
        if (r.adminResponse() != null) {
            String resp = blankToNull(r.adminResponse());
            if (resp != null && !resp.equals(f.getAdminResponse())) {
                f.setAdminResponse(resp);
                f.setRespondedAt(Instant.now());
                notify = true;
            }
        }
        if (r.publicVisible() != null) {
            if (r.publicVisible() && f.getCategory() != Feedback.Category.SUGGESTION) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "NOT_A_SUGGESTION",
                        "Yalnızca öneriler herkese açık panoya alınabilir.");
            }
            if (r.publicVisible() && !f.isPublicVisible()) { // herkese acik panoya alinirken denetlenir
                ContentGuard.clean(guard, Entity.SUGGESTION, "subject", f.getUserId(), f.getSubject());
                ContentGuard.clean(guard, Entity.SUGGESTION, "message", f.getUserId(), f.getMessage());
            }
            f.setPublicVisible(r.publicVisible());
        }
        Feedback saved = repo.save(f);
        if (notify) {
            notifications.sendLocalized(f.getUserId(), NotificationType.SYSTEM, "notif.feedback.updated.title", null,
                    f.getSubject(), Map.of("feedbackId", String.valueOf(f.getId())));
        }
        return saved;
    }

    private void requirePublic(Long feedbackId) {
        Feedback f = repo.findById(feedbackId).orElse(null);
        if (f == null || !f.isPublicVisible()) {
            throw new ApiException(HttpStatus.NOT_FOUND, "SUGGESTION_NOT_FOUND", "Öneri bulunamadı.");
        }
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }
}
