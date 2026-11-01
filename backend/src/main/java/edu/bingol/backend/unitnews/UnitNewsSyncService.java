package edu.bingol.backend.unitnews;

import edu.bingol.backend.config.SyncProperties;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.concurrent.atomic.AtomicBoolean;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

/**
 * Alt sitelerin duyurularini zamanlayiciyla ceker (CLAUDE.md bolum 5: API istegi sirasinda asla). Her kaynak icin
 * genel akis ({@code /duyurular/}) + bolumun kendi akislari; yalniz YENI adreslerin detayi cekilir. Hata cagirana
 * sizmaz: kaynak "bakim" durumuna gecer, eski veri sunulur. Ag erisimi islem DISINDA; her kayit kendi kisa islemindedir.
 */
@Service
public class UnitNewsSyncService {

    private static final Logger log = LoggerFactory.getLogger(UnitNewsSyncService.class);
    private static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");
    static final String GENERAL_FEED = "/duyurular/";
    static final int RECENT_DAYS = 90;
    static final int INITIAL_PER_FEED = 60;
    static final int REGULAR_PER_FEED = 30;
    static final int RETENTION_DAYS = 365;
    private static final int DEPT_REFRESH_DAYS = 7;
    private static final int PURGE_CHUNK = 1000;

    private final UnitSiteScraper scraper;
    private final UnitSourceRepository sources;
    private final UnitDepartmentRepository depts;
    private final UnitAnnouncementRepository anns;
    private final JdbcTemplate jdbc;
    private final SyncProperties props;
    private final UnitAttachmentsJson json = new UnitAttachmentsJson();
    private final AtomicBoolean running = new AtomicBoolean();

    /** Istekler arasi bekleme (CLAUDE.md: 500 ms alti olmaz); testlerde 0. */
    private long pauseMs = 600;

    public UnitNewsSyncService(UnitSiteScraper scraper, UnitSourceRepository sources, UnitDepartmentRepository depts,
                               UnitAnnouncementRepository anns, JdbcTemplate jdbc, SyncProperties props) {
        this.scraper = scraper;
        this.sources = sources;
        this.depts = depts;
        this.anns = anns;
        this.jdbc = jdbc;
        this.props = props;
    }

    void setPauseMs(long ms) {
        this.pauseMs = ms;
    }

    /** Yalniz ilk kurulumda (hic duyuru yok) arka planda bir kez doldurur. */
    @EventListener(ApplicationReadyEvent.class)
    public void initialFill() {
        if (props.initialFill() && anns.count() == 0) {
            java.util.concurrent.CompletableFuture.runAsync(this::syncAll);
        }
    }

    /** Her gece 01:00 (Istanbul). Ayar: unitnews.sync.cron */
    @Scheduled(cron = "${unitnews.sync.cron:0 0 1 * * *}", zone = "Europe/Istanbul")
    public void scheduledSync() {
        syncAll();
    }

    /** Etkin tum kaynaklari sirayla ceker; toplam yeni kayit sayisini doner (zaten calisiyorsa 0). Exception firlatmaz. */
    public int syncAll() {
        if (!running.compareAndSet(false, true)) {
            return 0;
        }
        try {
            int total = 0;
            for (UnitSource s : sources.findByEnabledTrueOrderByCodeAsc()) {
                total += syncOne(s);
                pause();
            }
            purgeOld();
            return total;
        } catch (RuntimeException e) {
            log.warn("Birim haberleri senkronu hata verdi: {}", e.toString());
            return 0;
        } finally {
            running.set(false);
        }
    }

    /** Tek kaynak (yonetici elle tetikleme); kapali kaynak da calistirilabilir. Bulunamazsa -1. */
    public int sync(String code) {
        UnitSource s = sources.findById(code).orElse(null);
        if (s == null) {
            return -1;
        }
        if (!running.compareAndSet(false, true)) {
            return 0;
        }
        try {
            return syncOne(s);
        } finally {
            running.set(false);
        }
    }

    public boolean isRunning() {
        return running.get();
    }

    // ---- ic ----

    int syncOne(UnitSource s) {
        s.setLastAttemptAt(Instant.now());
        int added = 0;
        try {
            refreshDepartmentsIfDue(s);
            boolean first = anns.countBySourceCode(s.getCode()) == 0;
            added = syncFeed(s, GENERAL_FEED, null, first, true);
            for (UnitDepartment d : depts.findBySourceCodeOrderByNameAsc(s.getCode())) {
                if (d.getFeedPath() != null) {
                    pause();
                    try {
                        added += syncFeed(s, d.getFeedPath(), d.getSlug(), first, false);
                    } catch (Exception e) {
                        log.warn("Bolum akisi atlandi ({} {}): {}", s.getCode(), d.getSlug(), e.toString());
                    }
                }
            }
            s.setLastSuccessAt(Instant.now());
            s.setMaintenance(false);
            s.setLastMessage(added + " yeni duyuru");
        } catch (Exception e) {
            // genel akis okunamadi ya da bos: yapi degismis/ulasilamiyor -> bakim, eski veri sunulur
            s.setMaintenance(true);
            s.setLastMessage(shorten(e.toString()));
            log.warn("Birim kaynagi alinamadi ({}): {}", s.getCode(), e.toString());
        }
        sources.save(s);
        return added;
    }

