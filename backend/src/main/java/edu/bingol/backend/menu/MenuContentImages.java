package edu.bingol.backend.menu;

import edu.bingol.backend.common.Hashing;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeSet;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Menu gorseli tarihe degil ICERIGE baglidir. Ozet = yemek adlarinin normalize (MenuItemKey), siralamasiz SHA-256'si:
 * birebir ayni menu (baska ay/gun) ayni gorseli kendiliginden alir; kaynak site menude en ufak degisiklik yaparsa ozet
 * degisir, eslesme kalmaz ve gun gorselsiz ("yeni gorsel bekliyor") doner. Senkron bu sinifa dokunmaz: eslesme okuma
 * aninda cozulur, bu yuzden eski gorsel yanlis menude asla gosterilmez.
 */
@Service
public class MenuContentImages {

    private static final Logger log = LoggerFactory.getLogger(MenuContentImages.class);
    private static final int CHUNK = 500;

    private final MenuContentImageRepository images;
    private final MenuRepository days;

    public MenuContentImages(MenuContentImageRepository images, MenuRepository days) {
        this.images = images;
        this.days = days;
    }

    /** Bos menu icin null (eslesecek icerik yok). */
    public static String hash(String items) {
        TreeSet<String> keys = new TreeSet<>();
        if (items != null) {
            for (String it : items.split("\n")) {
                String k = MenuItemKey.of(it);
                if (!k.isEmpty()) {
                    keys.add(k);
                }
            }
        }
        return keys.isEmpty() ? null : Hashing.sha256(String.join("\n", keys));
    }

    /** Gun -> gorsel adresi (yalniz eslesen gunler). Gun listesi cagiran tarafindan sinirlidir. */
    @Transactional(readOnly = true)
    public Map<LocalDate, String> forDays(Collection<MenuDay> list) {
        Map<LocalDate, String> hashOf = new HashMap<>();
        for (MenuDay d : list) {
            String h = hash(d.getItems());
            if (h != null) {
                hashOf.put(d.getMenuDate(), h);
            }
        }
        Map<String, String> urlOf = new HashMap<>();
        List<String> all = new ArrayList<>(new TreeSet<>(hashOf.values()));
        for (int i = 0; i < all.size(); i += CHUNK) {
            for (MenuContentImage m : images.findByContentHashIn(all.subList(i, Math.min(all.size(), i + CHUNK)))) {
                urlOf.put(m.getContentHash(), m.getImageUrl());
            }
        }
        Map<LocalDate, String> out = new HashMap<>();
        hashOf.forEach((date, h) -> {
            String url = urlOf.get(h);
            if (url != null) {
                out.put(date, url);
            }
        });
        return out;
    }

    @Transactional(readOnly = true)
    public String forDay(MenuDay day) {
        return forDays(List.of(day)).get(day.getMenuDate());
    }

    /** Bu menunun gorselini ayarlar; onceki gorselin adresini (yoksa null) doner. */
    @Transactional
    public String remember(MenuDay day, String url) {
        String h = hash(day.getItems());
        if (h == null) {
            return null;
        }
        MenuContentImage m = images.findById(h).orElseGet(() -> {
            MenuContentImage n = new MenuContentImage();
            n.setContentHash(h);
            return n;
        });
        String previous = m.getImageUrl();
        m.setImageUrl(url);
        m.setUpdatedAt(Instant.now());
        images.saveAndFlush(m);
        return previous;
    }

    /** Bu menunun gorselini kaldirir; kaldirilan adresi (yoksa null) doner. */
    @Transactional
    public String forget(MenuDay day) {
        String h = hash(day.getItems());
        MenuContentImage m = h == null ? null : images.findById(h).orElse(null);
        if (m == null) {
            return null;
        }
        images.delete(m);
        images.flush();
        return m.getImageUrl();
    }

    /** Eski menu_day.image_url degerlerini icerik tablosuna tasir (idempotent); hata acilisi bozmaz. */
    @EventListener(ApplicationReadyEvent.class)
    @Transactional
    public void adoptLegacy() {
        try {
            for (MenuDay d : days.findByImageUrlIsNotNull()) {
                String h = hash(d.getItems());
                if (h != null && !images.existsById(h)) {
                    MenuContentImage n = new MenuContentImage();
                    n.setContentHash(h);
                    n.setImageUrl(d.getImageUrl());
                    images.save(n);
                }
                d.setImageUrl(null);
                days.save(d);
            }
        } catch (RuntimeException e) {
            log.warn("Eski menu gorselleri tasinamadi: {}", e.toString());
        }
    }
}
