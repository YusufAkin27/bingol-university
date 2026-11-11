package edu.bingol.backend.messaging.room.notice;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.messaging.room.notice.RoomNoticeService.NoticeView;
import edu.bingol.backend.messaging.room.notice.RoomNoticeService.PinnedView;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Duration;
import org.springframework.http.HttpStatus;
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

/** Oda duyuru panosu uclari. Yalniz HTTP eslemesi + rate limit; yetki ve kurallar RoomNoticeService'te. */
@RestController
@RequestMapping("/api/conversations/{cid}/notices")
public class RoomNoticeController {

    public record CreateRequest(@NotBlank @Size(max = 80) String title, @NotBlank @Size(max = 600) String body,
                                Boolean pinned) {}

    public record UpdateRequest(@Size(max = 80) String title, @Size(max = 600) String body, Boolean pinned) {}

    private final RoomNoticeService svc;
    private final RateLimiter limiter;

    public RoomNoticeController(RoomNoticeService svc, RateLimiter limiter) {
        this.svc = svc;
        this.limiter = limiter;
    }

    @GetMapping("/pinned")
    public PinnedView pinned(@PathVariable Long cid) {
        Long me = CurrentUser.id();
        limiter.check("room-notice-read:user:" + me, 120, Duration.ofMinutes(1));
        return svc.pinned(cid, me);
    }

    @GetMapping
    public CursorPage<NoticeView> list(@PathVariable Long cid, @RequestParam(required = false) Long cursor,
                                       @RequestParam(defaultValue = "20") int size) {
        Long me = CurrentUser.id();
        limiter.check("room-notice-read:user:" + me, 120, Duration.ofMinutes(1));
        return svc.list(cid, me, cursor, size);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public NoticeView create(@PathVariable Long cid, @Valid @RequestBody CreateRequest r) {
        Long me = CurrentUser.id();
        limiter.check("room-notice-write:user:" + me, 20, Duration.ofHours(1));
        return svc.create(cid, me, r.title(), r.body(), Boolean.TRUE.equals(r.pinned()));
    }

    @PatchMapping("/{id}")
    public NoticeView update(@PathVariable Long cid, @PathVariable Long id, @Valid @RequestBody UpdateRequest r) {
        Long me = CurrentUser.id();
        limiter.check("room-notice-write:user:" + me, 60, Duration.ofHours(1));
        return svc.update(cid, me, id, r.title(), r.body(), r.pinned());
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long cid, @PathVariable Long id) {
        Long me = CurrentUser.id();
        limiter.check("room-notice-write:user:" + me, 60, Duration.ofHours(1));
        svc.delete(cid, me, id);
    }

    @PostMapping("/{id}/seen")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void seen(@PathVariable Long cid, @PathVariable Long id) {
        Long me = CurrentUser.id();
        limiter.check("room-notice-seen:user:" + me, 240, Duration.ofMinutes(1));
        svc.markSeen(cid, me, id);
    }
}
