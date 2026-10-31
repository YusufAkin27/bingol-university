package edu.bingol.backend.menu;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.ShortTx;
import edu.bingol.backend.media.ImageKind;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.menu.dto.MenuImageResponse;
import edu.bingol.backend.menu.dto.MenuResponse;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeParseException;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

/** Yonetici menu fotografi islemleri. Satir uydurulmaz: yalniz scraper'in yazdigi gunler. */
@Service
public class MenuAdminService {

    private static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");
    private static final int MAX_RANGE_DAYS = 366;

    private final MenuRepository repo;
    private final MediaService media;
    private final MenuCalorieService calories;

    /** Kisa DB islemi (T-068); yoksa dogrudan calisir (elle kurulan testler). */
    private ShortTx tx = ShortTx.direct();

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setTxManager(org.springframework.transaction.PlatformTransactionManager tm) {
        this.tx = ShortTx.of(tm);
    }

    public MenuAdminService(MenuRepository repo, MediaService media, MenuCalorieService calories) {
        this.repo = repo;
        this.media = media;
        this.calories = calories;
    }

    public static LocalDate parseDate(String raw) {
        try {
            return LocalDate.parse(raw == null ? "" : raw.trim());
        } catch (DateTimeParseException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "MENU_DATE_INVALID",
                    "Tarih yyyy-MM-dd biçiminde olmalıdır.");
        }
    }

    /** from/to bos ise icinde bulunulan ay. */
    @Transactional(readOnly = true)
    public List<MenuResponse> list(String fromRaw, String toRaw) {
        LocalDate today = LocalDate.now(ZONE);
        LocalDate from = fromRaw == null || fromRaw.isBlank() ? today.withDayOfMonth(1) : parseDate(fromRaw);
        LocalDate to = toRaw == null || toRaw.isBlank() ? from.withDayOfMonth(from.lengthOfMonth()) : parseDate(toRaw);
        if (to.isBefore(from) || from.plusDays(MAX_RANGE_DAYS).isBefore(to)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "MENU_RANGE_INVALID",
                    "Tarih aralığı geçersiz (en çok 366 gün).");
        }
        Map<LocalDate, Map<String, Integer>> kcal = calories.range(from, to);
        return repo.findByMenuDateBetweenOrderByMenuDate(from, to).stream()
                .map(d -> MenuResponse.of(d, kcal.getOrDefault(d.getMenuDate(), Map.of()))).toList();
    }

    /** Gorsel isleme islem DISINDA (T-068); yalniz URL yazimi kisa islemdedir. */
    public MenuImageResponse setImage(LocalDate date, MultipartFile file) {
        load(date); // yoksa gorsel islenmeden 404
        String url = media.storeImage(file, ImageKind.COVER).url();
        String old = tx.call(() -> {
            MenuDay day = load(date);
            String prev = day.getImageUrl();
            day.setImageUrl(url);
            repo.saveAndFlush(day);
            return prev;
        });
        if (old != null && !old.equals(url)) {
            media.release(old);
        }
        return new MenuImageResponse(date.toString(), url);
    }

    @Transactional
    public void deleteImage(LocalDate date) {
        MenuDay day = load(date);
        String old = day.getImageUrl();
        if (old == null) {
            return;
        }
        day.setImageUrl(null);
        repo.saveAndFlush(day);
        media.release(old);
    }

    private MenuDay load(LocalDate date) {
        return repo.findByMenuDate(date).orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND,
                "MENU_DAY_NOT_FOUND", "Bu tarih için menü kaydı bulunamadı."));
    }
}
