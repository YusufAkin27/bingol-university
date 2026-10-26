package edu.bingol.backend.menu;

import edu.bingol.backend.config.SyncProperties;
import edu.bingol.backend.status.StatusService;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

@Service
public class MenuSyncService {

    private static final Logger log = LoggerFactory.getLogger(MenuSyncService.class);

    private static final int MAX_ITEMS_LEN = 1000;

    private final MenuScraper scraper;
    private final MenuRepository repo;
    private final StatusService status;
    private final AtomicBoolean running = new AtomicBoolean();
    private final SyncProperties props;

    public MenuSyncService(MenuScraper scraper, MenuRepository repo, StatusService status, SyncProperties props) {
        this.props = props;
        this.scraper = scraper;
        this.repo = repo;
        this.status = status;
    }

    /** Sadece ilk kurulumda (tablo bos) bir kez doldurur. */
    @EventListener(ApplicationReadyEvent.class)
    public void initialFill() {
        if (props.initialFill() && repo.count() == 0) {
            // Acilisi bloklamasin (saglik kontrolu hemen UP olsun): ilk dolum arka planda
            java.util.concurrent.CompletableFuture.runAsync(this::sync);
        }
    }

    /** Ayda bir: ayin son gunu 23:30 (Istanbul). Ayar: menu.sync.cron */
    @Scheduled(cron = "${menu.sync.cron:0 30 23 L * *}", zone = "Europe/Istanbul")
    public void scheduledSync() {
        sync();
    }

    /** Eklenen/guncellenen gun sayisini doner; -1 = bakim durumu. Exception firlatmaz. */
    public int sync() {
        if (!running.compareAndSet(false, true)) {
            return 0;
        }
        try {
            List<MenuScraper.Day> days = scraper.fetch();
            if (days.isEmpty()) {
                status.markMaintenance(StatusService.MENU, "Yemek listesi sayfasinda beklenen tablo bulunamadi");
                return -1;
            }
            int changed = 0;
            for (MenuScraper.Day d : days) {
                String items = String.join("\n", d.items());
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
            }
            status.markOk(StatusService.MENU, null);
            log.info("Yemek listesi senkronizasyonu bitti: {} gun guncellendi", changed);
            return changed;
        } catch (Exception e) {
            log.warn("Yemek listesi alinamadi: {}", e.toString());
            status.markMaintenance(StatusService.MENU, "Kaynak site okunamadi");
            return -1;
        } finally {
            running.set(false);
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
