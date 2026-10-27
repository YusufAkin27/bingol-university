package edu.bingol.backend.post.spi;

import java.util.Collection;
import java.util.Set;

/** Bakan kullanicinin begendigi gonderiler (C uygular). */
public interface PostLikeLookup {

    Set<Long> likedPostIds(Long viewerId, Collection<Long> postIds);
}
