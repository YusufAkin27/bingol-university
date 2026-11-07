package edu.bingol.backend.forum.moderation;

import edu.bingol.backend.forum.topic.spi.ForumMuteLookup;
import java.util.Set;
import org.springframework.stereotype.Component;

/** A'nin {@link ForumMuteLookup} SPI uygulamasi: bakanin sessize aldigi kullanicilar (forum_user_mute). */
@Component
public class ForumMuteLookupImpl implements ForumMuteLookup {

    private final ForumMuteService mutes;

    public ForumMuteLookupImpl(ForumMuteService mutes) {
        this.mutes = mutes;
    }

    @Override
    public Set<Long> mutedBy(Long viewerId) {
        return mutes.mutedIds(viewerId);
    }
}
