package edu.bingol.backend.messaging;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.messaging.dto.MessagingDtos.AddMembersRequest;
import edu.bingol.backend.messaging.dto.MessagingDtos.ArchiveRequest;
import edu.bingol.backend.messaging.dto.MessagingDtos.MuteRequest;
import edu.bingol.backend.messaging.dto.MessagingDtos.UnreadSummary;
import edu.bingol.backend.messaging.dto.MessagingDtos.ConversationDetail;
import edu.bingol.backend.messaging.dto.MessagingDtos.ConversationView;
import edu.bingol.backend.messaging.dto.MessagingDtos.CreateConversationRequest;
import edu.bingol.backend.messaging.dto.MessagingDtos.RenameRequest;
import jakarta.validation.Valid;
import java.time.Duration;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Konusma listesi/olusturma ve grup yonetimi. Mesaj uclari {@link MessageController}'da. */
@RestController
@RequestMapping("/api/conversations")
public class ConversationController {

    static final int MANAGE_PER_MINUTE = 30;

    private final ConversationService conversations;
    private final RateLimiter limiter;

    private final ConversationPrefsService prefs;

    public ConversationController(ConversationService conversations, RateLimiter limiter, ConversationPrefsService prefs) {
        this.prefs = prefs;
        this.conversations = conversations;
        this.limiter = limiter;
    }

    /** `{userId}` birebir (varsa 200 + mevcut, yoksa 201); `{title, memberIds}` grup. Kullanici basina gunde 30 istek. */
    @PostMapping
    public ResponseEntity<ConversationView> create(@Valid @RequestBody CreateConversationRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("conv:create:" + uid, 30, Duration.ofDays(1));
        if (r.userId() != null) {
            ConversationService.Opened o = conversations.openDirect(uid, r.userId());
            return ResponseEntity.status(o.created() ? HttpStatus.CREATED : HttpStatus.OK).body(o.conversation());
        }
        if (r.title() == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "userId ya da title + memberIds gerekli.");
        }
        return ResponseEntity.status(HttpStatus.CREATED).body(conversations.createGroup(uid, r.title(), r.memberIds()));
    }

    @GetMapping
    public CursorPage<ConversationView> list(@RequestParam(required = false) Long cursor,
                                             @RequestParam(defaultValue = "20") int size,
                                             @RequestParam(defaultValue = "false") boolean archived) {
        return conversations.list(CurrentUser.id(), cursor, size, archived);
    }

    /** Rozet: sessize alinmamis konusmalardaki toplam okunmamis + konusma bazli dokum. */
    @GetMapping("/unread-count")
    public UnreadSummary unreadCount() {
        Long uid = CurrentUser.id();
        limiter.check("conv:unread:" + uid, 120, Duration.ofMinutes(1));
        return prefs.unreadSummary(uid);
    }

    /** Sessize al: `{durationMinutes}` ya da `{forever:true}`. */
    @PutMapping("/{id}/mute")
    public ConversationView mute(@PathVariable Long id, @Valid @RequestBody MuteRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("conv:pref:" + uid, 60, Duration.ofMinutes(1));
        return prefs.mute(uid, id, r.durationMinutes(), r.forever());
    }

    @DeleteMapping("/{id}/mute")
    public ConversationView unmute(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("conv:pref:" + uid, 60, Duration.ofMinutes(1));
        return prefs.unmute(uid, id);
    }

    /** Arsivle; `keepArchived=true` ise yeni mesaj gelse de arsivde kalir. */
    @PutMapping("/{id}/archive")
    public ConversationView archive(@PathVariable Long id, @RequestBody(required = false) ArchiveRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("conv:pref:" + uid, 60, Duration.ofMinutes(1));
        return prefs.archive(uid, id, r != null && Boolean.TRUE.equals(r.keepArchived()));
    }

    @DeleteMapping("/{id}/archive")
    public ConversationView unarchive(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("conv:pref:" + uid, 60, Duration.ofMinutes(1));
        return prefs.unarchive(uid, id);
    }

    @GetMapping("/{id}")
    public ConversationDetail detail(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("conv:detail:" + uid, 120, Duration.ofMinutes(1));
        return conversations.detail(uid, id);
    }

    @PatchMapping("/{id}")
    public ConversationView rename(@PathVariable Long id, @Valid @RequestBody RenameRequest r) {
        Long uid = CurrentUser.id();
        limitManage(uid);
        return conversations.rename(uid, id, r.title());
    }

    @PostMapping("/{id}/members")
    public ConversationView addMembers(@PathVariable Long id, @Valid @RequestBody AddMembersRequest r) {
        Long uid = CurrentUser.id();
        limitManage(uid);
        return conversations.addMembers(uid, id, r.userIds());
    }

    @DeleteMapping("/{id}/members/{userId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void removeMember(@PathVariable Long id, @PathVariable Long userId) {
        Long uid = CurrentUser.id();
        limitManage(uid);
        conversations.removeMember(uid, id, userId);
    }

    @PostMapping("/{id}/leave")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void leave(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limitManage(uid);
        conversations.leave(uid, id);
    }

    /** Grup yonetimi (ad, uye ekle/cikar, ayril) icin kullanici basina ortak dakikalik sinir. */
    private void limitManage(Long uid) {
        limiter.check("conv:manage:" + uid, MANAGE_PER_MINUTE, Duration.ofMinutes(1));
    }
}
