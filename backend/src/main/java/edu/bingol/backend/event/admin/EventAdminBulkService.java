package edu.bingol.backend.event.admin;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.event.EventModerationService;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.BulkAction;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.BulkItem;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.BulkResult;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * Toplu moderasyon (gizle / yeniden yayinla / iptal). Her etkinlik KENDI islemiyle (EventModerationService'in
 * @Transactional metodu) calisir; biri hata verse digerleri etkilenmez (kismi basari raporu). Bu sinif bilerek
 * @Transactional DEGILDIR: tek islemde bir hata tum partiyi "rollback-only" yapardi.
 */
@Service
public class EventAdminBulkService {

    public static final int MAX_IDS = 100;
    private static final Logger log = LoggerFactory.getLogger(EventAdminBulkService.class);

    private final EventModerationService moderation;

    public EventAdminBulkService(EventModerationService moderation) {
        this.moderation = moderation;
    }

    public BulkResult run(Long adminId, BulkAction action, List<Long> rawIds, String reason) {
        if (rawIds == null || rawIds.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz istek.");
        }
        LinkedHashSet<Long> ids = new LinkedHashSet<>();
        for (Long id : rawIds) {
            if (id != null && id > 0) {
                ids.add(id);
            }
        }
        if (ids.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz istek.");
        }
        if (ids.size() > MAX_IDS) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "EVENT_BULK_LIMIT",
                    "Tek seferde en fazla " + MAX_IDS + " etkinlik işlenebilir.", String.valueOf(MAX_IDS));
        }
        if (reason == null || reason.isBlank()) {
            // Toplu islem her zaman sebep ister (EventModerationService de bos sebebi reddeder; erken ve net hata)
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz istek.");
        }
        List<BulkItem> items = new ArrayList<>();
        int done = 0;
        for (Long id : ids) {
            try {
                switch (action) {
                    case HIDE -> moderation.hide(adminId, id, reason);
                    case UNHIDE -> moderation.unhide(adminId, id, reason);
                    case CANCEL -> moderation.cancel(adminId, id, reason);
                }
                items.add(new BulkItem(id, true, HttpStatus.OK.value(), null));
                done++;
            } catch (ApiException ex) {
                items.add(new BulkItem(id, false, ex.status().value(), ex.code()));
            } catch (RuntimeException ex) {
                log.warn("Toplu etkinlik islemi beklenmeyen hata: id={} action={} {}", id, action, ex.toString());
                items.add(new BulkItem(id, false, HttpStatus.INTERNAL_SERVER_ERROR.value(), "INTERNAL_ERROR"));
            }
        }
        return new BulkResult(action, ids.size(), done, ids.size() - done, items);
    }
}
