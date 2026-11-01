package edu.bingol.backend.menu;

import edu.bingol.backend.config.SyncProperties;
import edu.bingol.backend.status.StatusService;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneId;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

@Service
public class MenuSyncService {

    private static final Logger log = LoggerFactory.getLogger(MenuSyncService.class);

    private static final int MAX_ITEMS_LEN = 1000;
    private static final ZoneId ISTANBUL = ZoneId.of("Europe/Istanbul");
    /** Icinde bulunulan ayda bu kadar gun varsa yakalama kaynak siteye hic istek atmaz. */
    static final int CATCHUP_MIN_DAYS = 20;
    /** Yakalama denemeleri arasindaki en kisa sure (gunde en cok bir istek). */
    static final Duration CATCHUP_MIN_GAP = Duration.ofHours(20);
    /** Ay kismen doluysa (kaynak az gun yayinliyor olabilir) yalniz ayin ilk haftasinda yeniden denenir. */
    static final int CATCHUP_PARTIAL_UNTIL_DAY = 7;

    private final MenuScraper scraper;
    private final MenuRepository repo;
    private final StatusService status;
    private final AtomicBoolean running = new AtomicBoolean();
    private final SyncProperties props;
    private final Clock clock;

    private edu.bingol.backend.status.SyncExecutor syncExecutor;

    @Autowired(required = false)
    void setSyncExecutor(edu.bingol.backend.status.SyncExecutor syncExecutor) {
        this.syncExecutor = syncExecutor;
    }

    @Autowired
    public MenuSyncService(MenuScraper scraper, MenuRepository repo, StatusService status, SyncProperties props) {
        this(scraper, repo, status, props, Clock.system(ISTANBUL));
    }

    MenuSyncService(MenuScraper scraper, MenuRepository repo, StatusService status, SyncProperties props, Clock clock) {
        this.props = props;
        this.scraper = scraper;
        this.repo = repo;
        this.status = status;
        this.clock = clock;
    }

    /** Sadece ilk kurulumda (tablo bos) bir kez doldurur. */
    @EventListener(ApplicationReadyEvent.class)
    public void initialFill() {
        if (props.initialFill() && repo.count() == 0) {
            // Acilisi bloklamasin (saglik kontrolu hemen UP olsun): ilk dolum arka planda
            edu.bingol.backend.status.SyncExecutor.dispatch(syncExecutor, this::sync);
        }
    }

    /** Ayda bir: ayin son gunu 23:30 (Istanbul). Ayar: menu.sync.cron */
    @Scheduled(cron = "${menu.sync.cron:0 30 23 L * *}", zone = "Europe/Istanbul")
    public void scheduledSync() {
        sync();
    }

    /**
     * Gunluk 06:00 yakalama (K20, CLAUDE.md "cron sikilastirma" kuralina bilincli istisna): ay sonu cekimi basarisiz
     * ya da yeni ay menusu gec yayinlanmissa bir ay beklenmesin. Kaynak siteye YALNIZ icinde bulunulan ayin menusu
     * eksikse (bkz. {@link #catchUp()}) ve son denemeden beri en az 20 saat gectiyse gidilir; ay doluysa istek atilmaz.
     * Ayar: menu.catchup.cron
     */
    @Scheduled(cron = "${menu.catchup.cron:0 0 6 * * *}", zone = "Europe/Istanbul")
    public void scheduledCatchUp() {
        catchUp();
    }

    /** Kaynaga gidildiyse true. Exception firlatmaz. */
    boolean catchUp() {
        try {
            LocalDate today = LocalDate.now(clock);
            YearMonth ym = YearMonth.from(today);
            long days = repo.countByMenuDateBetween(ym.atDay(1), ym.atEndOfMonth());
            if (days >= CATCHUP_MIN_DAYS) {
                return false;
            }
            if (days > 0 && today.getDayOfMonth() > CATCHUP_PARTIAL_UNTIL_DAY) {
                return false;
            }
            Instant last = status.find(StatusService.MENU).map(s -> s.getLastAttemptAt()).orElse(null);
            if (last != null && Duration.between(last, clock.instant()).compareTo(CATCHUP_MIN_GAP) < 0) {
                return false;
            }
            log.info("Yemek listesi yakalama: {} icin {} gun var, kaynak denenecek", ym, days);
            sync();
            return true;
        } catch (Exception e) {
            log.warn("Yemek listesi yakalama atlandi: {}", e.toString());
            return false;
        }
    }

    /** Eklenen/guncellenen gun sayisini doner; -1 = bakim durumu. Exception firlatmaz. */
    public int sync() {
        if (!running.compareAndSet(false, true)) {
            return 0;
        }
        try {
            List<MenuScraper.Day> days = scraper.fetch();
            if (days.isEmpty()) {
                failed("Yemek listesi sayfasinda beklenen tablo bulunamadi");
                return -1;
            }
            int changed = 0;
            for (MenuScraper.Day d : days) {
                // Tek gunun hatasi (uzun metin, kisit ihlali) tum senkronu bakima sokmasin: o gunu atla, devam et
                try {
                    String items = fit(String.join("\n", d.items()));
                    MenuDay row = repo.findByMenuDate(d.date()).orElseGet(() -> {
                        MenuDay m = new MenuDay();
                        m.setMenuDate(d.date());
                        return m;
                    });
                    if (!items.equals(row.getItems())) {
                        row.setItems(items);
                        repo.save(row);
                        changed++;
                    }
                } catch (Exception e) {
                    log.warn("Yemek gunu atlandi ({}): {}", d.date(), e.toString());
                }
            }
            status.markOk(StatusService.MENU, null);
            log.info("Yemek listesi senkronizasyonu bitti: {} gun guncellendi", changed);
            return changed;
        } catch (Exception e) {
            log.warn("Yemek listesi alinamadi: {}", e.toString());
            failed("Kaynak site okunamadi");
            return -1;
        } finally {
            running.set(false);
        }
    }

    /**
     * Basarisiz cekimde bakim bandi YALNIZ icinde bulunulan ayin menusu bossa gosterilir (ay sonu cekimi tutmadiysa
     * eldeki ay menusu sunulmaya devam eder); aksi halde yalniz deneme zamani yazilir.
     */
    private void failed(String message) {
        boolean currentMonthHasMenu;
        try {
            YearMonth ym = YearMonth.now(clock);
            currentMonthHasMenu = repo.countByMenuDateBetween(ym.atDay(1), ym.atEndOfMonth()) > 0;
        } catch (Exception e) {
            currentMonthHasMenu = false;
        }
        if (currentMonthHasMenu) {
            status.markAttempt(StatusService.MENU, message);
        } else {
            status.markMaintenance(StatusService.MENU, message);
        }
    }

    /** menu_day.items 1000 karakterle sinirli; tasan kayit tum senkronu bozmasin diye satir sinirinda kirpilir. */
    static String fit(String items) {
        if (items.length() <= MAX_ITEMS_LEN) {
            return items;
        }
        int cut = items.lastIndexOf('\n', MAX_ITEMS_LEN);
        return items.substring(0, cut > 0 ? cut : MAX_ITEMS_LEN);
    }
}
