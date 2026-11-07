package edu.bingol.backend.news;

/**
 * Native (PostgreSQL) arama sorgusunun satiri: tarihler ve tur metin olarak gelir (CAST), cunku native
 * projeksiyonda java.sql tipleri ile LocalDate/enum donusumune guvenilmez. `content` secilmez.
 */
public interface NewsSearchRow {
    Long getId();

    String getType();

    String getTitle();

    String getSummary();

    String getImageUrl();

    String getPublishedDate();

    String getUrl();

    String getEventDate();
}
