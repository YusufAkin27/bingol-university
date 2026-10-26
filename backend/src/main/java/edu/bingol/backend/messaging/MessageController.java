package edu.bingol.backend.messaging;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.messaging.dto.MessagingDtos.MessageView;
import edu.bingol.backend.messaging.dto.MessagingDtos.PresenceView;
import edu.bingol.backend.messaging.dto.MessagingDtos.ReadRequest;
import edu.bingol.backend.messaging.dto.MessagingDtos.ReportMessageRequest;
import edu.bingol.backend.messaging.dto.MessagingDtos.SendMessageRequest;
import edu.bingol.backend.messaging.ws.PresenceService;
import jakarta.validation.Valid;
import java.time.Duration;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Mesaj gecmisi, yedek (REST) gonderim, okundu imleci, raporlama ve cevrimici durum. */
@RestController
@RequestMapping("/api")
public class MessageController {

    private final MessageService messages;
    private final PresenceService presence;
    private final RateLimiter limiter;

    public MessageController(MessageService messages, PresenceService presence, RateLimiter limiter) {
        this.messages = messages;
        this.presence = presence;
        this.limiter = limiter;
    }

    /** Imlec: `before=<en eski gorulen id>` (yeni->eski) ya da `after=<son bilinen id>` (eski->yeni, yeniden baglanma). */
    @GetMapping("/conversations/{id}/messages")
    public CursorPage<MessageView> history(@PathVariable Long id, @RequestParam(required = false) Long before,
                                           @RequestParam(required = false) Long after,
                                           @RequestParam(defaultValue = "30") int size) {
        return messages.history(CurrentUser.id(), id, before, after, size);
    }

    /** WebSocket yokken yedek gonderim; `clientId` ile idempotent (tekrarda 200 + mevcut mesaj, yenide 201). */
    @PostMapping("/conversations/{id}/messages")
    public ResponseEntity<MessageView> send(@PathVariable Long id, @Valid @RequestBody SendMessageRequest r) {
        MessageService.SendResult res = messages.send(CurrentUser.id(), id, r.text(), r.clientId(), r.attachmentIds());
        return ResponseEntity.status(res.created() ? HttpStatus.CREATED : HttpStatus.OK).body(res.message());
    }

    @PostMapping("/conversations/{id}/read")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void read(@PathVariable Long id, @Valid @RequestBody ReadRequest r) {
        messages.markRead(CurrentUser.id(), id, r.lastMessageId());
    }

    /** /api/reports ile ayni ReportService ve ayni gunluk limit (20) kullanilir. */
    @PostMapping("/messages/{id}/report")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Long> report(@PathVariable Long id, @Valid @RequestBody ReportMessageRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("report:user:" + uid, 20, Duration.ofDays(1));
        return Map.of("id", messages.report(uid, id, r));
    }

    /** Yalnizca ortak konusmasi olan (ve engel iliskisi olmayan) kullanicilar gorur; aksi halde 404. */
    @GetMapping("/users/{id}/presence")
    public PresenceView presence(@PathVariable Long id) {
        return presence.view(CurrentUser.id(), id);
    }
}
