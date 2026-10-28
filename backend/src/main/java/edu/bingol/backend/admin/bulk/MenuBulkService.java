package edu.bingol.backend.admin.bulk;

import edu.bingol.backend.admin.bulk.BulkDtos.Report;
import edu.bingol.backend.admin.bulk.BulkSupport.Tally;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.menu.MenuAdminService;
import edu.bingol.backend.menu.MenuDay;
import edu.bingol.backend.menu.MenuRepository;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Menu gunlerini toplu siler. Her gun KENDI islemiyle silinir; satir silindikten (islem tamamlandiktan) sonra gorsel
 * dosyasi {@link MediaService#release} ile serbest birakilir (baska kayit kullaniyorsa dosya kalir). Satir
 * uydurulmaz: yalniz var olan gunler silinir. Not: kaynak site aylik senkronda silinen gunu yeniden yazabilir.
 */
@Service
public class MenuBulkService {

    private static final Logger log = LoggerFactory.getLogger(MenuBulkService.class);

    private final MenuRepository repo;
    private final MediaService media;
    private final TransactionTemplate tx;

    public MenuBulkService(MenuRepository repo, MediaService media, TransactionTemplate tx) {
        this.repo = repo;
        this.media = media;
        this.tx = tx;
    }

    /** Tarih dizgelerini ayristirir (gecersiz -> 400 MENU_DATE_INVALID, hicbir sey silinmez); tekrarlar atilir. */
    public static List<LocalDate> parse(List<String> raw) {
        LinkedHashSet<LocalDate> out = new LinkedHashSet<>();
        for (String s : raw) {
            out.add(MenuAdminService.parseDate(s));
        }
        return new ArrayList<>(out);
    }

    public Report delete(List<LocalDate> dates) {
        Tally t = new Tally();
        for (LocalDate d : dates) {
            try {
                // null: gun yok; "" : gorsel yoktu; aksi: serbest birakilacak gorsel adresi
                String image = tx.execute(status -> {
                    Optional<MenuDay> day = repo.findByMenuDate(d);
                    if (day.isEmpty()) {
                        return null;
                    }
                    String url = day.get().getImageUrl();
                    repo.delete(day.get());
                    repo.flush();
                    return url == null ? "" : url;
                });
                if (image == null) {
                    t.skipped(d, "NOT_FOUND");
                } else {
                    if (!image.isEmpty()) {
                        media.release(image);
                    }
                    t.done(d);
                }
            } catch (RuntimeException e) {
                log.warn("Toplu menu silme hatasi: {} {}", d, e.toString());
                t.failed(d, "INTERNAL_ERROR");
            }
        }
        return t.report();
    }
}
