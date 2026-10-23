package edu.bingol.backend.news;

import edu.bingol.backend.config.SyncProperties;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.status.StatusService;
import java.time.Instant;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

@Service
public class NewsSyncService {

    private static final Logger log = LoggerFactory.getLogger(NewsSyncService.class);
    /** Siteyi yormamak icin ardisik detay istekleri arasindaki bekleme. */
    private static final long REQUEST_DELAY_MS = 500;

    private final NewsScraper scraper;
    private final NewsRepository repo;
    private final StatusService status;
    private final AtomicBoolean running = new AtomicBoolean();
    private final SyncProperties props;
    private final NotificationService notifications;
    private final I18n i18n;

    public NewsSyncService(NewsScraper scraper, NewsRepository repo, StatusService status, SyncProperties props,
                           NotificationService notifications, I18n i18n) {
        this.notifications = notifications;
        this.i18n = i18n;
        this.props = props;
        this.scraper = scraper;
        this.repo = repo;
        this.status = status;
    }

    /** Sadece ilk kurulumda (veritabani bos) bir kez doldurur; sonraki acilislarda siteye istek atmaz. */
    @EventListener(ApplicationReadyEvent.class)
    public void initialFill() {
        if (props.initialFill() && repo.count() == 0) {
            // Acilisi bloklamasin (saglik kontrolu hemen UP olsun): ilk dolum arka planda
            java.util.concurrent.CompletableFuture.runAsync(this::sync);
        }
    }

    /** Varsayilan: her gece 00:00 (Istanbul). Ayar: news.sync.cron */
    @Scheduled(cron = "${news.sync.cron:0 0 0 * * *}", zone = "Europe/Istanbul")
    public void scheduledSync() {
        sync();
    }

    /** Yeni kayitlari ceker; tur basina eklenen sayiyi doner. Hicbir zaman exception firlatmaz. */
    public Map<ContentType, Integer> sync() {
        Map<ContentType, Integer> added = new EnumMap<>(ContentType.class);
        if (!running.compareAndSet(false, true)) {
            log.info("Haber senkronizasyonu zaten calisiyor");
            return added;
        }
        try {
            // Veritabani bossa (ilk dolum) kimseye bildirim gonderme
            boolean notify = repo.count() > 0;
            List<String> failures = new ArrayList<>();
            for (ContentType type : ContentType.values()) {
                try {
                    added.put(type, syncType(type, notify));
                } catch (Exception e) {
                    log.warn("{} senkronizasyonu basarisiz: {}", type, e.toString());
                    failures.add(type + ": " + e.getMessage());
                }
            }
            if (failures.size() == ContentType.values().length) {
                status.markMaintenance(StatusService.NEWS, "Kaynak site okunamadi: " + String.join("; ", failures));
            } else {
                status.markOk(StatusService.NEWS, failures.isEmpty() ? null : "Kismi hata: " + String.join("; ", failures));
            }
            log.info("Haber senkronizasyonu bitti: {}", added);
        } catch (Exception e) {
            log.error("Beklenmeyen senkronizasyon hatasi", e);
            status.markMaintenance(StatusService.NEWS, "Beklenmeyen hata");
        } finally {
            running.set(false);
        }
        return added;
    }

    private int syncType(ContentType type, boolean notify) throws Exception {
        List<NewsScraper.ListEntry> entries = scraper.fetchList(type);
        if (entries.isEmpty()) {
            // Sayfa yapisi degismis olabilir.
            throw new IllegalStateException("liste bos / beklenen yapi bulunamadi");
        }
        int count = 0;
        List<NewsItem> fresh = new ArrayList<>();
        for (NewsScraper.ListEntry e : entries) {
            if (repo.existsByUrl(e.url())) {
                continue;
            }
            NewsScraper.Detail d = scraper.fetchDetail(e.url());
            NewsItem item = new NewsItem();
            item.setType(type);
            item.setUrl(e.url());
            item.setTitle(truncate(e.title(), 1000));
            item.setPublishedDate(e.date());
            item.setFetchedAt(Instant.now());
            if (d != null) {
                item.setContent(d.content());
                item.setSummary(NewsScraper.summarize(d.content()));
                item.setImageUrl(d.imageUrl());
            }
            fresh.add(repo.save(item));
            count++;
            Thread.sleep(REQUEST_DELAY_MS);
        }
        if (notify) {
            notifyNew(type, fresh);
        }
        return count;
    }

    /** En fazla 3 yeni kayit tek tek, fazlasi tek ozet bildirim olarak gider (gece toplu cekimde bildirim yagmuru olmasin). */
    private void notifyNew(ContentType type, List<NewsItem> fresh) {
        if (fresh.isEmpty()) {
            return;
        }
        NotificationType nt = switch (type) {
            case HABER -> NotificationType.NEWS;
            case DUYURU -> NotificationType.ANNOUNCEMENT;
            case ETKINLIK -> NotificationType.EVENT;
        };
        if (fresh.size() <= 3) {
            for (NewsItem n : fresh) {
                notifications.broadcast(nt, n.getTitle(), n.getSummary(), java.util.Map.of("newsId", String.valueOf(n.getId())));
            }
        } else {
            String count = String.valueOf(fresh.size());
            notifications.broadcastLocalized(nt, lang -> i18n.msg("notif.news.many." + type.name(), lang, count),
                    lang -> fresh.get(0).getTitle(), java.util.Map.of());
        }
    }

    private static String truncate(String s, int max) {
        return s.length() <= max ? s : s.substring(0, max);
    }
}
