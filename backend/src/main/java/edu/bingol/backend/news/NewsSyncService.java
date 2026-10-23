package edu.bingol.backend.news;

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

    public NewsSyncService(NewsScraper scraper, NewsRepository repo, StatusService status) {
        this.scraper = scraper;
        this.repo = repo;
        this.status = status;
    }

    /** Sadece ilk kurulumda (veritabani bos) bir kez doldurur; sonraki acilislarda siteye istek atmaz. */
    @EventListener(ApplicationReadyEvent.class)
    public void initialFill() {
        if (repo.count() == 0) {
            sync();
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
            List<String> failures = new ArrayList<>();
            for (ContentType type : ContentType.values()) {
                try {
                    added.put(type, syncType(type));
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

    private int syncType(ContentType type) throws Exception {
        List<NewsScraper.ListEntry> entries = scraper.fetchList(type);
        if (entries.isEmpty()) {
            // Sayfa yapisi degismis olabilir.
            throw new IllegalStateException("liste bos / beklenen yapi bulunamadi");
        }
        int count = 0;
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
            repo.save(item);
            count++;
            Thread.sleep(REQUEST_DELAY_MS);
        }
        return count;
    }

    private static String truncate(String s, int max) {
        return s.length() <= max ? s : s.substring(0, max);
    }
}
