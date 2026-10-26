package edu.bingol.backend.news.dto;

import edu.bingol.backend.news.ContentType;
import edu.bingol.backend.news.NewsItem;

/** Detay gorunumu; content harici sitelerdeki duyurularda null olabilir. */
public record NewsDetail(Long id, ContentType type, String title, String content,
                         String imageUrl, String publishedDate, String url, String eventDate) {

    public static NewsDetail of(NewsItem n) {
        return new NewsDetail(n.getId(), n.getType(), n.getTitle(), n.getContent(), n.getImageUrl(),
                n.getPublishedDate() == null ? null : n.getPublishedDate().toString(), n.getUrl(),
                n.getEventDate() == null ? null : n.getEventDate().toString());
    }
}
