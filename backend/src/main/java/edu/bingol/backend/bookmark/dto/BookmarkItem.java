package edu.bingol.backend.bookmark.dto;

import edu.bingol.backend.news.dto.NewsSummary;
import java.time.Instant;

/**
 * Birlesik Kaydedilenler satiri. type: NEWS|EVENT|COMMUNITY|POLL|ACADEMIC|POST|FORUM_TOPIC|FORUM_COMMENT.
 * link: uygulama ici yol (istemci eslemesi), ornek /events/12; NEWS icin dis adres {@code news.url}'dedir. news yalniz NEWS'te dolu.
 */
public record BookmarkItem(String type, Long targetId, Instant savedAt, String title, String subtitle,
                           String imageUrl, String link, NewsSummary news) {
}
