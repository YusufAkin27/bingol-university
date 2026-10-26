package edu.bingol.backend.messaging;

import java.time.Clock;
import java.time.Duration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Silinen mesajlarin saklama suresi (T24). `app.chat.deleted-retention-days` = 0 (varsayilan) ise silinen mesajlar
 * suresiz saklanir ve is hicbir sey yapmaz; N > 0 ise N gunden eski silinmis mesajlar (tepki ve duzenleme gecmisiyle
 * birlikte) her gece kalici silinir. Hata exception sizdirmaz.
 */
@Component
public class DeletedMessageRetention {

    private static final Logger log = LoggerFactory.getLogger(DeletedMessageRetention.class);

    private final MessageRepository messages;
    private final Clock clock;
    private final long retentionDays;

    public DeletedMessageRetention(MessageRepository messages, Clock clock,
                                   @Value("${app.chat.deleted-retention-days:0}") long retentionDays) {
        this.messages = messages;
        this.clock = clock;
        this.retentionDays = Math.max(0, retentionDays);
    }

    @Scheduled(cron = "${app.chat.deleted-retention-cron:0 40 3 * * *}", zone = "Europe/Istanbul")
    public void purge() {
        if (retentionDays == 0) {
            return;
        }
        try {
            int n = messages.purgeDeletedBefore(clock.instant().minus(Duration.ofDays(retentionDays)));
            log.info("Silinen mesaj saklama: {} mesaj kalici silindi (sure {} gun)", n, retentionDays);
        } catch (RuntimeException e) {
            log.warn("Silinen mesaj temizligi basarisiz: {}", e.toString());
        }
    }
}
