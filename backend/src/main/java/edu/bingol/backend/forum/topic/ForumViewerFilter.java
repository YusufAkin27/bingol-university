package edu.bingol.backend.forum.topic;

import edu.bingol.backend.forum.topic.spi.ForumMuteLookup;
import edu.bingol.backend.moderation.BlockService;
import java.util.HashSet;
import java.util.Set;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Component;

/**
 * Bakan icin GIZLENECEK yazar kumesi: iki yonlu engel ({@link BlockService}) + tek yonlu sessize alma
 * ({@link ForumMuteLookup}, D uygular; bean yoksa uygulanmaz). Anonim iceriklerde de ayni kume uygulanir:
 * karari sunucu verir, istemciye kimlik sizmaz.
 */
@Component
public class ForumViewerFilter {

    /** Bos IN listesi tasinabilir degildir; hicbir kullanici kimligi olmayan bekci deger. */
    public static final Long SENTINEL = -1L;

    private final BlockService blocks;
    private final ObjectProvider<ForumMuteLookup> mutes;

    public ForumViewerFilter(BlockService blocks, ObjectProvider<ForumMuteLookup> mutes) {
        this.blocks = blocks;
        this.mutes = mutes;
    }

    /** Hicbir zaman bos degildir (bekci deger icerir) ve bakanin kendisini icermez. */
    public Set<Long> hiddenFrom(Long viewerId) {
        Set<Long> out = new HashSet<>();
        if (viewerId != null) {
            out.addAll(blocks.hiddenFrom(viewerId));
            ForumMuteLookup m = mutes.getIfAvailable();
            if (m != null) {
                out.addAll(m.mutedBy(viewerId));
            }
            out.remove(viewerId);
        }
        out.add(SENTINEL);
        return out;
    }
}
