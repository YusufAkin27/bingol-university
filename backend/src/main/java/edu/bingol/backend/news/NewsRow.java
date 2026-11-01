package edu.bingol.backend.news;

import java.time.LocalDate;

/**
 * Liste gorunumu icin dar projeksiyon: TEXT `content` (8-20 KB, TOAST) hic okunmaz. Liste, favori ve
 * arama uclari tam {@link NewsItem} yerine bunu kullanir (docs/DATABASE.md "liste uclarinda dar projeksiyon").
 */
public interface NewsRow {
    Long getId();

    ContentType getType();

    String getTitle();

    String getSummary();

    String getImageUrl();

    LocalDate getPublishedDate();

    String getUrl();

    LocalDate getEventDate();
}
