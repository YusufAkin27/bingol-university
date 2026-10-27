package edu.bingol.backend.post;

import java.util.List;

/** Gonderi silindiginde yayinlanir; medya katmani (B) dosyalari zamanlayarak temizler. */
public record PostDeletedEvent(long postId, List<Long> mediaIds) {}
