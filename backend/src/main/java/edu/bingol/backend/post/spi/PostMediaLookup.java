package edu.bingol.backend.post.spi;

import edu.bingol.backend.post.PostDtos.MediaView;
import java.util.Collection;
import java.util.List;
import java.util.Map;

/** Gonderi medyasi (B uygular). Gonderi akisi toplu cagirir; medyasi olmayan id anahtar olarak bulunmayabilir. */
public interface PostMediaLookup {

    Map<Long, List<MediaView>> viewsFor(Collection<Long> postIds, Long viewerId);
}
