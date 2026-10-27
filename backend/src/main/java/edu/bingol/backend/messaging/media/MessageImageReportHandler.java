package edu.bingol.backend.messaging.media;

import edu.bingol.backend.moderation.MediaPreview;
import edu.bingol.backend.moderation.ReportTargetHandler;
import edu.bingol.backend.moderation.ReportTargetType;
import java.util.Optional;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

/**
 * MESSAGE_IMAGE hedefi: "gizle" = yumusak gizleme (erisim kapanir, bayt yeni anahtara tasinir), geri alinabilir
 * (otomatik gizleme esigi + itiraz + rapor reddinde unhide). Onizleme yoneticiye ozel yetkili uctan servis edilir.
 */
@Component
public class MessageImageReportHandler implements ReportTargetHandler {

    public static final String ADMIN_PREVIEW = "/api/admin/media/attachments/";

    private final MessageAttachmentRepository repo;
    private final MessageAttachmentService service;

    public MessageImageReportHandler(MessageAttachmentRepository repo, MessageAttachmentService service) {
        this.repo = repo;
        this.service = service;
    }

    @Override
    public ReportTargetType type() {
        return ReportTargetType.MESSAGE_IMAGE;
    }

    /**
     * Gonderilmis ek var mi. Istegi yapan sade kullanici ise ek ayni zamanda ONA GORUNUR olmali: aksi halde
     * genel /api/reports ucu ile baskasinin eklerinin varligi yoklanabilirdi. Yonetici/ic cagri kisitlanmaz.
     */
    @Override
    public boolean exists(Long targetId) {
        Optional<MessageAttachment> a = repo.findById(targetId).filter(x -> x.getMessageId() != null);
        if (a.isEmpty()) {
            return false;
        }
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.getPrincipal() instanceof Long uid
                && auth.getAuthorities().stream().noneMatch(g -> g.getAuthority().equals("ROLE_ADMIN"))) {
            return service.accessible(uid, a.get().getConversationId(), targetId).isPresent();
        }
        return true;
    }

    @Override
    public Optional<Long> ownerId(Long targetId) {
        return repo.findById(targetId).map(MessageAttachment::getUploaderId);
    }

    @Override
    public void hide(Long targetId) {
        service.hide(targetId);
    }

    @Override
    public Optional<MediaPreview> preview(Long targetId) {
        return repo.findById(targetId).map(a -> "VIDEO".equals(a.getKind())
                ? MediaPreview.video(ADMIN_PREVIEW + a.getId() + "/preview",
                        a.getThumbKey() == null ? null : ADMIN_PREVIEW + a.getId() + "/preview?thumb=true", a.getContentType())
                : MediaPreview.image(ADMIN_PREVIEW + a.getId() + "/preview",
                        ADMIN_PREVIEW + a.getId() + "/preview?thumb=true", a.getContentType()));
    }

    @Override
    public boolean reversible() {
        return true;
    }

    @Override
    public void unhide(Long targetId) {
        service.unhide(targetId);
    }
}
