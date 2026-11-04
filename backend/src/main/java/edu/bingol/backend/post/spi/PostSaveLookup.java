package edu.bingol.backend.post.spi;

import java.util.Collection;
import java.util.Set;

/** Bakanin kaydettigi gonderiler (KS-BE2); PostViewAssembler toplu (N+1'siz) cagirir. */
public interface PostSaveLookup {

    /** viewerId'nin kaydettigi gonderiler (verilen kimlikler icinden). */
    Set<Long> savedPostIds(Long viewerId, Collection<Long> postIds);
}
