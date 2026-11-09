package edu.bingol.backend.messaging.room.dept;

import edu.bingol.backend.appinfo.AppSetting;
import edu.bingol.backend.appinfo.AppSettingRepository;
import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.messaging.room.dept.DepartmentChatService.AutoJoinResult;
import edu.bingol.backend.user.UserRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Mevcut kullanicilari kendi bolum kanalina BIR KEZ ekleyen geri doldurma (kullanici karari 2026-11-09). Migration
 * DEGIL (buyuk yazi yuku): 500'luk kimlik parcalari, parca arasi bekleme, SchedulerLock ile tek calisan, idempotent,
 * opt-out'a saygili (DepartmentChatService.autoJoinOwn). Ilerleme `app_setting` `dept_chat_backfill_cursor`, bitince
 * `dept_chat_backfill_done` yazilir ve is bir daha calismaz (yeniden calistirmak icin iki ayar satiri silinir).
 * Kapatma: `app.chat.dept-backfill-enabled=false` (CHAT_DEPT_BACKFILL_ENABLED).
 */
@Component
public class DepartmentChatBackfillJob {

    static final String CURSOR_KEY = "dept_chat_backfill_cursor";
    static final String DONE_KEY = "dept_chat_backfill_done";
    static final int BATCH = 500;

    private static final Logger log = LoggerFactory.getLogger(DepartmentChatBackfillJob.class);

    private final DepartmentChatService service;
    private final UserRepository users;
    private final AppSettingRepository settings;
    private final SchedulerLock lock;
    private final boolean enabled;
    private final long pauseMs;

    public DepartmentChatBackfillJob(DepartmentChatService service, UserRepository users,
                                     AppSettingRepository settings, SchedulerLock lock,
                                     @Value("${app.chat.dept-backfill-enabled:true}") boolean enabled,
                                     @Value("${app.chat.dept-backfill-pause-ms:300}") long pauseMs) {
        this.service = service;
        this.users = users;
        this.settings = settings;
        this.lock = lock;
        this.enabled = enabled;
        this.pauseMs = Math.max(0, pauseMs);
    }

    @Scheduled(initialDelayString = "${app.chat.dept-backfill-initial-delay-ms:180000}",
            fixedDelayString = "${app.chat.dept-backfill-poll-ms:900000}")
    public void tick() {
        if (!enabled || isDone()) {
            return;
        }
        try {
            lock.tryRun("dept-chat-backfill", Duration.ofHours(2), this::runAll);
        } catch (RuntimeException e) {
            log.warn("Bolum kanali geri doldurma hatasi (sonraki turda devam eder): {}", e.getClass().getSimpleName());
        }
    }

    /** Bitene kadar parca parca calisir; her parcadan sonra imleci saklar. Test icin acik. */
    void runAll() {
        long cursor = readCursor();
        Map<AutoJoinResult, Integer> total = new EnumMap<>(AutoJoinResult.class);
        int processed = 0;
        while (true) {
            List<Long> ids = users.deptUserIdsAfter(cursor, PageRequest.of(0, BATCH));
            if (ids.isEmpty()) {
                break;
            }
            for (Long id : ids) {
                total.merge(service.autoJoinOwn(id), 1, Integer::sum);
            }
            processed += ids.size();
            cursor = ids.get(ids.size() - 1);
            put(CURSOR_KEY, String.valueOf(cursor));
            log.info("Bolum kanali geri doldurma ilerleme: islenen={} son_id={} sonuc={}", processed, cursor, total);
            if (pauseMs > 0) {
                try {
                    Thread.sleep(pauseMs);
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    return;
                }
            }
        }
        put(DONE_KEY, Instant.now().toString());
        log.info("Bolum kanali geri doldurma TAMAMLANDI: islenen={} sonuc={}", processed, total);
    }

    boolean isDone() {
        return settings.findById(DONE_KEY).map(s -> !s.getValue().isBlank()).orElse(false);
    }

    private long readCursor() {
        try {
            return settings.findById(CURSOR_KEY).map(s -> Long.parseLong(s.getValue().trim())).orElse(0L);
        } catch (NumberFormatException e) {
            return 0L;
        }
    }

    private void put(String key, String value) {
        AppSetting s = settings.findById(key).orElseGet(() -> {
            AppSetting n = new AppSetting();
            n.setKey(key);
            return n;
        });
        s.setValue(value);
        s.setUpdatedAt(Instant.now());
        settings.save(s);
    }
}
