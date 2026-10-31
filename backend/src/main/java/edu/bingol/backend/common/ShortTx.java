package edu.bingol.backend.common;

import java.util.function.Supplier;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Kisa islem yardimcisi (T-068): agir is (gorsel isleme, dosya yazimi) islem DISINDA yapilir, yalniz kisa DB yazimi
 * bu sarmalayicinin icinde calisir. Boylece Hikari baglantisi/PostgreSQL oturumu "idle in transaction" kalmaz
 * (A2-05: 24 eszamanli yuklemede 24 bosta islem, yukte idle-in-transaction zaman asimiyla 500).
 *
 * <p>Islem yoneticisi yoksa (birim testlerinde servisler elle kurulur) cagri dogrudan calisir; davranis ayni kalir.
 */
public final class ShortTx {

    private static final ShortTx DIRECT = new ShortTx(null);

    private final TransactionTemplate template;

    private ShortTx(TransactionTemplate template) {
        this.template = template;
    }

    /** Islem yoneticisi null ise dogrudan calistiran ornek doner. */
    public static ShortTx of(PlatformTransactionManager tm) {
        return tm == null ? DIRECT : new ShortTx(new TransactionTemplate(tm));
    }

    public static ShortTx direct() {
        return DIRECT;
    }

    /** Verilen isi tek kisa islemde calistirir (islem yoksa dogrudan). Exception geri alir ve yayilir. */
    public <T> T call(Supplier<T> work) {
        return template == null ? work.get() : template.execute(status -> work.get());
    }

    /** Sonuc donmeyen is icin {@link #call}. */
    public void run(Runnable work) {
        call(() -> {
            work.run();
            return null;
        });
    }

    /** Yeni deger + serbest birakilacak eski dosya URL'si (islem sonrasi {@code media.release(old)} icin). */
    public record Replaced<T>(T value, String old) {
    }
}
