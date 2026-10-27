package edu.bingol.backend.post.spi;

import edu.bingol.backend.post.PostDtos.MentionView;
import java.util.Collection;
import java.util.List;
import java.util.Map;

/** Gonderi/yorum sosyal ekleri: kaydetme durumu, etiketlenenler, #etiketler (post.social uygular). */
public interface PostExtrasLookup {

    record Extras(boolean savedByMe, List<MentionView> mentions, List<String> hashtags) {
        public static final Extras EMPTY = new Extras(false, List.of(), List.of());
    }

    /** Anahtari olmayan gonderi = ek yok. */
    Map<Long, Extras> postExtras(Long viewerId, Collection<Long> postIds);

    /** Yorum kimligi -> etiketlenenler. */
    Map<Long, List<MentionView>> commentMentions(Long viewerId, Collection<Long> commentIds);
}
