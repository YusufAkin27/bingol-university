package edu.bingol.backend.messaging.media;

import edu.bingol.backend.export.DataExporter;
import edu.bingol.backend.profile.privacy.AvatarCleanup;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Sohbet gorselleri icin zamanlanmis temizlik, KVKK disa aktarimi ve hesap silme kancasi. */
@Configuration
public class ChatMediaMaintenance {

    private static final Logger log = LoggerFactory.getLogger(ChatMediaMaintenance.class);

    /** Mesaja baglanmamis yuklemeler `unclaimed-hours` (24) sonra, satiri olmayan dosyalar da ayni yastan sonra silinir. */
    @Component
    static class Janitor {

        private final MessageAttachmentService service;
        private final int unclaimedHours;

        Janitor(MessageAttachmentService service,
                @Value("${app.chat.media.unclaimed-hours:24}") int unclaimedHours) {
            this.service = service;
            this.unclaimedHours = Math.max(1, unclaimedHours);
        }

        @Scheduled(cron = "${app.chat.media.cleanup-cron:0 15 * * * *}", zone = "Europe/Istanbul")
        public void scheduled() {
            int n = run();
            if (n > 0) {
                log.info("Sohbet gorseli temizligi: {} baglanmamis yukleme silindi", n);
            }
        }

        /** Suresi (24 sa) dolan tek gosterimlik eklerin baytlari silinir; goruntuleme kayitlari kalir. */
        @Scheduled(cron = "${app.chat.media.view-once-cron:0 30 * * * *}", zone = "Europe/Istanbul")
        public void purgeViewOnce() {
            int n = service.purgeExpiredViewOnce();
            if (n > 0) {
                log.info("Tek gosterimlik gorsel temizligi: {} ek icerigi silindi", n);
            }
        }

        int run() {
            return service.cleanup(Duration.ofHours(unclaimedHours));
        }
    }

    /** Hesap silme (KVKK): kullanicinin yukledigi tum sohbet gorselleri ve baytlari kaldirilir. */
    @Component
    static class AccountCleanup implements AvatarCleanup {

        private final MessageAttachmentService service;

        AccountCleanup(MessageAttachmentService service) {
            this.service = service;
        }

        @Override
        public void cleanup(Long userId, List<String> refs) {
            int n = service.purgeForUser(userId);
            if (n > 0) {
                log.info("Hesap silme: {} sohbet gorseli kaldirildi (kullanici {})", n, userId);
            }
        }
    }

    /** KVKK "verilerimi indir": gonderilen gorsellerin SAYISI/boyutu ve meta verisi; gorsel icerigi HARIC. */
    @Bean
    DataExporter chatMediaExporter(MessageAttachmentRepository repo) {
        return DataExporter.of("sentChatImages", uid -> {
            List<MessageAttachment> rows = repo.findByUploaderId(uid);
            List<Map<String, Object>> items = rows.stream().map(a -> {
                Map<String, Object> e = new LinkedHashMap<>();
                e.put("id", a.getId());
                e.put("conversationId", a.getConversationId());
                e.put("messageId", a.getMessageId());
                e.put("createdAt", a.getCreatedAt().toString());
                e.put("width", a.getWidth());
                e.put("height", a.getHeight());
                e.put("bytes", a.getBytes());
                e.put("removed", a.isHidden());
                e.put("viewOnce", a.isViewOnce()); // tek gosterimlik: yalniz meta, icerik hicbir durumda yok
                return e;
            }).toList();
            return Map.of("count", rows.size(), "totalBytes", rows.stream().mapToLong(MessageAttachment::getBytes).sum(),
                    "items", items, "note", "Görsel içerikleri bu dosyaya dahil değildir.");
        });
    }
}
