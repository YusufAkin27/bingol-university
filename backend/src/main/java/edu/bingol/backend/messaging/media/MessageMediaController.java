package edu.bingol.backend.messaging.media;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.messaging.dto.MessagingDtos.ReportMessageRequest;
import edu.bingol.backend.moderation.ReportReason;
import edu.bingol.backend.moderation.ReportService;
import edu.bingol.backend.moderation.ReportTargetType;
import edu.bingol.backend.moderation.dto.ModerationDtos.CreateReportRequest;
import jakarta.validation.Valid;
import java.time.Duration;
import java.util.Map;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/** Sohbet gorselleri: yukleme, yetkili okuma, imzali adres, rapor. Hepsi kimlikli; yetki servis katmaninda (IDOR = 404). */
@RestController
@RequestMapping("/api/conversations/{cid}/media")
public class MessageMediaController {

    private final MessageAttachmentService service;
    private final ReportService reports;
    private final RateLimiter limiter;

    public MessageMediaController(MessageAttachmentService service, ReportService reports, RateLimiter limiter) {
        this.service = service;
        this.reports = reports;
        this.limiter = limiter;
    }

    /** Alan adi `file`. Yanit `id`yi mesaj gonderiminde `attachmentIds` ile kullanin. Hiz/kota servis icinde. */
    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public AttachmentView upload(@PathVariable Long cid, @RequestParam("file") MultipartFile file) {
        return service.upload(CurrentUser.id(), cid, file);
    }

    @GetMapping("/{aid}")
    public ResponseEntity<Resource> get(@PathVariable Long cid, @PathVariable Long aid) {
        Long uid = CurrentUser.id();
        limiter.check("chatmedia:get:" + uid, 300, Duration.ofMinutes(1));
        return service.stream(uid, cid, aid, false);
    }

    @GetMapping("/{aid}/thumb")
    public ResponseEntity<Resource> thumb(@PathVariable Long cid, @PathVariable Long aid) {
        Long uid = CurrentUser.id();
        limiter.check("chatmedia:get:" + uid, 300, Duration.ofMinutes(1));
        return service.stream(uid, cid, aid, true);
    }

    /** &lt;img&gt; etiketi Bearer gonderemez: kisa omurlu (varsayilan 5 dk) imzali adresler. */
    @GetMapping("/{aid}/link")
    public AttachmentView.Link link(@PathVariable Long cid, @PathVariable Long aid) {
        Long uid = CurrentUser.id();
        limiter.check("chatmedia:get:" + uid, 300, Duration.ofMinutes(1));
        return service.link(uid, cid, aid);
    }

    /** Yalnizca gonderilmemis kendi yuklemesi; mesaja bagliysa 409. */
    @DeleteMapping("/{aid}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long cid, @PathVariable Long aid) {
        Long uid = CurrentUser.id();
        limiter.check("chatmedia:del:" + uid, 30, Duration.ofMinutes(1));
        service.deleteUnsent(uid, cid, aid);
    }

    /** Gorseli raporla (MESSAGE_IMAGE). Erisimi olmayan icin 404; /api/reports ile ayni gunluk limit. */
    @PostMapping("/{aid}/report")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Long> report(@PathVariable Long cid, @PathVariable Long aid,
                                    @Valid @RequestBody ReportMessageRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("report:user:" + uid, 20, Duration.ofDays(1));
        limiter.check("report:burst:" + uid, 5, Duration.ofMinutes(1));
        service.require(uid, cid, aid);
        ReportReason reason = r.reason();
        return Map.of("id", reports.create(uid,
                new CreateReportRequest(ReportTargetType.MESSAGE_IMAGE, aid, reason, r.note())).getId());
    }
}