    private int syncFeed(UnitSource s, String feedPath, String deptSlug, boolean first, boolean required)
            throws Exception {
        List<UnitSiteScraper.ListEntry> entries = scraper.fetchList(s.getBaseUrl(), feedPath);
        if (entries.isEmpty()) {
            if (required) {
                throw new IllegalStateException("Duyuru listesinde kayit bulunamadi (site yapisi degismis olabilir)");
            }
            return 0;
        }
        Set<String> known = new HashSet<>();
        anns.findByUrlIn(entries.stream().map(UnitSiteScraper.ListEntry::url).toList())
                .forEach(a -> known.add(a.getUrl()));
        LocalDate cutoff = LocalDate.now(ZONE).minusDays(RECENT_DAYS);
        List<UnitSiteScraper.ListEntry> fresh = new ArrayList<>();
        for (UnitSiteScraper.ListEntry e : entries) {
            if (!known.contains(e.url()) && !e.date().isBefore(cutoff)) {
                fresh.add(e);
            }
        }
        fresh.sort((a, b) -> b.date().compareTo(a.date()));
        int cap = first ? INITIAL_PER_FEED : REGULAR_PER_FEED;
        int added = 0;
        for (UnitSiteScraper.ListEntry e : fresh.subList(0, Math.min(cap, fresh.size()))) {
            pause();
            UnitSiteScraper.Detail d;
            try {
                d = scraper.fetchDetail(e.url());
            } catch (Exception ex) {
                // detay okunamadi: yine de kaydet (baslik + baglanti); tekrar denenmez
                log.debug("Detay okunamadi {}: {}", e.url(), ex.toString());
                d = new UnitSiteScraper.Detail("", List.of(), null);
            }
            UnitAnnouncement a = new UnitAnnouncement();
            a.setSourceCode(s.getCode());
            a.setDeptSlug(deptSlug);
            a.setTitle(e.title());
            a.setUrl(e.url());
            a.setPublishedDate(e.date());
            a.setBody(d.body().isBlank() ? null : d.body());
            a.setSummary(UnitSiteScraper.summaryOf(d.body(), e.title()));
            a.setAttachments(d.attachments().isEmpty() ? null : json.write(d.attachments()));
            try {
                anns.save(a);
                added++;
            } catch (org.springframework.dao.DataIntegrityViolationException dup) {
                log.debug("Kayit zaten var {}", e.url()); // es zamanli calisma: url benzersiz
            }
        }
        return added;
    }

    private void refreshDepartmentsIfDue(UnitSource s) throws Exception {
        Instant due = Instant.now().minus(DEPT_REFRESH_DAYS, ChronoUnit.DAYS);
        if (s.getDepartmentsCheckedAt() != null && s.getDepartmentsCheckedAt().isAfter(due)) {
            return;
        }
        List<UnitSiteScraper.Dept> found = scraper.fetchDepartments(s.getBaseUrl());
        for (UnitSiteScraper.Dept d : found) {
            String key = UnitKeys.deptKey(d.name());
            if (key == null) {
                continue;
            }
            UnitDepartment row = depts.findBySourceCodeOrderByNameAsc(s.getCode()).stream()
                    .filter(x -> x.getSlug().equals(d.slug())).findFirst().orElse(null);
            if (row == null) {
                row = new UnitDepartment();
                row.setSourceCode(s.getCode());
                row.setSlug(d.slug());
            }
            row.setName(d.name());
            row.setNameKey(key);
            if (!d.slug().startsWith("x-")) {
                pause();
                try {
                    row.setFeedPath(scraper.fetchFeedPath(s.getBaseUrl(), d.slug()));
                } catch (Exception e) {
                    log.debug("Bolum sayfasi okunamadi {} {}: {}", s.getCode(), d.slug(), e.toString());
                }
            }
            depts.save(row);
        }
        if (!found.isEmpty()) {
            s.setDepartmentsCheckedAt(Instant.now());
        }
    }

    /** 365 gunden eski kayitlari kucuk parcalarla siler (bagimli tablo yok). */
    void purgeOld() {
        LocalDate cutoff = LocalDate.now(ZONE).minusDays(RETENTION_DAYS);
        try {
            int n;
            do {
                n = jdbc.update("DELETE FROM unit_announcement WHERE id IN (SELECT id FROM unit_announcement "
                        + "WHERE published_date < ? ORDER BY id LIMIT " + PURGE_CHUNK + ")", java.sql.Date.valueOf(cutoff));
            } while (n >= PURGE_CHUNK);
        } catch (RuntimeException e) {
            log.warn("Eski birim duyurulari silinemedi: {}", e.toString());
        }
    }

    private void pause() {
        if (pauseMs > 0) {
            try {
                Thread.sleep(pauseMs);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
    }

    private static String shorten(String s) {
        return s.length() <= 300 ? s : s.substring(0, 300);
    }
}
