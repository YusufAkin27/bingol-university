package edu.bingol.backend.menu.dto;

import edu.bingol.backend.menu.MenuDay;
import edu.bingol.backend.menu.MenuItemKey;
import java.util.List;
import java.util.Map;

/**
 * Bir gunun menusu. date ISO (yyyy-MM-dd); imageUrl istege bagli menu fotografi (yoksa null).
 * items: yalniz yemek adlari (eski istemciler icin degismedi). dishes: ayni sirada {name, kcal}; kcal yoneticinin girdigi
 * kalori, yoksa null. totalKcal: kalorisi bilinen yemeklerin toplami (hicbiri bilinmiyorsa null); kcalComplete: tum
 * yemeklerin kalorisi girilmis mi (false ise toplam eksiktir, "en az" diye gosterilmeli).
 */
public record MenuResponse(String date, List<String> items, String imageUrl, List<MenuDish> dishes, Integer totalKcal,
                           boolean kcalComplete) {

    /** Kalorisiz (kalori tablosuna bakmadan) donusum. */
    public static MenuResponse of(MenuDay d) {
        return of(d, Map.of());
    }

    /** kcalByKey: {@link MenuItemKey#of} anahtarli kalori haritasi (bos olabilir). */
    public static MenuResponse of(MenuDay d, Map<String, Integer> kcalByKey) {
        List<String> items = List.of(d.getItems().split("\n"));
        List<MenuDish> dishes = items.stream().map(n -> new MenuDish(n, kcalByKey.get(MenuItemKey.of(n)))).toList();
        int known = 0;
        int sum = 0;
        for (MenuDish dish : dishes) {
            if (dish.kcal() != null) {
                known++;
                sum += dish.kcal();
            }
        }
        return new MenuResponse(d.getMenuDate().toString(), items, d.getImageUrl(), dishes,
                known == 0 ? null : sum, known == dishes.size() && known > 0);
    }
}
