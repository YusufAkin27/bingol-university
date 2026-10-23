package edu.bingol.backend.messaging;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.messaging.dto.MessagingDtos.AddMembersRequest;
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
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Konusma listesi/olusturma ve grup yonetimi. Mesaj uclari {@link MessageController}'da. */
@RestController
@RequestMapping("/api/conversations")
public class ConversationController {

    private final ConversationService conversations;
    private final RateLimiter limiter;

    public ConversationController(ConversationService conversations, RateLimiter limiter) {
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
                                             @RequestParam(defaultValue = "20") int size) {
        return conversations.list(CurrentUser.id(), cursor, size);
    }

    @GetMapping("/{id}")
    public ConversationDetail detail(@PathVariable Long id) {
        return conversations.detail(CurrentUser.id(), id);
    }

    @PatchMapping("/{id}")
    public ConversationView rename(@PathVariable Long id, @Valid @RequestBody RenameRequest r) {
        return conversations.rename(CurrentUser.id(), id, r.title());
    }

    @PostMapping("/{id}/members")
    public ConversationView addMembers(@PathVariable Long id, @Valid @RequestBody AddMembersRequest r) {
        return conversations.addMembers(CurrentUser.id(), id, r.userIds());
    }

    @DeleteMapping("/{id}/members/{userId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void removeMember(@PathVariable Long id, @PathVariable Long userId) {
        conversations.removeMember(CurrentUser.id(), id, userId);
    }

    @PostMapping("/{id}/leave")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void leave(@PathVariable Long id) {
        conversations.leave(CurrentUser.id(), id);
    }
}
