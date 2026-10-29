package edu.bingol.backend.menu;

import java.text.Normalizer;
import java.util.Locale;

/**
 * Yemek adini kalori anahtarina cevirir: bosluklar tek, buyuk/kucuk harf ve Turkce harf farki yok sayilir
 * (I/İ/ı -> i, ç/ş/ğ/ö/ü -> c/s/g/o/u), en cok 300 karakter. Boylece kaynak sitenin BUYUK HARFLI adi ile
 * yoneticinin ASCII/Turkce yazdigi ad ayni yemege gider.
 */
public final class MenuItemKey {

    public static final int MAX_LEN = 300;

    private MenuItemKey() {}

    public static String of(String name) {
        if (name == null) {
            return "";
        }
        String k = name.replace(' ', ' ').trim().replaceAll("\\s+", " ");
        // Locale'e bagli kucuk harfe cevirme sorunlarini (I -> ı) onlemek icin once i-ailesi sabitlenir
        k = k.replace('İ', 'i').replace('I', 'i').replace('ı', 'i');
        k = Normalizer.normalize(k, Normalizer.Form.NFD).replaceAll("\\p{M}+", "");
        k = k.toLowerCase(Locale.ROOT);
        return k.length() > MAX_LEN ? k.substring(0, MAX_LEN) : k;
    }
}
