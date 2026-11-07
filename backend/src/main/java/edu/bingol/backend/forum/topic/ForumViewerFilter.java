package edu.bingol.backend.forum.topic;

import edu.bingol.backend.forum.topic.spi.ForumMuteLookup;
import edu.bingol.backend.moderation.BlockService;
import java.util.HashSet;
import java.util.Set;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Component;

/**
 * Bakan icin GIZLENECEK yazar kumesi: iki yonlu engel ({@link BlockService}) + tek yonlu sessize alma
 * ({@link ForumMuteLookup}, D uygular; bean yoksa uygulanmaz).
 *
 * <p>KODLAMA (anonimlik sizintisi onlemi): ENGEL anonim icerikte de uygulanir (karsilikli, kimlik acilmaz); SESSIZE ALMA
 * ise yalniz yazar ADIYLA gorunen (anonim olmayan) iceriklere uygulanir, yoksa kullanici tahmin ettigi birini sessize alip
 * anonim icerigin kaybolup kaybolmadigina bakarak kimligi sinayabilirdi. Tek kume tasimak icin engellenenler POZITIF kimlik,
 * sessize alinanlar NEGATIF kimlik ({@code -id}, {@link #mutedKey}) olarak yazilir; sorgular
 * {@code user_id NOT IN :hidden AND (anonymous OR -user_id NOT IN :hidden)} kalibini kullanir ({@link #hides} Java karsiligi).
 */
@Component
public class ForumViewerFilter {

    /** Bos IN listesi tasinabilir degildir; hicbir kullanici kimligi olmayan bekci deger. */
    public static final Long SENTINEL = Long.MIN_VALUE;

    private final BlockService blocks;
    private final ObjectProvider<ForumMuteLookup> mutes;

    public ForumViewerFilter(BlockService blocks, ObjectProvider<ForumMuteLookup> mutes) {
        this.blocks = blocks;
        this.mutes = mutes;
    }

    /** Sessize alinan kullanicinin kume anahtari (engelden ayirt etmek icin negatif). */
    public static Long mutedKey(long userId) {
        return -userId;
    }

    /** {@code hidden} (bkz. {@link #hiddenFrom}) bu yazarin bu icerigini bakandan gizler mi. */
    public static boolean hides(java.util.Collection<Long> hidden, long authorId, boolean anonymous) {
        return hidden.contains(authorId) || (!anonymous && hidden.contains(mutedKey(authorId)));
    }

    /** Hicbir zaman bos degildir (bekci deger icerir) ve bakanin kendisini icermez. */
    public Set<Long> hiddenFrom(Long viewerId) {
        Set<Long> out = new HashSet<>();
        if (viewerId != null) {
            out.addAll(blocks.hiddenFrom(viewerId));
            ForumMuteLookup m = mutes.getIfAvailable();
            if (m != null) {
                m.mutedBy(viewerId).forEach(id -> out.add(mutedKey(id)));
            }
            out.remove(viewerId);
            out.remove(mutedKey(viewerId));
        }
        out.add(SENTINEL);
        return out;
    }
}
