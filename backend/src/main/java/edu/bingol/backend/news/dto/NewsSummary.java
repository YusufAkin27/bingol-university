package edu.bingol.backend.news.dto;

import edu.bingol.backend.news.ContentType;
import edu.bingol.backend.news.NewsItem;
import edu.bingol.backend.news.NewsRow;
import edu.bingol.backend.news.NewsSearchRow;

/** Liste gorunumu. publishedDate ISO (yyyy-MM-dd). */
public record NewsSummary(Long id, ContentType type, String title, String summary,
                          String imageUrl, String publishedDate, String url, String eventDate) {

    public static NewsSummary of(NewsItem n) {
        return new NewsSummary(n.getId(), n.getType(), n.getTitle(), n.getSummary(), n.getImageUrl(),
                n.getPublishedDate() == null ? null : n.getPublishedDate().toString(), n.getUrl(),
                n.getEventDate() == null ? null : n.getEventDate().toString());
    }

    /** Dar projeksiyondan (content okunmadan) liste ogesi. */
    public static NewsSummary of(NewsRow n) {
        return new NewsSummary(n.getId(), n.getType(), n.getTitle(), n.getSummary(), n.getImageUrl(),
                n.getPublishedDate() == null ? null : n.getPublishedDate().toString(), n.getUrl(),
                n.getEventDate() == null ? null : n.getEventDate().toString());
    }

    /** Native arama satirindan liste ogesi (tarihler zaten ISO metin). */
    public static NewsSummary of(NewsSearchRow n) {
        return new NewsSummary(n.getId(), n.getType() == null ? null : ContentType.valueOf(n.getType()), n.getTitle(),
                n.getSummary(), n.getImageUrl(), n.getPublishedDate(), n.getUrl(), n.getEventDate());
    }
}
