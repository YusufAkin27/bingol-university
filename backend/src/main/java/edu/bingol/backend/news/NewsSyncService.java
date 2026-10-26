package edu.bingol.backend.news;

import edu.bingol.backend.config.SyncProperties;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.status.StatusService;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

@Service
public class NewsSyncService {

    private static final Logger log = LoggerFactory.getLogger(NewsSyncService.class);
    /** Siteyi yormamak icin ardisik detay istekleri arasindaki bekleme. */
    private static final long REQUEST_DELAY_MS = 500;
    private static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");
    private static final int MAX_CONTENT_ATTEMPTS = 5;
    private static final int RETRY_BATCH = 20;
    /** Gece cekimi gunde bir kez calistigindan ayni kayit en cok gunde bir denenir. */
    private static final Duration RETRY_INTERVAL = Duration.ofHours(20);

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
            retryMissingContentSafely();
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

    private void retryMissingContentSafely() {
        try {
            log.info("Icerigi eksik {} kayit tamamlandi", retryMissingContent());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        } catch (Exception e) {
            log.warn("Icerik yeniden deneme basarisiz: {}", e.toString());
        }
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
            Instant now = Instant.now();
            NewsItem item = new NewsItem();
            item.setType(type);
            item.setUrl(e.url());
            item.setTitle(truncate(e.title(), 1000));
            item.setFetchedAt(now);
            item.setPublishedDate(e.date() != null ? e.date() : LocalDate.ofInstant(now, ZONE));
            applyDetail(item, scraper.fetchDetail(e.url()), now);
            fresh.add(repo.save(item));
            count++;
            Thread.sleep(REQUEST_DELAY_MS);
        }
        if (notify) {
            notifyNew(type, fresh);
        }
        return count;
    }

    /** Detay sonucunu kayda isler; null ise deneme sayaci artar ki bos kalan kayit sinirli sayida yeniden denensin. */
    private static void applyDetail(NewsItem item, NewsScraper.Detail d, Instant now) {
        item.setContentAttempts(item.getContentAttempts() + 1);
        item.setContentAttemptedAt(now);
        if (d == null) {
            return;
        }
        item.setContent(d.content());
        item.setSummary(NewsScraper.summarize(d.content()));
        item.setImageUrl(d.imageUrl());
        if (item.getType() == ContentType.ETKINLIK) {
            item.setEventDate(d.eventDate());
        }
    }

    /** Detayi alinamamis kayitlari gunde bir kez, en cok MAX_CONTENT_ATTEMPTS denemeye kadar tekrar dener. */
    private int retryMissingContent() throws InterruptedException {
        Instant now = Instant.now();
        List<NewsItem> pending = repo.findContentRetryCandidates(MAX_CONTENT_ATTEMPTS,
                now.minus(RETRY_INTERVAL), PageRequest.of(0, RETRY_BATCH));
        int filled = 0;
        for (NewsItem item : pending) {
            applyDetail(item, scraper.fetchDetail(item.getUrl()), now);
            repo.save(item);
            if (item.getContent() != null) {
                filled++;
            }
            Thread.sleep(REQUEST_DELAY_MS);
        }
        return filled;
    }

    /** En fazla 3 yeni kayit tek tek, fazlasi tek ozet bildirim olarak gider (gece toplu cekimde bildirim yagmuru olmasin). */
    private void notifyNew(ContentType type, List<NewsItem> all) {
        // Gizlenmis kayit icin bildirim gitmez
        List<NewsItem> fresh = all.stream().filter(n -> !n.isHidden()).toList();
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
