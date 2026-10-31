package edu.bingol.backend.messaging;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.messaging.dto.MessagingDtos.DeliveredRequest;
import edu.bingol.backend.messaging.dto.MessagingDtos.EditMessageRequest;
import edu.bingol.backend.messaging.dto.MessagingDtos.MessageView;
import edu.bingol.backend.messaging.dto.MessagingDtos.ReactRequest;
import edu.bingol.backend.messaging.dto.MessagingDtos.ReactionSummary;
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

/** Mesaj gecmisi, yedek (REST) gonderim, okundu imleci, raporlama ve cevrimici durum. */
@RestController
@RequestMapping("/api")
public class MessageController {

    static final int HISTORY_PER_MINUTE = 120;
    /** T-025: cevrimici/son gorulme sorgusu kullanici basina dakikada (id tarama/izleme sinirlanir). */
    static final int PRESENCE_PER_MINUTE = 60;

    private final MessageService messages;
    private final MessageActionService actions;
    private final PresenceService presence;
    private final RateLimiter limiter;
    private final ReceiptService receipts;

    public MessageController(MessageService messages, MessageActionService actions, PresenceService presence,
                             RateLimiter limiter, ReceiptService receipts) {
        this.receipts = receipts;
        this.actions = actions;
        this.messages = messages;
        this.presence = presence;
        this.limiter = limiter;
    }

    /** Imlec: `before=<en eski gorulen id>` (yeni->eski) ya da `after=<son bilinen id>` (eski->yeni, yeniden baglanma). */
    @GetMapping("/conversations/{id}/messages")
    public CursorPage<MessageView> history(@PathVariable Long id, @RequestParam(required = false) Long before,
                                           @RequestParam(required = false) Long after,
                                           @RequestParam(defaultValue = "30") int size) {
        Long uid = CurrentUser.id();
        // Istemci tarafi arama bu ucu sayfalayarak tarar (sunucuda arama yok): toplu cozmeyi sinirlar
        limiter.check("msg:history:" + uid, HISTORY_PER_MINUTE, Duration.ofMinutes(1));
        return messages.history(uid, id, before, after, size);
    }

    /** WebSocket yokken yedek gonderim; `clientId` ile idempotent (tekrarda 200 + mevcut mesaj, yenide 201). */
    @PostMapping("/conversations/{id}/messages")
    public ResponseEntity<MessageView> send(@PathVariable Long id, @Valid @RequestBody SendMessageRequest r) {
        MessageService.SendResult res = messages.send(CurrentUser.id(), id, r.text(), r.clientId(), r.replyToMessageId(),
                r.attachmentIds(), r.viewOnce());
        return ResponseEntity.status(res.created() ? HttpStatus.CREATED : HttpStatus.OK).body(res.message());
    }

    @PostMapping("/conversations/{id}/read")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void read(@PathVariable Long id, @Valid @RequestBody ReadRequest r) {
        messages.markRead(CurrentUser.id(), id, r.lastMessageId());
    }

    /** Iletildi ack'i: imlec yalniz ileri gider; kendi mesajlari yok sayilir. Dakikada 120. */
    @PostMapping("/conversations/{id}/delivered")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delivered(@PathVariable Long id, @Valid @RequestBody DeliveredRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("delivered:" + uid, ReceiptService.DELIVERED_PER_MINUTE, Duration.ofMinutes(1));
        receipts.markDelivered(uid, id, r.lastMessageId());
    }

    /** Duzenle (yalniz gonderen, sure sinirli). */
    @PatchMapping("/messages/{id}")
    public MessageView edit(@PathVariable Long id, @Valid @RequestBody EditMessageRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("msg:edit:" + uid, 30, Duration.ofMinutes(1));
        return actions.edit(uid, id, r.text());
    }

    /** Herkes icin sil (gonderen ya da grup yoneticisi); idempotent. */
    @DeleteMapping("/messages/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("msg:delete:" + uid, 30, Duration.ofMinutes(1));
        actions.delete(uid, id);
    }

    /** Tepki ver / degistir (mesaj basina 1). */
    @PutMapping("/messages/{id}/reaction")
    public ReactionSummary react(@PathVariable Long id, @Valid @RequestBody ReactRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("msg:react:" + uid, 60, Duration.ofMinutes(1));
        return actions.react(uid, id, r.emoji());
    }

    @DeleteMapping("/messages/{id}/reaction")
    public ReactionSummary unreact(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("msg:react:" + uid, 60, Duration.ofMinutes(1));
        return actions.unreact(uid, id);
    }

    /** Istemcinin tepki secicisi icin izinli emoji listesi. */
    @GetMapping("/messages/reactions")
    public Map<String, java.util.Collection<String>> allowedReactions() {
        return Map.of("emojis", actions.allowedReactions());
    }

    /** /api/reports ile ayni ReportService ve ayni gunluk limit (20) kullanilir. */
    @PostMapping("/messages/{id}/report")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Long> report(@PathVariable Long id, @Valid @RequestBody ReportMessageRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("report:user:" + uid, 20, Duration.ofDays(1));
        return Map.of("id", messages.report(uid, id, r));
    }

    /**
     * Yalnizca ortak konusmasi olan kullanicilar gorur; ortak konusma yoksa 404. Engel iliskisi, hedefin gizlilik ayari
     * ve karsilik gormemis birebir konusmada sabit "cevrimdisi" doner (200; engel ayrimi sizdirilmaz).
     */
    @GetMapping("/users/{id}/presence")
    public PresenceView presence(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("presence:" + uid, PRESENCE_PER_MINUTE, Duration.ofMinutes(1));
        return presence.view(uid, id);
    }
}
