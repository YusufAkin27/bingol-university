package edu.bingol.backend.unitnews;

import edu.bingol.backend.config.SyncProperties;
import edu.bingol.backend.status.SyncExecutor;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.function.LongSupplier;
import java.util.concurrent.atomic.AtomicBoolean;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
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

    /** Toplu senkronun toplam sure butcesi (haber senkronundaki T-074 gibi); asilirsa kalan kaynaklar sonraki geceye. */
    private Duration budget = Duration.ofMinutes(45);
    private LongSupplier nanoClock = System::nanoTime;
    private volatile boolean deadlineActive;
    private volatile long deadlineNanos;
    private SyncExecutor syncExecutor;

    /** Istekler arasi bekleme (CLAUDE.md: 500 ms alti olmaz); testlerde 0. */
    private long pauseMs = 600;
    private java.util.function.LongConsumer sleeper = ms -> {
        try {
            Thread.sleep(ms);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    };

    /** Detayi okunamayan adresin ardisik basarisiz deneme sayisi (bellekte, sinirli; yeniden baslatmada sifirlanir). */
    static final int MAX_DETAIL_FAILURES = 3;
    private final java.util.Map<String, Integer> detailFailures = java.util.Collections.synchronizedMap(
            new java.util.LinkedHashMap<>() {
                @Override
                protected boolean removeEldestEntry(java.util.Map.Entry<String, Integer> eldest) {
                    return size() > 2000;
                }
            });

    public UnitNewsSyncService(UnitSiteScraper scraper, UnitSourceRepository sources, UnitDepartmentRepository depts,
                               UnitAnnouncementRepository anns, JdbcTemplate jdbc, SyncProperties props) {
        this.scraper = scraper;
        this.sources = sources;
        this.depts = depts;
        this.anns = anns;
        this.jdbc = jdbc;
        this.props = props;
    }

    @Autowired(required = false)
    void setSyncExecutor(SyncExecutor syncExecutor) {
        this.syncExecutor = syncExecutor;
    }

    @Autowired(required = false)
    void setBudgetMinutes(@Value("${unitnews.sync.budget-minutes:45}") int minutes) {
        this.budget = Duration.ofMinutes(Math.max(1, minutes));
    }

    /** Testler: sure butcesi ve saat. */
    void setBudget(Duration budget) {
        this.budget = budget;
    }

    void setNanoClock(LongSupplier nanoClock) {
        this.nanoClock = nanoClock;
    }

    private boolean overBudget() {
        return deadlineActive && nanoClock.getAsLong() - deadlineNanos > 0;
    }

    void setPauseMs(long ms) {
        this.pauseMs = ms;
    }

    /** Testler: bekleme yerine kayit (istek sirasinin 500 ms kuralina uydugunu dogrulamak icin). */
    void setSleeper(java.util.function.LongConsumer sleeper) {
        this.sleeper = sleeper;
    }

    /** Yalniz ilk kurulumda (hic duyuru yok) arka planda bir kez doldurur. */
    @EventListener(ApplicationReadyEvent.class)
    public void initialFill() {
        if (props.initialFill() && anns.count() == 0) {
            SyncExecutor.dispatch(syncExecutor, this::syncAll);
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
            // En eski denenen kaynak once (sure butcesi dolarsa hep ayni son kaynaklar aclik cekmesin); esitlikte kod sirasi
            List<UnitSource> order = new ArrayList<>(sources.findByEnabledTrueOrderByCodeAsc());
            order.sort(Comparator.comparing(UnitSource::getLastAttemptAt, Comparator.nullsFirst(Comparator.naturalOrder())));
            deadlineNanos = nanoClock.getAsLong() + budget.toNanos();
            deadlineActive = true;
            List<String> skipped = new ArrayList<>();
            for (UnitSource listed : order) {
                if (overBudget()) {
                    skipped.add(listed.getCode());
                    continue;
                }
                // liste senkron baslarken okundu; sirasi gelene kadar yonetici kapatmis olabilir (A2)
                UnitSource s = sources.findById(listed.getCode()).filter(UnitSource::isEnabled).orElse(null);
                if (s == null) {
                    continue;
                }
                total += syncOne(s);
                pause();
            }
            if (!skipped.isEmpty()) {
                log.warn("Birim haberleri sure butcesi ({} dk) doldu, {} kaynak sonraki geceye kaldi", budget.toMinutes(),
                        skipped.size());
                noteSkipped(skipped);
            }
            purgeOld();
            return total;
        } catch (RuntimeException e) {
            log.warn("Birim haberleri senkronu hata verdi: {}", e.toString());
            return 0;
        } finally {
            deadlineActive = false;
            running.set(false);
        }
    }

    /** Butce nedeniyle atlanan kaynaklara not duser (yalniz last_message; baska alana dokunulmaz). */
    private void noteSkipped(List<String> codes) {
        for (String code : codes) {
            try {
                jdbc.update("UPDATE unit_source SET last_message = ? WHERE code = ?",
                        "Sure butcesi doldu, sonraki turda denenecek", code);
            } catch (RuntimeException e) {
                log.warn("Birim kaynagi notu yazilamadi ({}): {}", code, e.toString());
            }
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
            if (refreshDepartmentsIfDue(s)) {
                pause(); // bolum yenilemesinin son istegi ile genel akis istegi arasi (CLAUDE.md: >= 500 ms)
            }
            boolean first = anns.countBySourceCode(s.getCode()) == 0;
            added = syncFeed(s, GENERAL_FEED, null, first, true);
            for (UnitDepartment d : depts.findBySourceCodeOrderByNameAsc(s.getCode())) {
                if (overBudget()) {
                    log.info("Sure butcesi doldu, {} kaynaginin kalan bolum akislari sonraki geceye", s.getCode());
                    break;
                }
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
        saveState(s);
        return added;
    }

    /**
     * Durum alanlarini TEK {@code UPDATE} ile yazar (A2): senkron dakikalarca surebilir; yonetici bu arada kaynagi
     * kapatabilir/{@code faculty_keys}'i degistirebilir. Tum satiri kaydetmek (JPA save) o ayari bayat degerle ezerdi.
     * enabled/faculty_keys/graduate/ad hic yazilmaz.
     */
    private void saveState(UnitSource s) {
        try {
            jdbc.update("UPDATE unit_source SET last_attempt_at = ?, last_success_at = ?, departments_checked_at = ?, "
                    + "last_message = ?, maintenance = ? WHERE code = ?", ts(s.getLastAttemptAt()), ts(s.getLastSuccessAt()),
                    ts(s.getDepartmentsCheckedAt()), s.getLastMessage(), s.isMaintenance(), s.getCode());
        } catch (RuntimeException e) {
            log.warn("Birim kaynagi durumu yazilamadi ({}): {}", s.getCode(), e.toString());
        }
    }

    private static java.sql.Timestamp ts(Instant i) {
        return i == null ? null : java.sql.Timestamp.from(i);
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
                detailFailures.remove(e.url());
            } catch (Exception ex) {
                // Gecici ag hatasi kaydi kalici eksik (govdesiz/eksuz) birakmasin (A5): kaydetme, sonraki gece yeniden
                // denenir. Kalici bozuk sayfa sonsuza dek denenmesin diye MAX_DETAIL_FAILURES'ten sonra baslik +
                // baglantiyla kaydedilir.
                int n = detailFailures.merge(e.url(), 1, Integer::sum);
                if (n < MAX_DETAIL_FAILURES) {
                    log.debug("Detay okunamadi {} (deneme {}): {}", e.url(), n, ex.toString());
                    continue;
                }
                log.debug("Detay {} kez okunamadi, baslik+baglanti kaydediliyor {}: {}", n, e.url(), ex.toString());
                detailFailures.remove(e.url());
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

    /** Bolum listesi bu cagrida siteden okunduysa (ag istegi yapildiysa) true. */
    private boolean refreshDepartmentsIfDue(UnitSource s) throws Exception {
        Instant due = Instant.now().minus(DEPT_REFRESH_DAYS, ChronoUnit.DAYS);
        if (s.getDepartmentsCheckedAt() != null && s.getDepartmentsCheckedAt().isAfter(due)) {
            return false;
        }
        List<UnitSiteScraper.Dept> found = scraper.fetchDepartments(s.getBaseUrl());
        List<UnitDepartment> existing = depts.findBySourceCodeOrderByNameAsc(s.getCode());
        Set<String> seen = new HashSet<>();
        for (UnitSiteScraper.Dept d : found) {
            String key = UnitKeys.deptKey(d.name());
            // sutun sinirlari (V1050): uzun slug/ad tek bolumu atlatir, kaynagi bakima dusurmez (A8)
            if (key == null || d.slug() == null || d.slug().isBlank() || d.slug().length() > UnitSiteScraper.MAX_SLUG_LEN) {
                continue;
            }
            try {
                UnitDepartment row = existing.stream().filter(x -> x.getSlug().equals(d.slug())).findFirst().orElse(null);
                if (row == null) {
                    row = new UnitDepartment();
                    row.setSourceCode(s.getCode());
                    row.setSlug(d.slug());
                }
                row.setName(UnitSiteScraper.cut(d.name(), 200));
                row.setNameKey(key);
                if (!d.slug().startsWith("x-")) {
                    pause();
                    try {
                        String feed = scraper.fetchFeedPath(s.getBaseUrl(), d.slug());
                        row.setFeedPath(feed != null && feed.length() <= UnitSiteScraper.MAX_FEED_PATH_LEN ? feed : null);
                    } catch (Exception e) {
                        log.debug("Bolum sayfasi okunamadi {} {}: {}", s.getCode(), d.slug(), e.toString());
                    }
                }
                depts.save(row);
                seen.add(d.slug());
            } catch (RuntimeException e) {
                log.warn("Bolum kaydedilemedi ({} {}): {}", s.getCode(), d.slug(), e.toString());
            }
        }
        if (!found.isEmpty()) {
            removeVanishedDepartments(s, existing, seen);
            s.setDepartmentsCheckedAt(Instant.now());
        }
        return true; // fetchDepartments en az ana sayfa istegi yapti
    }

    /**
     * Siteden kalkan bolumleri siler (A8): aksi halde eski bolum adi hala eslesir ve olu bir akisa baglanir. Ayristirma
     * kismen basarisiz olduysa (bulunan sayi eskinin yarisindan azsa) hicbir sey silinmez; sonraki yenilemede toparlanir.
     */
    private void removeVanishedDepartments(UnitSource s, List<UnitDepartment> existing, Set<String> seen) {
        if (existing.isEmpty() || seen.size() * 2 < existing.size()) {
            if (!existing.isEmpty()) {
                log.warn("Bolum listesi beklenenden kisa ({} < {}/2), eski bolumler silinmedi: {}", seen.size(),
                        existing.size(), s.getCode());
            }
            return;
        }
        for (UnitDepartment old : existing) {
            if (!seen.contains(old.getSlug())) {
                try {
                    depts.delete(old);
                } catch (RuntimeException e) {
                    log.warn("Eski bolum silinemedi ({} {}): {}", s.getCode(), old.getSlug(), e.toString());
                }
            }
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
            sleeper.accept(pauseMs);
        }
    }

    private static String shorten(String s) {
        return s.length() <= 300 ? s : s.substring(0, 300);
    }
}
