package edu.bingol.backend.bookmark.dto;

import edu.bingol.backend.bookmark.BookmarkTarget;
import edu.bingol.backend.news.dto.NewsSummary;
import java.time.Instant;

/** Kaydedilenler listesi satiri: haber ozeti ve kaydedilme zamani. */
public record BookmarkView(BookmarkTarget targetType, Long targetId, Instant savedAt, NewsSummary news) {
}
